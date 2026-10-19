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
		mkdir -p "${pgdata}/sock" || die
		"${pg}/pg_ctl" -D "${pgdata}" -w -t 60 -l "${root}/postgres.log" start \
			-o "-p ${port} -k ${pgdata}/sock -c listen_addresses=localhost" \
			|| die "pg_ctl start failed"
		echo "${port}" > "${root}/postgres.port" || die
		"${pg}/psql" -h "${pgdata}/sock" -U testuser -d postgres -v ON_ERROR_STOP=1 \
			-c "CREATE DATABASE stormbyte_test OWNER testuser;" \
			|| die "CREATE DATABASE stormbyte_test failed"
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
		sock="${root}/mariadb.sock"
		cnf="${root}/mariadb.cnf"
		mkdir -p "${data}" || die

		einfo "PGO: MariaDB datadir ${data} port ${port}"
		"${installdb}" --datadir="${data}" --auth-root-authentication-method=normal \
			|| die "mariadb-install-db failed"
		cat > "${cnf}" <<-EOF || die
			[mysqld]
			datadir=${data}
			port=${port}
			socket=${sock}
			pid-file=${root}/mariadb.pid
			bind-address=127.0.0.1
			skip-networking=0
			skip-name-resolve
		EOF
		# skip-grant-tables only for the first boot, so the test user can be
		# created no matter how root was authenticated. The tests then run
		# against a normal server.
		"${server}" --defaults-file="${cnf}" --skip-grant-tables --daemonize \
			|| die "mariadbd failed to start"
		local i
		for i in $(seq 1 60); do
			"${client}" --socket="${sock}" -u root -e "SELECT 1" &>/dev/null && break
			sleep 1
		done
		"${client}" --socket="${sock}" -u root -e "SELECT 1" &>/dev/null \
			|| die "MariaDB did not accept connections"
		echo "${port}" > "${root}/mariadb.port" || die
		"${client}" --socket="${sock}" -u root <<-SQL || die "MariaDB user setup failed"
			FLUSH PRIVILEGES;
			CREATE DATABASE IF NOT EXISTS stormbyte_test;
			CREATE USER IF NOT EXISTS 'testuser'@'127.0.0.1' IDENTIFIED BY 'testpass';
			GRANT ALL PRIVILEGES ON stormbyte_test.* TO 'testuser'@'127.0.0.1';
			FLUSH PRIVILEGES;
		SQL
		"${client}" --socket="${sock}" -u root -e "SHUTDOWN" || die "MariaDB shutdown failed"
		rm -f "${root}/mariadb.pid"
		local n=0
		while [[ -S ${sock} && ${n} -lt 60 ]]; do
			sleep 1
			n=$((n + 1))
		done
		[[ -S ${sock} ]] && die "MariaDB socket stayed after shutdown"
		"${server}" --defaults-file="${cnf}" --daemonize \
			|| die "mariadbd failed to restart"
		for i in $(seq 1 60); do
			"${client}" --socket="${sock}" -u testuser -ptestpass -e "SELECT 1" stormbyte_test &>/dev/null && break
			sleep 1
		done
		"${client}" --socket="${sock}" -u testuser -ptestpass -e "SELECT 1" stormbyte_test &>/dev/null \
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

	if [[ -S ${root}/mariadb.sock ]]; then
		local client
		client=$(type -P mariadb || type -P mysql || true)
		if [[ -n ${client} ]]; then
			"${client}" --socket="${root}/mariadb.sock" -u root -e "SHUTDOWN" \
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
