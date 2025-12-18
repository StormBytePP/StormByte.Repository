EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByteDatabase"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+mariadb +postgres +sqlite"

DEPEND="
	dev-libs/StormByte
	dev-libs/StormByte-Logger
	mariadb? ( dev-db/mariadb-connector-c )
	postgres? ( dev-db/postgresql )
	sqlite? ( dev-db/sqlite:3 )
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	local mycmakeargs=(
		-DWITH_MARIADB=$(usex mariadb SYSTEM OFF)
		-DWITH_POSTGRES=$(usex postgres SYSTEM OFF)
		-DWITH_SQLITE=$(usex sqlite SYSTEM OFF)
		-DWITH_STORMBYTE=SYSTEM
	)
	cmake_src_configure
}
