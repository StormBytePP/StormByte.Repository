# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Buffer module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Buffer"

LICENSE="LGPL-3"

# Logger and System are public link dependencies, not only transitive.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger)
	$(stormbyte-suite_dep dev-libs/StormByte-System)
"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_STORMBYTE=SYSTEM
	)
}
