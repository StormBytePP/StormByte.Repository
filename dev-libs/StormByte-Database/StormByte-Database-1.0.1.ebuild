EAPI=7

inherit cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://github.com/StormBytePP/StormByteDatabase"
SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+sqlite test"

DEPEND="
	sqlite? ( dev-db/sqlite:3 )
	dev-libs/StormByte
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DENABLE_SQLITE=ON
		-DWITH_SYSTEM_STORMBYTE=ON
		-DWITH_SYSTEM_SQLITE=ON
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