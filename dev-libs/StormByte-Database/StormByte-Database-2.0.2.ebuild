# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Database module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Database"

LICENSE="LGPL-3"
IUSE+=" +mariadb mssql +postgres +sqlite"

# Logger public-links the core library; both are required explicitly.
# OpenSSL cannot be disabled upstream (WITH_OPENSSL is SYSTEM or BUNDLED).
# The servers are build-time only: USE=pgo trains against a private
# datadir. MSSQL has no Linux server, so that test keeps skipping.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger)
	dev-libs/openssl:=
	mariadb? ( dev-db/mariadb-connector-c:= )
	mssql? ( dev-db/freetds:= )
	postgres? ( dev-db/postgresql:= )
	sqlite? ( dev-db/sqlite:3= )
"
RDEPEND="${DEPEND}"
BDEPEND+="
	pgo? (
		mariadb? ( dev-db/mariadb )
		postgres? ( dev-db/postgresql:=[server] )
	)
"

src_prepare() {
	# 2.0.2's install smoke test only looks in the BuildMaster prefix.
	# A system StormByte-Logger lives in /usr/lib64, so PGO aborts.
	eapply "${FILESDIR}/stormbyte-database-2.0.2-system-smoke.patch"
	stormbyte-suite_src_prepare
}

# Private servers live here, not on the system ports.
_sbdb_root() {
	echo "${BUILD_DIR:-${WORKDIR}/${P}_build}/pgo-servers"
}

# First TCP port in the range that nothing is accepting.
_sbdb_free_port() {
	local start=${1} port
	for port in $(seq "${start}" $((start + 50))); do
		if ! (: >/dev/tcp/127.0.0.1/"${port}") 2>/dev/null; then
			echo "${port}"
			return 0
		fi
	done
	die "no free TCP port from ${start}"
}

