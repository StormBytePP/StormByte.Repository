# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="StormByte Multimedia module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Multimedia"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormByte-Suite/${PN}.git"
else
	SRC_URI="https://github.com/StormByte-Suite/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~x86"
fi

LICENSE="LGPL-3"
SLOT="0"
IUSE="lto"

DEPEND="
	>=dev-libs/StormByte-2.0.0
	>=dev-libs/StormByte-Buffer-2.0.0
	>=dev-libs/StormByte-Logger-2.0.0
	>=dev-libs/StormByte-System-2.0.0

	app-text/tesseract
	media-libs/libebur128
	media-libs/libvmaf
	media-libs/zimg
	>=media-video/ffmpeg-9.0.0[bzip2,dav1d,fdk,gpl,kvazaar,lame,libaom,libass,openh264,opus,rav1e,srt,svt-av1,vorbis,vpx,webp,x264,x265]
"
RDEPEND="${DEPEND}"
BDEPEND="
	>=dev-build/cmake-3.21
	>=dev-build/StormByte-BuildMaster-2.0.3
"

src_prepare() {
	cmake_src_prepare

	# Tarball lacks for submodules
	local empty_submodules=(
		buildmaster/CMakeLists.txt
		buildmaster/helpers.cmake
	)

	local file
	for file in "${empty_submodules[@]}"; do
		touch "${file}" || die
	done
}

src_configure() {
	local mycmakeargs=(
		-DWITH_LIBEBUR128=SYSTEM
		-DWITH_FFMPEG=SYSTEM
		-DWITH_OCR=SYSTEM
		-DWITH_VMAF=SYSTEM
		-DWITH_ZIMG=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DENABLE_TEST=OFF
	)

	cmake_src_configure
}
