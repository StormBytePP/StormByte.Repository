# Copyright 2025 StormByte
# Distributed under the terms of the GPL license

EAPI=8

inherit cmake

DESCRIPTION="StormByte Video Converter (Alchemist project)"
HOMEPAGE="https://github.com/StormBytePP/Alchemist"
SRC_URI="https://github.com/StormBytePP/Alchemist/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+x265 +fdk +opus -static-libs"

DEPEND="
    dev-libs/boost
    dev-db/sqlite:3[static-libs?]
    dev-libs/libconfig[cxx,static-libs?]
    media-video/ffmpeg
    x265? (
        media-video/ffmpeg[x265]
        media-video/hdr10plus_tool
    )
    fdk? ( media-video/ffmpeg[fdk] )
    opus? ( media-video/ffmpeg[opus] )
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.30.0"

# El tarball se descomprime en Alchemist-${PV}
S="${WORKDIR}/Alchemist-${PV}"

src_configure() {
    local mycmakeargs=(
        -DCMAKE_BUILD_TYPE=Release
        -DENABLE_HEVC=$(usex x265)
        -DENABLE_FDKAAC=$(usex fdk)
        -DENABLE_OPUS=$(usex opus)
        -DENABLE_AAC=ON
        -DENABLE_AC3=ON
        -DENABLE_EAC3=ON
        -DENABLE_STATIC=$(usex static-libs)
    )
    cmake_src_configure
}

src_install() {
    doinitd "${FILESDIR}/StormByte-VideoConvert"
    doconfd "${FILESDIR}/StormByte-VideoConvert.conf"

    cmake_src_install
}
