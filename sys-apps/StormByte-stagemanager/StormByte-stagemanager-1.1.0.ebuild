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
	sys-libs/StormByte-functions
	sys-apps/coreutils
	app-arch/pigz
	app-arch/pbzip2
	app-arch/pxz
	app-arch/tar
	net-misc/curl
	sys-fs/btrfs-progs
"
DEPEND="${RDEPEND}
"

src_unpack() {
	#Since there are no downloaded files, this is dummy to prevent folder not exist error
	mkdir "${S}"
}

src_install() {
	dobin "${FILESDIR}/stormbyte-stagemanager"
	doconfd "${FILESDIR}/stormbyte-stagemanager.conf"
}

