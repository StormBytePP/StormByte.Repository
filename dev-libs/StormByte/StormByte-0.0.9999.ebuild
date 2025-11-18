EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByte"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="config crypto database multimedia network system test"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"
PDEPEND="
	config? ( dev-libs/StormByte-Config )
	crypto? ( dev-libs/StormByte-Crypto )
	database? ( dev-libs/StormByte-Database )
	multimedia? ( dev-libs/StormByte-Multimedia )
	network? ( dev-libs/StormByte-Network )
	system? ( dev-libs/StormByte-System )
"

src_configure() {
	local mycmakeargs=(
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