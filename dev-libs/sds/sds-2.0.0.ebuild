# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Simple dynamic strings library for C"
HOMEPAGE="https://github.com/StormBytePP/sds"
SRC_URI="https://github.com/StormBytePP/sds/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="~amd64 ~arm ~arm64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

src_prepare() {
	cp "${FILESDIR}/CMakeLists.txt" . || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DSDS_VERSION="${PV}"
		-DBUILD_TESTING=$(usex test)
	)
	cmake_src_configure
}
