# Copyright 1999-2026 StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info

DESCRIPTION="StormByte's Stage Manager"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI="https://github.com/StormBytePP/StormByte-StageManager/archive/${PV}.tar.gz -> StormByte-StageManager-${PV}.tar.gz"

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="+lbzip2 +pigz +pxz +zram"

RDEPEND="
	app-alternatives/bzip2[lbzip2=]
	app-alternatives/gzip[pigz=]
	pxz? ( app-arch/pxz )
	!pxz? ( app-arch/xz-utils )
	app-arch/tar
	app-arch/zstd
	net-misc/curl
	sys-apps/coreutils
	sys-apps/pv
	>=sys-libs/StormByte-functions-4.2.0[bash]
	sys-fs/e2fsprogs
"

DEPEND="${RDEPEND}"

pkg_pretend() {
	if use zram; then
		CHECK_REQUIRED="ZRAM || ( EXT2_FS EXT4_USE_FOR_EXT2 )"

		ERROR_ZRAM="ZRAM MUST be enabled on kernel for this to work"
		ERROR_EXT2_FS="EXT2_FS or EXT4_USE_FOR_EXT2 must be enabled when using zram"
		ERROR_EXT4_USE_FOR_EXT2="EXT2_FS or EXT4_USE_FOR_EXT2 must be enabled when using zram"
	fi

	check_extra_config
}

src_install() {
	dobin "${S}/StormByte-StageManager"
	doconfd "${S}/StormByte-StageManager.conf"
	insinto /usr/share/bash-completion/completions
	newins "${S}/StormByte-StageManager.bash-completion" StormByte-StageManager
}