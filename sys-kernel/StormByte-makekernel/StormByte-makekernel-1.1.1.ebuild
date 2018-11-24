# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's Genkernel Helper Layout"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI="https://github.com/StormBytePP/StormByte-makekernel/archive/${PV}.tar.gz"

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	sys-libs/StormByte-functions
	|| ( sys-kernel/genkernel sys-kernel/genkernel-next )
"
DEPEND="${RDEPEND}
"

src_install() {
	dobin "${S}/stormbyte-makekernel"
	doconfd "${S}/stormbyte-makekernel.conf"
}
