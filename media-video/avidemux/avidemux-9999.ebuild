# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_MAKEFILE_GENERATOR="emake"
inherit cmake desktop flag-o-matic git-r3 qmake-utils xdg

DESCRIPTION="Video editor designed for simple cutting, filtering and encoding tasks"
HOMEPAGE="http://fixounet.free.fr/avidemux"
EGIT_REPO_URI="https://github.com/mean00/avidemux2.git"

# Multiple licenses because of all the bundled stuff.
# See License.txt.
LICENSE="GPL-2 MIT PSF-2 LGPL-2 OFL-1.1"
SLOT="2.7"
KEYWORDS="~amd64 ~x86"
IUSE="debug nls opengl gui sdl vaapi vdpau xv"

BDEPEND="
	dev-lang/yasm
	gui? ( dev-qt/linguist-tools:5 )
"
DEPEND="
	~media-libs/avidemux-core-${PV}:${SLOT}[nls?,sdl?,vaapi?,vdpau?,xv?]
	opengl? ( virtual/opengl )
	gui? (
		dev-qt/qtbase:6[gui,opengl,widgets]
	)
	vaapi? ( media-libs/libva:= )
"
RDEPEND="
	${DEPEND}
	nls? ( virtual/libintl )
	!<media-video/avidemux-${PV}
"

PDEPEND="~media-libs/avidemux-plugins-${PV}:${SLOT}[opengl?,gui?]"

CMAKE_USE_DIR="${S}/${PN/-/_}"

src_unpack() {
	git-r3_src_unpack
}

src_prepare() {
	eapply "${FILESDIR}/${PN}-2.7.4-qt-5.15.patch"

	processes="buildCli:avidemux/cli"
	use gui && processes+=" buildQt4:avidemux/qt4"

	for process in ${processes} ; do
		CMAKE_USE_DIR="${S}"/${process#*:} cmake_src_prepare
	done

	if use gui; then
		# Fix icon name -> avidemux-2.7
		sed -i -e "/^Icon/ s:${PN}\.png:${PN}-${SLOT}:" appImage/"${PN}".desktop || die "Icon name fix failed."

		# The desktop file is broken. It uses avidemux3_portable instead of avidemux3_qt5
		sed -i -re '/^Exec/ s:(avidemux3_)portable:\1qt5:' appImage/"${PN}".desktop || die "Desktop file fix failed."

		# QA warnings: missing trailing ';' and 'Application' is deprecated.
		sed -i -e 's/Application;AudioVideo/AudioVideo;/g' appImage/"${PN}".desktop || die "Desktop file fix failed."

		# Now rename the desktop file to not collide with 2.6.
		mv appImage/"${PN}".desktop "${PN}-${SLOT}".desktop || die "Collision rename failed."
	fi
}

src_configure() {
	# See bug 432322.
	use x86 && replace-flags -O0 -O1

	# The build relies on an avidemux-core header that uses 'nullptr'
	# which is from >=C++11. Let's use the GCC-6 default C++ dialect.
	append-cxxflags -std=c++14

	local mycmakeargs=(
		-DGETTEXT="$(usex nls)"
		-DSDL="$(usex sdl)"
		-DXVIDEO="$(usex xv)"
	)

	use opengl && mycmakeargs+=(
		-DOPENGL="$(usex opengl)"
		-DOpenGL_GL_PREFERENCE=GLVND
	)

	use gui && mycmakeargs+=(
			-DENABLE_QT6="$(usex gui)"
			-DLRELEASE_EXECUTABLE="$(qt6_get_bindir)/lrelease"
	)

	use debug && mycmakeargs+=( -DVERBOSE=1 -DADM_DEBUG=1 )

	for process in ${processes} ; do
		local build="${WORKDIR}/${P}_build/${process%%:*}"
		CMAKE_USE_DIR="${S}"/${process#*:} BUILD_DIR="${build}" cmake_src_configure
	done
}

src_compile() {
	for process in ${processes} ; do
		local build="${WORKDIR}/${P}_build/${process%%:*}"
		BUILD_DIR="${build}" cmake_src_compile
	done
}

src_test() {
	for process in ${processes} ; do
		local build="${WORKDIR}/${P}_build/${process%%:*}"
		BUILD_DIR="${build}" cmake_src_test
	done
}

src_install() {
	for process in ${processes} ; do
		local build="${WORKDIR}/${P}_build/${process%%:*}"
		BUILD_DIR="${build}" cmake_src_install
	done

	if use gui; then
		cd "${S}" || die "Can't enter source folder"
		newicon "${PN}"_icon.png "${PN}-${SLOT}".png
		domenu "${PN}-${SLOT}".desktop
	fi
}
