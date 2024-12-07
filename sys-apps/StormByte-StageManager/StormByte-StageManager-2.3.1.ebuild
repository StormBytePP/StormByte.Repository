# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit linux-info

DESCRIPTION="StormByte's Stage Manager"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI="https://github.com/StormBytePP/StormByte-StageManager/archive/${PV}.tar.gz -> StormByte-StageManager-${PV}.tar.gz"

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="pbzip2 +pigz +pxz"

RDEPEND="
	app-alternatives/bzip2[pbzip2=]
	app-alternatives/gzip[pigz=]
	pxz? ( app-arch/pxz )
	!pxz? ( app-arch/xz-utils )
	app-arch/tar
	app-arch/zstd
	net-misc/curl
	sys-apps/coreutils
	sys-apps/pv
	sys-fs/btrfs-progs
	sys-libs/StormByte-functions
"
DEPEND="${RDEPEND}"

pkg_pretend() {
	CONFIG_CHECK="BTRFS_FS"
	ERROR_BTRFS_FS="BTRFS MUST be enabled on kernel for this to work"
	check_extra_config
}

src_install() {
	dobin "${S}/StormByte-StageManager"
	doconfd "${S}/StormByte-StageManager.conf"
}

