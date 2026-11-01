# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="SVG rendering and manipulation library"
HOMEPAGE="https://github.com/sammycage/lunasvg"
SRC_URI="https://github.com/sammycage/lunasvg/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/3"
KEYWORDS="~amd64 ~arm ~arm64 ~x86"
IUSE="+system-fonts"

DEPEND=">=media-libs/plutovg-1.3.0:="
RDEPEND="${DEPEND}"

PATCHES=( "${FILESDIR}/${PN}-3.5.0-system-plutovg.patch" )

src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=ON
		-DLUNASVG_BUILD_EXAMPLES=OFF
		-DLUNASVG_DISABLE_LOAD_SYSTEM_FONTS=$(usex system-fonts OFF ON)
	)
	cmake_src_configure
}
