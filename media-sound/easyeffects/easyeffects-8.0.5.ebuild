# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs xdg-utils

DESCRIPTION="Limiter, auto volume and many other plugins for PipeWire applications"
HOMEPAGE="https://github.com/wwmm/easyeffects"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/wwmm/easyeffects"
else
	SRC_URI="https://github.com/wwmm/easyeffects/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="amd64 ~arm ~arm64 ~ppc64 ~x86"
fi

LICENSE="GPL-3"
SLOT="0"
IUSE=""

COMMON_DEPEND="
	dev-cpp/nlohmann_json
	dev-cpp/tbb
	>=dev-libs/glib-2.56:2
	dev-libs/libfmt
	>=dev-libs/libsigc++-3.0.6:3
	>=gui-libs/gtk-4.10.0:4
	>=gui-libs/libadwaita-1.2.0:1
	media-libs/libbs2b
	>=media-libs/libebur128-1.2.0
	media-libs/libsndfile
	media-libs/libsoundtouch
	>=media-libs/lilv-0.22
	>=media-libs/lv2-1.18.2
	media-libs/rnnoise
	media-libs/speexdsp
	>=media-libs/zita-convolver-3.0.0
	>=media-video/pipewire-0.3.41
	sci-libs/gsl:=
	sci-libs/fftw:3.0
"
# Only header files are used from these two
DEPEND="
	${COMMON_DEPEND}
	media-libs/ladspa-sdk
	media-libs/libsamplerate
"
RDEPEND="
	${COMMON_DEPEND}
	>=media-libs/lsp-plugins-1.2.10[lv2]
	sys-apps/dbus
	dev-qt/qtgraphs
	kde-frameworks/qqc2-desktop-style
	dev-libs/kirigami-addons
"
BDEPEND="
	dev-libs/appstream-glib
	dev-util/desktop-file-utils
	dev-util/itstool
	sys-devel/gettext
	virtual/pkgconfig
"

pkg_pretend() {
	if [[ ${MERGE_TYPE} != "binary" ]] ; then
		if ! tc-is-gcc; then
			if ! tc-is-clang || [[ $(clang-major-version) -lt 16 ]]; then
				die "${PN} can only be built with GCC or >=Clang-16 due to required level of C++20 support"
			fi
		elif [[ $(gcc-major-version) -lt 11 ]] ; then
			die "Since version 6.2.5, ${PN} requires GCC 11 or newer to build (bug #848072)"
		fi
	fi
}

src_configure() {
	local libcxx=false
	[[ $(tc-get-cxx-stdlib) == "libc++" ]] && libcxx=true

	local mycmakeargs=(
		-DENABLE_LIBCPP_WORKAROUNDS=${libcxx}
		-DENABLE_RNNOISE=ON
	)

	cmake_src_configure
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}
