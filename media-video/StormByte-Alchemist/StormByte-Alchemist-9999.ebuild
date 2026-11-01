# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake desktop xdg stormbyte-suite

DESCRIPTION="StormByte Alchemist media transcoder and license server"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Alchemist"

# The repository is private. github-alchemist is an SSH host alias in the
# portage user's ~/.ssh/config that points to github.com with a read-only
# deploy key, so no other GitHub access uses that key.
EGIT_REPO_URI="ssh://git@github-alchemist/StormByte-Suite/${PN}.git"
# Nothing is built from these. The GUI embeds their license texts while
# linking the system QtSvg, libpulse and libsndfile.
EGIT_SUBMODULES=( "QT - SVG" playback-pulseaudio playback-libsndfile )

LICENSE="all-rights-reserved"
IUSE+=" +gui license-server"
REQUIRED_USE="|| ( gui license-server )"
RESTRICT="bindist mirror"

# Alchemy (shared by both programs) links every module except Database.
# ControlServer adds Database and selects SQLite, PostgreSQL or MariaDB
# at runtime, so all three backends are required.
DEPEND="
	>=dev-libs/StormByte-2.2.2:=
	>=dev-libs/StormByte-Buffer-2.0.5:=
	>=dev-libs/StormByte-Config-2.0.5:=
	>=dev-libs/StormByte-Crypto-2.3.0:=
	>=dev-libs/StormByte-Logger-2.0.5:=
	>=dev-libs/StormByte-Multimedia-1.1.0:=
	>=dev-libs/StormByte-Network-3.0.0:=
	>=dev-libs/StormByte-System-2.1.2:=
	gui? (
		dev-qt/qtbase:6[gui,opengl,widgets]
		dev-qt/qtsvg:6
		>=media-libs/libpulse-16.1
	)
	license-server? (
		acct-group/alchemist-control
		>=dev-libs/StormByte-Database-2.1.2:=[mariadb,postgres,sqlite]
	)
"
RDEPEND="
	${DEPEND}
	license-server? ( acct-user/alchemist-control )
"
BDEPEND+="
	gui? ( dev-qt/qttools:6[linguist] )
"

# The programs find their own libraries through $ORIGIN, so they live
# together outside the system library directory.
ALCHEMIST_PREFIX="/opt/${PN}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}${ALCHEMIST_PREFIX}"
		-DENABLE_GUI=$(usex gui ON OFF)
		-DENABLE_CONTROL=$(usex license-server ON OFF)
		-DOPTIMIZATION_FLAGS_LINUX=
		-DWITH_PULSEAUDIO=SYSTEM
		-DWITH_QT=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DALCHEMY_LICENSE_SERVER_HOST=alchemist.stormbyte.org
		-DALCHEMY_LICENSE_SERVER_PORT=6869
	)
}

src_install() {
	cmake_src_install

	if use gui; then
		dosym -r "${ALCHEMIST_PREFIX}/StormByte-Alchemist" /usr/bin/StormByte-Alchemist
		newicon -s scalable components/alchemist/resources/icons/alchemist.svg ${PN}.svg
		make_desktop_entry --eapi9 StormByte-Alchemist -n "StormByte Alchemist" \
			-C "Media transcoder" -i ${PN} -c "AudioVideo;Video;"
	fi

	if use license-server; then
		dosym -r "${ALCHEMIST_PREFIX}/control-server" /usr/bin/alchemist-control-server
		dodoc components/control/control.conf.example

		newinitd "${FILESDIR}"/alchemist-control.initd alchemist-control
		newconfd "${FILESDIR}"/alchemist-control.confd alchemist-control
		insinto /etc/logrotate.d
		newins "${FILESDIR}"/alchemist-control.logrotate alchemist-control

		# Same port the GUI is built with; the database lives with the service.
		sed -e 's/^\tport = 47800$/\tport = 6869/' \
			-e 's|^\tpath = "control.db"$|\tpath = "/var/lib/alchemist-control/control.db"|' \
			components/control/control.conf.example > "${T}"/control.conf || die
		grep -qxF $'\tport = 6869' "${T}"/control.conf || die "control.conf port not set"
		grep -qxF $'\tpath = "/var/lib/alchemist-control/control.db"' "${T}"/control.conf \
			|| die "control.conf database path not set"

		# Root owns the configuration and keys; the service can only read them.
		insinto /etc/alchemist-control
		insopts -m 0640 -o root -g alchemist-control
		doins "${T}"/control.conf
		fowners root:alchemist-control /etc/alchemist-control
		fperms 0750 /etc/alchemist-control
	fi
}

pkg_postinst() {
	use gui && xdg_pkg_postinst

	if use license-server; then
		elog "Copy the license server certificate chain and private key to"
		elog "${EROOT}/etc/alchemist-control. Only the service user may read the key:"
		elog "  chown alchemist-control:alchemist-control license-server.key"
		elog "  chmod 0400 license-server.key"
		elog "  chown root:alchemist-control license-server-chain.crt"
		elog "  chmod 0640 license-server-chain.crt"
		elog "Then review ${EROOT}/etc/alchemist-control/control.conf and run:"
		elog "  rc-service alchemist-control start"
		elog "  rc-update add alchemist-control default"
		elog "Run administration commands as the service user, for example:"
		elog "  su -s /bin/sh alchemist-control -c \\"
		elog "    'alchemist-control-server --config /etc/alchemist-control/control.conf list'"
	fi
}

pkg_postrm() {
	use gui && xdg_pkg_postrm
}
