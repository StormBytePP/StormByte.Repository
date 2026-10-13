# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Tests need real database servers, users and credentials, so they cannot
# train a profile. The profile enables pgo globally; this package does not
# advertise the flag. The -9999 ebuild is the same file content.
STORMBYTE_NO_PGO=1
inherit stormbyte-suite

DESCRIPTION="StormByte Database module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Database"

LICENSE="LGPL-3"
IUSE+=" +mariadb mssql +postgres +sqlite"

# Logger public-links the core library; both are required explicitly.
# OpenSSL cannot be disabled upstream (WITH_OPENSSL is SYSTEM or BUNDLED).
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger)
	dev-libs/openssl:=
	mariadb? ( dev-db/mariadb-connector-c:= )
	mssql? ( dev-db/freetds:= )
	postgres? ( dev-db/postgresql:= )
	sqlite? ( dev-db/sqlite:3= )
"
RDEPEND="${DEPEND}"

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_MARIADB=$(usex mariadb SYSTEM OFF)
		-DWITH_MSSQL=$(usex mssql SYSTEM OFF)
		-DWITH_OPENSSL=SYSTEM
		-DWITH_POSTGRES=$(usex postgres SYSTEM OFF)
		-DWITH_SQLITE=$(usex sqlite SYSTEM OFF)
		-DWITH_STORMBYTE=SYSTEM
	)
}
