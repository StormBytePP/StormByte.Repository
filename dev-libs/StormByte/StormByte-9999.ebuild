# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte C++ library"
HOMEPAGE="https://suite.stormbyte.org/StormByte"

LICENSE="LGPL-3"
IUSE+=" buffer config crypto database logger multimedia network system"

DEPEND=">=dev-libs/sds-2.0.0:="
RDEPEND="${DEPEND}"

# Modules are optional add-ons installed after the core library.
# PDEPEND avoids the cycle (every module links this package).
PDEPEND="
	buffer? ( $(stormbyte-suite_dep dev-libs/StormByte-Buffer 3.0.0 post) )
	config? ( $(stormbyte-suite_dep dev-libs/StormByte-Config 3.0.0 post) )
	crypto? ( $(stormbyte-suite_dep dev-libs/StormByte-Crypto 3.0.0 post) )
	database? ( $(stormbyte-suite_dep dev-libs/StormByte-Database 3.0.0 post) )
	logger? ( $(stormbyte-suite_dep dev-libs/StormByte-Logger 3.0.0 post) )
	multimedia? ( $(stormbyte-suite_dep dev-libs/StormByte-Multimedia 3.0.0 post) )
	network? ( $(stormbyte-suite_dep dev-libs/StormByte-Network 3.2.0 post) )
	system? ( $(stormbyte-suite_dep dev-libs/StormByte-System 3.0.0 post) )
"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DSTORMBYTE_USE_SYSTEM_SDS=ON
	)
}
