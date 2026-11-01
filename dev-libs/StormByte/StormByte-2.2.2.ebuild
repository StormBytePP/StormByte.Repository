# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte C++ library"
HOMEPAGE="https://suite.stormbyte.org/StormByte"

LICENSE="LGPL-3"
IUSE+=" buffer config crypto database logger multimedia network system"

PATCHES=( "${FILESDIR}/${PN}-2.2.2-system-sds.patch" )

DEPEND=">=dev-libs/sds-2.0.0:="
RDEPEND="${DEPEND}"

# Modules are optional add-ons installed after the core library.
# PDEPEND avoids the cycle (every module links this package).
PDEPEND="
	buffer? ( $(stormbyte-suite_dep dev-libs/StormByte-Buffer post) )
	config? ( $(stormbyte-suite_dep dev-libs/StormByte-Config post) )
	crypto? ( $(stormbyte-suite_dep dev-libs/StormByte-Crypto post) )
	database? ( $(stormbyte-suite_dep dev-libs/StormByte-Database post) )
	logger? ( $(stormbyte-suite_dep dev-libs/StormByte-Logger post) )
	multimedia? ( $(stormbyte-suite_dep dev-libs/StormByte-Multimedia post) )
	network? ( $(stormbyte-suite_dep dev-libs/StormByte-Network post) )
	system? ( $(stormbyte-suite_dep dev-libs/StormByte-System post) )
"
