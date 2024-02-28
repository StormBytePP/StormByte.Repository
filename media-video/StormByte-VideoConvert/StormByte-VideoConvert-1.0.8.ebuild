EAPI=7

inherit cmake

DESCRIPTION="StormByte Video Converter"
HOMEPAGE="https://github.com/StormBytePP/StormByte-videoconvert"
SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+x265 +fdk +opus -static-libs"

DEPEND="
	dev-libs/boost
	dev-db/sqlite:3[static-libs?]
	dev-libs/libconfig[cxx,static-libs?]
	media-video/ffmpeg[encode]
	x265? ( media-video/ffmpeg[x265] )
	fdk? ( media-video/ffmpeg[fdk] )
	opus? ( media-video/ffmpeg[opus] )
"
RDEPEND="${DEPEND}"
BDEPEND=""

src_configure() {
	ls "${S}"
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

pkg_preinst() {
	chmod +x "${D}/etc/init.d/StormByte-VideoConvert"
}

