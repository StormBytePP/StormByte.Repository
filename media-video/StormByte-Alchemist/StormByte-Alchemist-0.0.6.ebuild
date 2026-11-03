# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

STORMBYTE_SUITE_NO_PGO=yes
inherit cmake desktop xdg stormbyte-suite git-r3

DESCRIPTION="StormByte Alchemist media transcoder and license server"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Alchemist"

# Private sources use the portage user's read-only deploy-key SSH alias.
# Pin the released commit so retagging cannot silently change this ebuild.
SRC_URI=""
EGIT_REPO_URI="ssh://git@github-alchemist/StormByte-Suite/${PN}.git"
EGIT_BRANCH=""
EGIT_COMMIT="b379d2005f07354bc5817e5d586de3241c7225e2"
EGIT_SUBMODULES=( playback-pulseaudio playback-libsndfile )
PROPERTIES="${PROPERTIES//live/}"

LICENSE="all-rights-reserved"
IUSE+=" +gui +lto license-server"
REQUIRED_USE="|| ( gui license-server )"
RESTRICT="bindist mirror"

# Alchemy (shared by both programs) links every module except Database.
# ControlServer adds Database and selects SQLite, PostgreSQL or MariaDB
# at runtime, so all three backends are required.
DEPEND="
	>=dev-libs/StormByte-2.2.3:=
	>=dev-libs/StormByte-Buffer-2.0.6:=
	>=dev-libs/StormByte-Config-2.0.6:=
	>=dev-libs/StormByte-Crypto-2.3.1:=
	>=dev-libs/StormByte-Logger-2.0.6:=
	>=dev-libs/StormByte-Multimedia-2.0.0:=
	>=dev-libs/StormByte-Network-3.1.0:=
	>=dev-libs/StormByte-System-2.1.3:=
	gui? (
		dev-qt/qtbase:6[gui,opengl,widgets]
		dev-qt/qtsvg:6
		>=media-libs/libpulse-16.1
	)
	license-server? (
		acct-group/alchemist-control
		>=dev-libs/StormByte-Database-2.1.3:=[mariadb,postgres,sqlite]
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

src_unpack() {
	if ! use gui; then
		EGIT_SUBMODULES=()
	fi
	git-r3_src_unpack
}

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}${ALCHEMIST_PREFIX}"
		-DENABLE_GUI=$(usex gui ON OFF)
		-DENABLE_CONTROL=$(usex license-server ON OFF)
		-DOPTIMIZATION_FLAGS_LINUX=
		-DWITH_PULSEAUDIO=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DALCHEMY_LICENSE_SERVER_HOST=alchemist.stormbyte.org
		-DALCHEMY_LICENSE_SERVER_PORT=47800
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
		[[ -x ${ED}${ALCHEMIST_PREFIX}/control-server ]] || die "ControlServer was not installed"
		dosym -r "${ALCHEMIST_PREFIX}/control-server" /usr/bin/alchemist-control-server
		dodoc components/control/control.conf.example

		newinitd "${FILESDIR}"/alchemist-control.initd alchemist-control
		newconfd "${FILESDIR}"/alchemist-control.confd alchemist-control
		insinto /etc/logrotate.d
		newins "${FILESDIR}"/alchemist-control.logrotate alchemist-control

		# Same port the GUI is built with; the database lives with the service.
		sed -e 's|^\tpath = "control.db"$|\tpath = "/var/lib/alchemist-control/control.db"|' \
			components/control/control.conf.example > "${T}"/control.conf || die
		grep -qxF $'\tport = 47800' "${T}"/control.conf || die "control.conf port not set"
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
		elog "${EROOT}/etc/alchemist-control. Keep the key root-owned and service-readable:"
		elog "  chown root:alchemist-control license-server.key"
		elog "  chmod 0640 license-server.key"
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
