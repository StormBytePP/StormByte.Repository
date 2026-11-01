# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake-multilib

DESCRIPTION="Tiny 2D vector graphics library in C"
HOMEPAGE="https://github.com/sammycage/plutovg"
SRC_URI="https://github.com/sammycage/plutovg/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/1"
KEYWORDS="~amd64 ~arm ~arm64 ~x86"
IUSE="+font-face-cache"

multilib_src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=ON
		-DPLUTOVG_BUILD_EXAMPLES=OFF
		-DPLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD=$(usex font-face-cache OFF ON)
	)
	cmake_src_configure
}
