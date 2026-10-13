# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Config module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Config"

LICENSE="LGPL-3"

DEPEND="$(stormbyte-suite_dep dev-libs/StormByte)"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_STORMBYTE=SYSTEM
	)
}
