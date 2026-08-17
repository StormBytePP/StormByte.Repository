# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic toolchain-funcs

DESCRIPTION="StormByte Database module"
HOMEPAGE="https://dev.stormbyte.org/StormByte-Database"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"
else
	SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86 ~arm ~arm64"
fi

LICENSE="LGPL-3"
SLOT="0"
IUSE="+mariadb +postgres +sqlite lto"

DEPEND="
	dev-libs/StormByte
	dev-libs/StormByte-Logger
	mariadb? ( dev-db/mariadb-connector-c )
	postgres? ( dev-db/postgresql )
	sqlite? ( dev-db/sqlite:3 )
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_prepare() {
	cmake_src_prepare

	# Tarball lacks for submodules
	local empty_submodules=(
		thirdparty/buildmaster/CMakeLists.txt
		thirdparty/buildmaster/helpers.cmake
	)

	local file
	for file in "${empty_submodules[@]}"; do
		touch "${file}" || die
	done
}

src_configure() {
	local mycmakeargs=(
		-DWITH_MARIADB=$(usex mariadb SYSTEM OFF)
		-DWITH_POSTGRES=$(usex postgres SYSTEM OFF)
		-DWITH_SQLITE=$(usex sqlite SYSTEM OFF)
		-DWITH_STORMBYTE=SYSTEM
		-DENABLE_TEST=OFF
	)

	cmake_src_configure
}
