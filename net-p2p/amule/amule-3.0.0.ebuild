# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
WX_GTK_VER="3.2-gtk3"

inherit cmake wxwidgets xdg-utils

if [[ ${PV} == 9999 ]] ; then
	EGIT_REPO_URI="https://github.com/amule-project/amule"
	inherit git-r3
else
	SRC_URI="https://github.com/amule-project/amule/archive/refs/tags/3.0.0.tar.gz -> amule-3.0.0.tar.gz"
	KEYWORDS="~alpha amd64 ~arm ~mips ppc ppc64 ~riscv ~sparc x86"
fi

DESCRIPTION="aMule, the all-platform eMule p2p client"
HOMEPAGE="https://www.amule.org/"

LICENSE="GPL-2+"
SLOT="0"
IUSE="daemon debug geoip +gui nls remote stats upnp"

RDEPEND="
	>=dev-libs/boost-1.70:=
	>=dev-libs/crypto++-5.6:=
	sys-libs/binutils-libs:0=
	sys-libs/readline:0=
	virtual/zlib:=
	x11-libs/wxGTK:${WX_GTK_VER}=[curl]
	daemon? ( acct-user/amule )
	geoip? ( dev-libs/libmaxminddb:= )
	gui? ( x11-libs/wxGTK:${WX_GTK_VER}=[X,curl] )
	nls? ( virtual/libintl )
	remote? (
		acct-user/amule
		media-libs/libpng:0=
	)
	stats? ( >=media-libs/gd-2.0:=[jpeg,png] )
	upnp? ( net-libs/libupnp:0= )
"
DEPEND="${RDEPEND}
	gui? ( dev-util/desktop-file-utils )
"
BDEPEND="
	>=dev-build/cmake-3.10
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
"

PATCHES=()

src_prepare() {
	cmake_src_prepare
}

src_configure() {
	setup-wxwidgets

	# Let the cmake eclass default to RelWithDebInfo; only override for debug USE
	use debug && CMAKE_BUILD_TYPE=Debug

	# Determine compound USE combinations
	local remotegui=OFF
	use gui && use remote && remotegui=ON

	local alc=OFF wxcas=OFF
	if use gui && use stats; then
		alc=ON
		wxcas=ON
	fi

	local mycmakeargs=(
		# Identify this as a packaged release, not a git snapshot
		-DGITDATE="${PV}"
		# Point cmake at the right wxGTK slot selected by setup-wxwidgets
		-DwxWidgets_CONFIG_EXECUTABLE="${WX_CONFIG}"
		# Always build the command-line client and ed2k link handler
		-DBUILD_AMULECMD=ON
		-DBUILD_ED2K=ON
		# Disable fetching missing dependencies from the internet
		-DDOWNLOAD_AND_BUILD_DEPS=OFF
		# Don't compile test suite during normal builds
		-DBUILD_TESTING=OFF
		# USE flag mappings
		-DBUILD_MONOLITHIC=$(usex gui ON OFF)
		-DBUILD_DAEMON=$(usex daemon ON OFF)
		-DBUILD_WEBSERVER=$(usex remote ON OFF)
		-DBUILD_REMOTEGUI="${remotegui}"
		-DBUILD_ALCC=$(usex stats ON OFF)
		-DBUILD_CAS=$(usex stats ON OFF)
		-DBUILD_ALC="${alc}"
		-DBUILD_WXCAS="${wxcas}"
		-DENABLE_IP2COUNTRY=$(usex geoip ON OFF)
		-DENABLE_NLS=$(usex nls ON OFF)
		-DENABLE_UPNP=$(usex upnp ON OFF)
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	if use daemon; then
		newconfd "${FILESDIR}"/amuled.confd-r1 amuled
		newinitd "${FILESDIR}"/amuled.initd amuled
	fi
	if use remote; then
		newconfd "${FILESDIR}"/amuleweb.confd-r1 amuleweb
		newinitd "${FILESDIR}"/amuleweb.initd amuleweb
	fi

	if use daemon || use remote; then
		keepdir /var/lib/${PN}
		fowners amule:amule /var/lib/${PN}
		fperms 0750 /var/lib/${PN}
	fi
}

pkg_postinst() {
	use gui && xdg_desktop_database_update
}

pkg_postrm() {
	use gui && xdg_desktop_database_update
}
