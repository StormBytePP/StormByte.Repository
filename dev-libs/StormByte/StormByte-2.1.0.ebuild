# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte C++ library"
HOMEPAGE="https://suite.stormbyte.org/StormByte"

LICENSE="LGPL-3 BSD"
IUSE+=" buffer config crypto database logger multimedia network system"

# GitHub tag archives leave the sds submodule empty. The library compiles
# thirdparty/sds/*.c directly, so the release ebuild unpacks that tree.
# The live ebuild fetches only this submodule.
if [[ ${PV} == 9999 ]]; then
	EGIT_SUBMODULES=( thirdparty/sds )
else
	SRC_URI+=" https://github.com/StormBytePP/sds/archive/refs/tags/2.0.0.tar.gz -> sds-2.0.0.tar.gz"
fi

# Modules are optional add-ons installed after the core library.
# PDEPEND avoids the cycle (every module links this package).
PDEPEND="
	buffer? ( $(stormbyte-suite_dep dev-libs/StormByte-Buffer) )
	config? ( $(stormbyte-suite_dep dev-libs/StormByte-Config) )
	crypto? ( $(stormbyte-suite_dep dev-libs/StormByte-Crypto) )
	database? ( $(stormbyte-suite_dep dev-libs/StormByte-Database) )
	logger? ( $(stormbyte-suite_dep dev-libs/StormByte-Logger) )
	multimedia? ( $(stormbyte-suite_dep dev-libs/StormByte-Multimedia) )
	network? ( $(stormbyte-suite_dep dev-libs/StormByte-Network) )
	system? ( $(stormbyte-suite_dep dev-libs/StormByte-System) )
"

src_prepare() {
	# 2.1.0's finder rejects the Base component. Buffer, Crypto, Database,
	# Multimedia and Network request it. The core library is already found.
	eapply "${FILESDIR}/stormbyte-2.1.0-find-base.patch"
	stormbyte-suite_src_prepare
}

src_unpack() {
	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
		return
	fi

	default
	rm -rf "${S}/thirdparty/sds" || die
	mv "${WORKDIR}/sds-2.0.0" "${S}/thirdparty/sds" || die
}
