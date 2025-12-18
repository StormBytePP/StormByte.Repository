EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByte"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="buffer config crypto database logger multimedia network system"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"
PDEPEND="
	buffer? ( dev-libs/StormByte-Buffer )
	config? ( dev-libs/StormByte-Config )
	crypto? ( dev-libs/StormByte-Crypto )
	database? ( dev-libs/StormByte-Database )
	logger? ( dev-libs/StormByte-Logger )
	multimedia? ( dev-libs/StormByte-Multimedia )
	network? ( dev-libs/StormByte-Network )
	system? ( dev-libs/StormByte-System )
"

src_configure() {
	cmake_src_configure
}
