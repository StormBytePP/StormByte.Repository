# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info

DESCRIPTION="SES disk locator and inventory tools for EMC Viper enclosures"
HOMEPAGE="https://dev.StormByte.org"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	sys-apps/sg3_utils
	sys-apps/smartmontools
	sys-apps/util-linux
	sys-fs/lsscsi
	sys-fs/zfs
	>=sys-libs/StormByte-functions-4.0.0[datacenter]
"

S="${WORKDIR}"

CONFIG_CHECK="ENCLOSURE_SERVICES SCSI_ENCLOSURE"

pkg_setup() {
	linux-info_pkg_setup
}

src_install() {
	dobin "${FILESDIR}/datacenter_info"
	dobin "${FILESDIR}/datacenter_led"
}
