EAPI=7

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByteConfig"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"

DEPEND="
	app-arch/bzip2
	dev-libs/crypto++
	dev-libs/StormByte
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DWITH_SYSTEM_STORMBYTE=ON
		-DWITH_SYSTEM_CRYPTOPP=ON
		-DWITH_SYSTEM_BZIP2=ON
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