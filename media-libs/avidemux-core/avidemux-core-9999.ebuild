# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_MAKEFILE_GENERATOR="emake"
inherit cmake flag-o-matic git-r3 toolchain-funcs

DESCRIPTION="Core libraries for simple video cutting, filtering and encoding tasks"
HOMEPAGE="http://fixounet.free.fr/avidemux"
EGIT_REPO_URI="https://github.com/mean00/avidemux2.git"

# Multiple licenses because of all the bundled stuff.
# See License.txt.
LICENSE="GPL-2 MIT PSF-2 LGPL-2 OFL-1.1"
SLOT="2.7"
KEYWORDS="~amd64 ~x86"
IUSE="debug nls nvenc sdl system-ffmpeg vaapi vdpau xv"

# Trying to use virtual; ffmpeg misses aac,cpudetection USE flags now though, are they needed?
DEPEND="
	dev-db/sqlite:3
	sys-libs/zlib
	nvenc? ( amd64? ( >=media-libs/nv-codec-headers-11.1.5.3 ) )
	sdl? ( media-libs/libsdl )
	system-ffmpeg? ( >=media-video/ffmpeg-9:0[mp3,theora] )
	vaapi? ( media-libs/libva:= )
	vdpau? ( x11-libs/libvdpau )
	xv? ( x11-libs/libXv )
"
RDEPEND="
	${DEPEND}
	!<media-libs/avidemux-core-${PV}
	!<media-video/avidemux-${PV}
	nls? ( virtual/libintl )
"
BDEPEND="
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
	!system-ffmpeg? ( dev-lang/yasm[nls=] )
"

CMAKE_USE_DIR="${S}/${PN/-/_}"

src_unpack() {
	git-r3_src_unpack
}

src_prepare() {
	cmake_src_prepare

	if use system-ffmpeg ; then
		# Preparations to support the system ffmpeg. Currently fails because
		# it depends on files the system ffmpeg doesn't install.
		local error="Failed to remove bundled ffmpeg."

		die ${error}

		rm -r cmake/admFFmpeg* cmake/ffmpeg* avidemux_core/ffmpeg_package || die "${error}"
		sed -e 's/include(admFFmpegUtil)//g' -e '/registerFFmpeg/d' -i cmake/commonCmakeApplication.cmake || die "${error}"
		sed -e 's/include(admFFmpegBuild)//g' -i avidemux_core/CMakeLists.txt || die "${error}"
		for file in avidemux_core/ADM_core/src/CMakeLists.txt avidemux_core/ADM_coreAudioParser/src/CMakeLists.txt avidemux_core/ADM_coreImage/src/CMakeLists.txt avidemux_core/ADM_coreMuxer/src/CMakeLists.txt avidemux_core/ADM_coreMuxer/src/CMakeLists.txt avidemux_core/ADM_coreUtils/src/CMakeLists.txt avidemux_core/ADM_coreVideoCodec/src/CMakeLists.txt avidemux_core/ADM_coreVideoEncoder/src/CMakeLists.txt; do
			sed -e 's/ADM_libavutil/avutil/g' -e 's/ADM_libavcodec/avcodec/g' -e 's/ADM_libavformat/avformat/g' -e 's/ADM_libswscale/swscale/g' -e 's/ADM_libpostproc/postproc/g' -i ${file} || die "${error}"
		done

	else
		local ffmpeg_args=(
			--cc=$(tc-getCC)
			--cxx=$(tc-getCXX)
			--ar=$(tc-getAR)
			--nm=$(tc-getNM)
			--ranlib=$(tc-getRANLIB)
			"--optflags='${CFLAGS}'"
		)
	fi
}

src_configure() {
	if ! use system-ffmpeg ; then
		# Delete non applicable patches
		rm -f avidemux_core/ffmpeg_package/patches/libavcodec_mathops.h_binutils_241.patch
	fi

	# See bug 432322.
	use x86 && replace-flags -O0 -O1

	local mycmakeargs=(
		-DGETTEXT="$(usex nls)"
		-DSDL="$(usex sdl)"
		-DLIBVA="$(usex vaapi)"
		-DNVENC="$(usex nvenc)"
		-DVDPAU="$(usex vdpau)"
		-DXVIDEO="$(usex xv)"
	)

	use debug && mycmakeargs+=( -DVERBOSE=1 -DADM_DEBUG=1 )

	cmake_src_configure
}

src_compile() {
	cmake_src_compile
}

src_install() {
	cmake_src_install
}
