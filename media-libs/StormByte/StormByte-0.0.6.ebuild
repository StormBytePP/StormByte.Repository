EAPI=7

inherit cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://github.com/StormBytePP/StormByte"
SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND="
	dev-db/sqlite:3
	>=dev-libs/libconfig-1.7.3[cxx]
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DWITH_SYSTEM_CONFIG++=ON
		-DWITH_SYSTEM_SQLITE=ON
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
}
