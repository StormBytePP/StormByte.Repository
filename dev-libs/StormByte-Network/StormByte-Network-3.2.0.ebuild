# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Network module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Network"

LICENSE="LGPL-3"

# DiscoveryTest sends a UDP broadcast. Portage network-sandbox has no
# route for 255.255.255.255, so sendto fails with ENETUNREACH and the
# PGO training ctest fails. Allow the real network stack.
RESTRICT="network-sandbox"

# HTTP/2 uses nghttp2; TLS uses Crypto. All StormByte components requested
# by find_package() are explicit dependencies.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Buffer 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Crypto 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-System 3.0.0)
	net-libs/nghttp2:=
"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_NGHTTP2=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
	)
}
