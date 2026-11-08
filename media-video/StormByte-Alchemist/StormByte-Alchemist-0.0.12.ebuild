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
EGIT_COMMIT="bd673719dd2ddf458350753b1455f376086c5217"
# Nothing is built from these. The GUI embeds their audio license texts
# while linking the system libraries; QtSvg notices are in the main tree.
EGIT_SUBMODULES=( playback-pulseaudio playback-libsndfile )
PROPERTIES="${PROPERTIES//live/}"

LICENSE="all-rights-reserved"
IUSE+=" +gui +lto license-server"
REQUIRED_USE="|| ( gui license-server )"
RESTRICT="bindist mirror"

# Both programs share the licensing core (Covenant); only the GUI's Alchemy
# links Multimedia.
# ControlServer adds Database and selects SQLite, PostgreSQL or MariaDB
# at runtime, so all three backends are required.
# Screen readers reach the GUI through the Qt AT-SPI bridge enabled by
# qtbase[accessibility], which pulls at-spi2-core.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Buffer 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Config 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Crypto 3.0.1)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Network 3.2.1)
	$(stormbyte-suite_dep dev-libs/StormByte-System 3.0.0)
	gui? (
		dev-libs/openssl:=
		$(stormbyte-suite_dep dev-libs/StormByte-Multimedia 3.0.0)
		dev-qt/qtbase:6[accessibility,dbus,gui,opengl,widgets]
		dev-qt/qtsvg:6
		>=media-libs/libpulse-16.1
	)
	license-server? (
		acct-group/alchemist-control
		$(stormbyte-suite_dep dev-libs/StormByte-Database 3.0.0)[mariadb,postgres,sqlite]
	)
"
RDEPEND="
	${DEPEND}
	license-server? ( acct-user/alchemist-control )
"
DEPEND+=" license-server? ( >=dev-cpp/nlohmann_json-3.11 )"
BDEPEND+="
	gui? (
		app-arch/gzip
		dev-qt/qttools:6[linguist]
		sys-apps/coreutils
	)
"
RDEPEND+=" gui? ( app-arch/gzip sys-apps/coreutils )"

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
		-DWITH_PULSEAUDIO=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DALCHEMY_RELEASE_STAGE=Beta
		-DALCHEMY_LICENSE_SERVER_HOST=alchemist.stormbyte.org
		-DALCHEMY_LICENSE_SERVER_PORT=47800
	)
}

src_compile() {
	cmake_src_compile
	if use gui; then
		cmake --build "${BUILD_DIR}" --target AlchemistHardwareIdentity -j"$(nproc)" \
			|| die "Hardware identity helper build failed"
	fi
}

src_install() {
	cmake_src_install

	if use gui; then
		# Portage saves this payload in the binary package's environment, not its image.
		ALCHEMIST_HARDWARE_PAYLOAD=$(
			set -o pipefail
			gzip -cn "${BUILD_DIR}/components/hardwareidentity/alchemist-hardware-identity" | base64
		) || die "Cannot embed hardware identity helper"
		[[ -n ${ALCHEMIST_HARDWARE_PAYLOAD} ]] || die "Empty hardware identity helper"

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

alchemist_hardware_identity() {
	[[ ${ROOT:-/} == / ]] || die "Generate hardware identity on the running target system"
	[[ -n ${ALCHEMIST_HARDWARE_PAYLOAD} ]] || die "Missing hardware identity helper payload"

	local directory="${EROOT}/var/lib/stormbyte/alchemist"
	install -d -o root -g root -m 0755 "${EROOT}/var/lib/stormbyte" "${directory}" \
		|| die "Cannot create hardware identity directory"
	local work
	work=$(mktemp -d "${directory}/.hardware-install.XXXXXX") \
		|| die "Cannot create temporary hardware identity directory"

	(
		trap 'rm -f "${work}/helper.gz" "${work}/helper"; rmdir "${work}"' EXIT
		base64 --decode > "${work}/helper.gz" <<< "${ALCHEMIST_HARDWARE_PAYLOAD}" \
			|| die "Cannot decode hardware identity helper"
		gzip -d "${work}/helper.gz" || die "Cannot decompress hardware identity helper"
		chmod 0700 "${work}/helper" || die "Cannot secure hardware identity helper"
		"${work}/helper" --write "${directory}/hardware.identity" \
			|| die "Cannot generate hardware identity"
		chown root:root "${directory}/hardware.identity" || die "Cannot set hardware identity owner"
		chmod 0644 "${directory}/hardware.identity" || die "Cannot set hardware identity permissions"
	) || die "Hardware identity provisioning failed; run emerge --config =${CATEGORY}/${PF} to retry"
}

pkg_config() {
	use gui || die "Hardware identity provisioning requires USE=gui"
	alchemist_hardware_identity
}

pkg_postinst() {
	use gui && xdg_pkg_postinst

	if use gui; then
		if [[ ${ROOT:-/} == / ]]; then
			alchemist_hardware_identity
		else
			ewarn "Hardware identity must be generated on the running target, not the build host."
			ewarn "After booting the target, run emerge --config =${CATEGORY}/${PF}"
		fi
	fi

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
