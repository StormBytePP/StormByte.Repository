# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Crypto module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Crypto"

LICENSE="LGPL-3"

# Upstream links Buffer (which public-links Logger and System) plus the
# core library. All three are spelled out. zlib.h is included directly.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Buffer 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger 3.0.0)
	$(stormbyte-suite_dep dev-libs/StormByte-System 3.0.0)
	app-arch/bzip2:=
	dev-libs/crypto++:=
	>=dev-libs/openssl-3.0:=
	virtual/zlib:=
"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_BZIP2=SYSTEM
		-DWITH_CRYPTOPP=SYSTEM
		-DWITH_OPENSSL=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
	)
}
