# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's Stage Manager"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI="https://github.com/StormBytePP/StormByte-StageManager/archive/${PV}.tar.gz -> StormByte-StageManager-${PV}.tar.gz"

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	sys-libs/StormByte-functions
	sys-apps/coreutils
	app-arch/pigz
	app-arch/pbzip2
	app-arch/pxz
	app-arch/zstd
	app-arch/tar
	net-misc/curl
	sys-fs/btrfs-progs
	sys-apps/pv
"
DEPEND="${RDEPEND}
"

src_install() {
	dobin "${S}/Stormbyte-StageManager"
	doconfd "${S}/Stormbyte-StageManager.conf"
}

