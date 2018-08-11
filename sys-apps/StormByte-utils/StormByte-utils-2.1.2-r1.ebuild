# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Utils from StormByte"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	sys-apps/StormByteStageManager
	sys-apps/coreutils
	sys-apps/findutils
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
	dobin "${FILESDIR}/findcontent"
	dobin "${FILESDIR}/portage-config"
}

