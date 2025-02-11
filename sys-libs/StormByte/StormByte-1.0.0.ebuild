EAPI=7

inherit cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://github.com/StormBytePP/StormByte"
SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"

DEPEND="
	dev-db/sqlite:3
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
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