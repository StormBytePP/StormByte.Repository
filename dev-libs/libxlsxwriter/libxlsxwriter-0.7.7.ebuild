# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit cmake-utils

SRC_URI="https://github.com/jmcnamara/libxlsxwriter/archive/RELEASE_${PV}.zip -> ${PV}.zip"


DESCRIPTION="A C library for creating Excel XLSX files"
HOMEPAGE="https://libxlsxwriter.github.io"


LICENSE="LGPL-2.1"
SLOT="1"
IUSE="+system-minizip +minizip +standard-tmpfile"
REQUIRED_USE="minizip"
KEYWORDS="~x86 ~amd64"


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
	unpack ${A}
	#Workaround to have the folder created with the expected name
	mv ${WORKDIR}/* ${WORKDIR}/${PF}
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





