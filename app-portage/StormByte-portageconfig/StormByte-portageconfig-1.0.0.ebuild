# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's Portage Config Helper"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND=""
DEPEND=""

src_unpack() {
	#Since there are no downloaded files, this is dummy to prevent folder not exist error
	mkdir "${S}"
}

src_install() {
	dobin "${FILESDIR}/stormbyte-portageconfig"
}

