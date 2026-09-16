# Copyright 1999-2026 StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info

DESCRIPTION="Gentoo stage tarball manager: chroot, convert, download and notes"
HOMEPAGE="https://github.com/StormBytePP/StormByte-StageManager"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormBytePP/StormByte-StageManager.git"
	KEYWORDS=""
else
	SRC_URI="https://github.com/StormBytePP/StormByte-StageManager/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-3"
SLOT="0"
IUSE="+lbzip2 +pigz +pxz +zram"

RDEPEND="
	app-admin/sudo
	app-arch/tar
	app-arch/zstd
	net-misc/curl
	sys-apps/coreutils
	sys-apps/findutils
	sys-apps/pv
	sys-apps/util-linux
	sys-fs/e2fsprogs
	lbzip2? ( app-alternatives/bzip2[lbzip2] )
	!lbzip2? ( app-arch/bzip2 )
	pigz? ( app-alternatives/gzip[pigz] )
	!pigz? ( app-arch/gzip )
	pxz? ( app-arch/pxz )
	!pxz? ( app-arch/xz-utils )
	>=sys-libs/StormByte-functions-bash-1.3.0
"
DEPEND="${RDEPEND}"

pkg_pretend() {
	if use zram; then
		# CONFIG_CHECK is a space-separated list only — no shell operators.
		CONFIG_CHECK="ZRAM"
		ERROR_ZRAM="CONFIG_ZRAM is required for USE=zram (STORAGE_SYSTEM=zram)"
		check_extra_config

		# Need either native ext2 or ext4's "use for ext2" support.
		if ! linux_chkconfig_present EXT2_FS && ! linux_chkconfig_present EXT4_USE_FOR_EXT2; then
			eerror "CONFIG_EXT2_FS or CONFIG_EXT4_USE_FOR_EXT2 is required to format zram as ext2"
			die "Kernel config does not support formatting zram (USE=zram)"
		fi
	fi
}

src_install() {
	dobin StormByte-StageManager

	doconfd StormByte-StageManager.conf

	insinto /usr/share/bash-completion/completions
	newins StormByte-StageManager.bash-completion StormByte-StageManager

	doman StormByte-StageManager.1

	dodoc README.md CHANGELOG.md
}

pkg_postinst() {
	elog "Edit /etc/conf.d/StormByte-StageManager.conf before first use."
	elog "TARBALL_FOLDER must exist and be writable by the invoking user."
	elog "use/rebase re-exec sudo -E (mounts, chroot, zram). Other commands do not."
	elog "Requires StormByte-functions-bash >= 1.3.0."
	elog "Example: StormByte-StageManager help"
	elog "         StormByte-StageManager config"
}
