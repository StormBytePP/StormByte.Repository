# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit cmake-utils git-r3

EGIT_REPO_URI="https://github.com/jmcnamara/libxlsxwriter.git"
EGIT_BRANCH="origin/HEAD"
EGIT_COMMIT="HEAD"
EGIT_CHECKOUT_DIR="${S}"

SRC_URI=""


DESCRIPTION="XXXXX"
HOMEPAGE="XXXXX"


LICENSE="LGPL-2.1"
SLOT="${PV}"
IUSE="+system-minizip +minizip +standard-tmpfile"
REQUIRED_USE="minizip"


COMMON_DEPEND="
	sys-libs/zlib
"
DEPEND="
	dev-util/cmake
"
RDEPEND="
	${COMMON_DEPEND}
	minizip? ( sys-libs/zlib[minizip] )
"

src_unpack() {
	git-r3_src_unpack
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DBUILD_SHARED_LIBS=ON
		-DUSE_SYSTEM_MINIZIP="$(usex system-minizip)"
		-DUSE_STANDARD_TMPFILE="$(usex standard-tmpfile)"
	)
	cmake-utils_src_configure
}





