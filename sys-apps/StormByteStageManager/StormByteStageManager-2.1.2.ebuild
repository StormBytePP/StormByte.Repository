# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's Stage Manager"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	sys-apps/coreutils
	app-shells/bash
	app-arch/pigz
	app-arch/pbzip2
	app-arch/pxz
"
DEPEND="${RDEPEND}
"

src_unpack() {
	#Since there are no downloaded files, this is dummy to prevent folder not exist error
	mkdir "${S}"
}

src_install() {
	dobin "${FILESDIR}/stormbyte-stage-manager"
	doconfd "${FILESDIR}/stormbyte-stage-manager.conf"
}

