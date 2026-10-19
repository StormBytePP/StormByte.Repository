# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Network module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Network"

LICENSE="LGPL-3"

# The link edge is Buffer. Logger and System are Buffer's public deps and
# are requested by find_package(); the core library comes with all of them.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte)
	$(stormbyte-suite_dep dev-libs/StormByte-Buffer)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger)
	$(stormbyte-suite_dep dev-libs/StormByte-System)
"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_STORMBYTE=SYSTEM
	)
}
