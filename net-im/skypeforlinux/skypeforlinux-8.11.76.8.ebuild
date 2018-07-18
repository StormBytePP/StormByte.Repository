# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

MULTILIB_COMPAT=( abi_x86_64 )

inherit pax-utils rpm multilib-build xdg-utils

DESCRIPTION="Instant messaging client, with support for audio and video"
HOMEPAGE="https://www.skype.com/"
#SRC_URI="https://repo.skype.com/rpm/stable/${PN}_${PV}-1.x86_64.rpm"
SRC_URI="https://repo.skype.com/rpm/unstable/${PN}_${PV}-1.x86_64.rpm"

LICENSE="no-source-code MIT MIT-with-advertising BSD-1 BSD-2 BSD Apache-2.0 Boost-1.0 ISC CC-BY-SA-3.0 CC0-1.0 openssl ZLIB APSL-2 icu Artistic-2 LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64"
IUSE="pax_kernel"

S="${WORKDIR}"
QA_PREBUILT=opt/skypeforlinux/skypeforlinux
QA_TEXTRELS=opt/skypeforlinux/resources/app.asar.unpacked/node_modules/slimcore/bin/slimcore.node
QA_EXECSTACK=opt/skypeforlinux/resources/app.asar.unpacked/node_modules/slimcore/bin/slimcore.node
RESTRICT="mirror bindist strip" #299368


RDEPEND="
	app-crypt/libsecret[${MULTILIB_USEDEP}]
	dev-libs/atk[${MULTILIB_USEDEP}]
	dev-libs/expat[${MULTILIB_USEDEP}]
	dev-libs/glib:2[${MULTILIB_USEDEP}]
	dev-libs/nspr[${MULTILIB_USEDEP}]
	dev-libs/nss[${MULTILIB_USEDEP}]
	gnome-base/gconf:2[${MULTILIB_USEDEP}]
	media-libs/alsa-lib[${MULTILIB_USEDEP}]
	media-libs/fontconfig:1.0[${MULTILIB_USEDEP}]
	media-libs/freetype:2[${MULTILIB_USEDEP}]
	media-libs/libv4l[${MULTILIB_USEDEP}]
	net-print/cups[${MULTILIB_USEDEP}]
	sys-apps/dbus[${MULTILIB_USEDEP}]
	sys-devel/gcc[cxx]
	virtual/ttf-fonts
	x11-libs/cairo[${MULTILIB_USEDEP}]
	x11-libs/gdk-pixbuf:2[${MULTILIB_USEDEP}]
	x11-libs/gtk+:2[${MULTILIB_USEDEP}]
	x11-libs/libX11[${MULTILIB_USEDEP}]
	x11-libs/libXScrnSaver[${MULTILIB_USEDEP}]
	x11-libs/libXcomposite[${MULTILIB_USEDEP}]
	x11-libs/libXcursor[${MULTILIB_USEDEP}]
	x11-libs/libXdamage[${MULTILIB_USEDEP}]
	x11-libs/libXext[${MULTILIB_USEDEP}]
	x11-libs/libXfixes[${MULTILIB_USEDEP}]
	x11-libs/libXi[${MULTILIB_USEDEP}]
	x11-libs/libXrandr[${MULTILIB_USEDEP}]
	x11-libs/libXrender[${MULTILIB_USEDEP}]
	x11-libs/libXtst[${MULTILIB_USEDEP}]
	x11-libs/libxcb[${MULTILIB_USEDEP}]
	x11-libs/libxkbfile[${MULTILIB_USEDEP}]
	x11-libs/pango[${MULTILIB_USEDEP}]"

src_unpack() {
	rpm_src_unpack ${A}
}

src_prepare() {
	default
	sed -e "s!^SKYPE_PATH=.*!SKYPE_PATH=${EPREFIX}/opt/skypeforlinux/skypeforlinux!" \
		-i usr/bin/skypeforlinux || die
	sed -e "s!^Exec=/usr/bin/skypeforlinux!Exec=${EPREFIX}/opt/bin/skypeforlinux!" \
		-e "s!^Categories=.*!Categories=Network;InstantMessaging;Telephony;!" \
		-e "/OnlyShowIn=.*/d" \
		-i usr/share/applications/skypeforlinux.desktop || die
}

src_install() {
	insinto /opt/skypeforlinux/locales
	doins usr/share/skypeforlinux/locales/*.pak

	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/keyboard-layout/build/Release
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/keyboard-layout/build/Release/keyboard-layout-manager.node

	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/keytar/build/Release
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/keytar/build/Release/keytar.node

	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/@paulcbetts/cld/build/Release
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/@paulcbetts/cld/build/Release/cld.node
	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/@paulcbetts/spellchecker/build/Release
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/@paulcbetts/spellchecker/build/Release/spellchecker.node

	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/slimcore/bin
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/slimcore/bin/*.node

	insinto /opt/skypeforlinux/resources/app.asar.unpacked/node_modules/sqlite3/lib/binding
	doins usr/share/skypeforlinux/resources/app.asar.unpacked/node_modules/sqlite3/lib/binding/node_sqlite3.node

	insinto /opt/skypeforlinux/resources
	doins usr/share/skypeforlinux/resources/*.asar

	insinto /opt/skypeforlinux
	doins usr/share/skypeforlinux/*.pak
	doins usr/share/skypeforlinux/*.bin
	doins usr/share/skypeforlinux/*.dat
	doins usr/share/skypeforlinux/version
	exeinto /opt/skypeforlinux
	doexe usr/share/skypeforlinux/*.so
	doexe usr/share/skypeforlinux/skypeforlinux

	into /opt
	dobin usr/bin/skypeforlinux

	dodoc usr/share/skypeforlinux/*.html
	dodoc -r usr/share/doc/skypeforlinux/.
	# symlink required for the "Help->3rd Party Notes" menu entry  (otherwise frozen skype -> xdg-open)
	dosym ${P} usr/share/doc/skypeforlinux

	# compat symlink for skypeforlinux bin autocreate autostart desktop file
	dosym ../../opt/bin/skypeforlinux usr/bin/skypeforlinux

	doicon usr/share/pixmaps/skypeforlinux.png

	local res
	# no 1024 at the moment
	for res in 16 32 256 512; do
		newicon -s ${res} usr/share/icons/hicolor/${res}x${res}/apps/skypeforlinux.png skypeforlinux.png
	done

	domenu usr/share/applications/skypeforlinux.desktop

	if use pax_kernel; then
		pax-mark -Cm "${ED%/}"/opt/skypeforlinux/skypeforlinux
		pax-mark -Cm "${ED%/}"/opt/skypeforlinux/resources/app.asar.unpacked/node_modules/slimcore/bin/slimcore.node
		eqawarn "You have set USE=pax_kernel meaning that you intend to run"
		eqawarn "${PN} under a PaX enabled kernel. To do so, we must modify"
		eqawarn "the ${PN} binary itself and this *may* lead to breakage! If"
		eqawarn "you suspect that ${PN} is being broken by this modification,"
		eqawarn "please open a bug."
	fi
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_mimeinfo_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_mimeinfo_database_update
}

