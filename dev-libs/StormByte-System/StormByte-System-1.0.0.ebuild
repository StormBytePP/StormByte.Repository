EAPI=7

inherit cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://github.com/StormBytePP/StormByte-System"
SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"

DEPEND="
	dev-libs/StormByte
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DWITH_SYSTEM_STORMBYTE=ON
		-DENABLE_TEST=$(usex test ON OFF)
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
}

src_test() {
	cmake_src_test
}