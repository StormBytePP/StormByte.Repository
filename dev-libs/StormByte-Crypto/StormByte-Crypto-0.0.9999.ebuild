EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByteConfig"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND="
	app-arch/bzip2
	dev-libs/crypto++
	dev-libs/StormByte
	dev-libs/StormByte-Buffer
	dev-libs/StormByte-Logger
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DWITH_BZIP2=SYSTEM
		-DWITH_CRYPTOPP=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
	)
	cmake_src_configure
}