_sbdb_pg_bindir() {
	local -a dirs=()
	local latest
	shopt -s nullglob
	dirs=( "${EPREFIX}"/usr/lib*/postgresql-*/bin )
	shopt -u nullglob
	[[ ${#dirs[@]} -gt 0 ]] || die "PostgreSQL server binaries not found"
	latest=$(printf '%s\n' "${dirs[@]}" | sort -V | tail -n1)
	echo "${latest}"
}

# MariaDB 12 has no --daemonize. A background job of this shell is still a
# sandbox child, and Portage waits for it. A short-lived bash exits; the
# server is left in a new session.
_sbdb_maria_launch() {
	local server=$1 cnf=$2
	shift 2
	bash -c '
		setsid "$1" --defaults-file="$2" "${@:3}" </dev/null >>"$LOG" 2>&1 &
		echo $! >"$PIDFILE"
		disown $! 2>/dev/null || true
		exit 0
	' _ "${server}" "${cnf}" "$@" || die "could not launch mariadbd"
}

# System my.cnf points at /var/run/mysqld/mysqld.sock and connect-timeout 0,
# so a bare client waits forever. Talk only to this datadir's socket.
_sbdb_maria() {
	local client=$1 sock=$2
	shift 2
	"${client}" --no-defaults --protocol=socket --socket="${sock}" \
		--connect-timeout=2 --skip-ssl "$@"
}

# install-db prints its banner and then can wait forever on the bootstrap
# server. The tables are already created at that point.
_sbdb_maria_install() {
	local installdb=$1 cnf=$2 data=$3
	local rc=0
	timeout --foreground 120 "${installdb}" --defaults-file="${cnf}" \
		--datadir="${data}" --auth-root-authentication-method=normal \
		</dev/null || rc=$?
	if [[ ${rc} -eq 124 ]]; then
		einfo "PGO: mariadb-install-db did not exit; stopping its server"
	elif [[ ${rc} -ne 0 ]]; then
		cat "${T}/mariadb.err" >&2 || true
		die "mariadb-install-db failed"
	fi
	# Only the build user's server. A system mariadbd runs as mysql.
	pkill -u "$(id -u)" mariadbd 2>/dev/null || true
	sleep 1
}

_sbdb_maria_wait() {
	local client=$1 sock=$2
	shift 2
	local i
	einfo "PGO: waiting for MariaDB socket ${sock}"
	for i in $(seq 1 30); do
		_sbdb_maria "${client}" "${sock}" "$@" &>/dev/null && return 0
		if [[ -f ${T}/mariadb.pid ]] && ! kill -0 "$(<"${T}/mariadb.pid")" 2>/dev/null; then
			break
		fi
		sleep 1
	done
	cat "${T}/mariadb.err" >&2 || true
	return 1
}

stormbyte-suite_pgo_start() {
	local root
	root=$(_sbdb_root)
	mkdir -p "${root}" || die

	# No MSSQL server exists on Linux. An empty MSSQL_HOST makes that
	# test return 77, which ctest treats as skipped.
	unset MSSQL_HOST

	if use postgres; then
		local pg pgdata port pw
		pg=$(_sbdb_pg_bindir)
		pgdata="${root}/postgres"
		port=$(_sbdb_free_port 45432)
		pw="${root}/postgres.pw"
		printf '%s\n' testpass > "${pw}" || die
		chmod 600 "${pw}" || die

		einfo "PGO: PostgreSQL datadir ${pgdata} port ${port}"
		addwrite /dev/shm
		"${pg}/initdb" -D "${pgdata}" \
			--username=testuser --pwfile="${pw}" \
			--auth-local=trust --auth-host=scram-sha-256 \
			--encoding=UTF8 --locale=C --no-instructions \
			|| die "initdb failed"
		# The build path is longer than the 108-byte unix-socket limit.
		# Data stays in the build tree; the socket does not.
		local pgsock="${T}/pgsock"
		mkdir -p "${pgsock}" || die
		"${pg}/pg_ctl" -D "${pgdata}" -w -t 60 -l "${root}/postgres.log" start \
			-o "-p ${port} -k ${pgsock} -c listen_addresses=localhost" \
			|| { cat "${root}/postgres.log" >&2 || true; die "pg_ctl start failed"; }
		echo "${port}" > "${root}/postgres.port" || die
		echo "${pgsock}" > "${root}/postgres.sockdir" || die
		"${pg}/psql" -h "${pgsock}" -p "${port}" -U testuser -d postgres -v ON_ERROR_STOP=1 \
			-c "CREATE DATABASE stormbyte_test OWNER testuser;" \
			|| { cat "${root}/postgres.log" >&2 || true; die "CREATE DATABASE stormbyte_test failed"; }
		export POSTGRES_USER=testuser
		export POSTGRES_PASSWORD=testpass
		export POSTGRES_PORT=${port}
	fi

	if use mariadb; then
		local installdb server client data port sock cnf
		installdb=$(type -P mariadb-install-db || type -P mysql_install_db || true)
		server=$(type -P mariadbd || type -P mysqld || true)
		client=$(type -P mariadb || type -P mysql || true)
		[[ -n ${installdb} && -n ${server} && -n ${client} ]] \
			|| die "MariaDB server binaries not found"
		data="${root}/mariadb"
		port=$(_sbdb_free_port 43306)
		# Same 108-byte unix-socket limit as PostgreSQL.
		sock="${T}/maria.sock"
		cnf="${root}/mariadb.cnf"
		mkdir -p "${data}" || die

		einfo "PGO: MariaDB datadir ${data} port ${port}"
		local install_cnf="${root}/mariadb-install.cnf"
		cat > "${install_cnf}" <<-EOF || die
			[mysqld]
			datadir=${data}
			log-error=${T}/mariadb.err
		EOF
		cat > "${cnf}" <<-EOF || die
			[mysqld]
			datadir=${data}
			port=${port}
			socket=${sock}
			pid-file=${T}/mariadb.pid
			bind-address=127.0.0.1
			skip-name-resolve
			log-error=${T}/mariadb.err
		EOF
		# Bootstrap only. A socket or pid-file here makes the install server
		# stay up, and the script never returns.
		export LOG="${T}/mariadb.err" PIDFILE="${T}/mariadb.pid"
		_sbdb_maria_install "${installdb}" "${install_cnf}" "${data}"
		einfo "PGO: MariaDB system tables installed"
		rm -f "${sock}" "${T}/mariadb.pid"
		# skip-grant-tables is only the first boot, so the test user can be
		# created. The tests then use a normal server.
		_sbdb_maria_launch "${server}" "${cnf}" --skip-grant-tables
		_sbdb_maria_wait "${client}" "${sock}" -u root -e "SELECT 1" \
			|| die "MariaDB did not accept connections"
		echo "${port}" > "${root}/mariadb.port" || die
		_sbdb_maria "${client}" "${sock}" -u root <<-SQL || die "MariaDB user setup failed"
			FLUSH PRIVILEGES;
			CREATE DATABASE IF NOT EXISTS stormbyte_test;
			CREATE USER IF NOT EXISTS 'testuser'@'127.0.0.1' IDENTIFIED BY 'testpass';
			CREATE USER IF NOT EXISTS 'testuser'@'localhost' IDENTIFIED BY 'testpass';
			GRANT ALL PRIVILEGES ON stormbyte_test.* TO 'testuser'@'127.0.0.1';
			GRANT ALL PRIVILEGES ON stormbyte_test.* TO 'testuser'@'localhost';
			FLUSH PRIVILEGES;
		SQL
		_sbdb_maria "${client}" "${sock}" -u root -e "SHUTDOWN" || die "MariaDB shutdown failed"
		local n=0 pid=""
		[[ -f ${T}/mariadb.pid ]] && pid=$(<"${T}/mariadb.pid")
		while [[ -n ${pid} && ${n} -lt 30 ]] && kill -0 "${pid}" 2>/dev/null; do
			sleep 1
			n=$((n + 1))
		done
		rm -f "${T}/mariadb.pid" "${sock}"
		[[ -n ${pid} ]] && kill -0 "${pid}" 2>/dev/null && die "MariaDB did not exit"
		_sbdb_maria_launch "${server}" "${cnf}"
		# The tests connect to 127.0.0.1, not to the unix socket.
		_sbdb_maria_wait "${client}" "${sock}" --protocol=tcp -h 127.0.0.1 -P "${port}" \
			-u testuser -ptestpass -e "SELECT 1" stormbyte_test \
			|| die "MariaDB did not accept the test user"
		export MARIADB_USER=testuser
		export MARIADB_PASSWORD=testpass
		export MARIADB_PORT=${port}
	fi
}

stormbyte-suite_pgo_stop() {
	local root pg
	root=$(_sbdb_root)
	[[ -d ${root} ]] || return 0

	if [[ -f ${root}/postgres.port ]]; then
		pg=$(_sbdb_pg_bindir)
		"${pg}/pg_ctl" -D "${root}/postgres" -m fast -w stop || \
			einfo "PostgreSQL was already stopped"
		rm -f "${root}/postgres.port"
	fi

	if [[ -S ${T}/maria.sock ]]; then
		local client
		client=$(type -P mariadb || type -P mysql || true)
		if [[ -n ${client} ]]; then
			_sbdb_maria "${client}" "${T}/maria.sock" -u root -e "SHUTDOWN" \
				|| einfo "MariaDB was already stopped"
		fi
	fi
	return 0
}

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_MARIADB=$(usex mariadb SYSTEM OFF)
		-DWITH_MSSQL=$(usex mssql SYSTEM OFF)
		-DWITH_OPENSSL=SYSTEM
		-DWITH_POSTGRES=$(usex postgres SYSTEM OFF)
		-DWITH_SQLITE=$(usex sqlite SYSTEM OFF)
		-DWITH_STORMBYTE=SYSTEM
	)
}
