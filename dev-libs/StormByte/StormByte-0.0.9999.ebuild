EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByte"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="buffer config crypto database multimedia network system test"
RESTRICT="!test? ( test )"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"
PDEPEND="
	buffer? ( dev-libs/StormByte-Buffer[test?] )
	config? ( dev-libs/StormByte-Config[test?] )
	crypto? ( dev-libs/StormByte-Crypto[test?] )
	database? ( dev-libs/StormByte-Database[test?] )
	multimedia? ( dev-libs/StormByte-Multimedia[test?] )
	network? ( dev-libs/StormByte-Network[test?] )
	system? ( dev-libs/StormByte-System[test?] )
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