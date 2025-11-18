# Copyright 2020 David C. Manuelda a.k.a. StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Plymouth dotLock theme"

HOMEPAGE="https://www.gnome-look.org/p/1635081"

SRC_URI="https://drive.google.com/uc?export=download&id=1CmFuFC6SoJiGL900VTE1FVmpGe12OCcK -> ${P}.tar.bz2"

LICENSE=""

SLOT="0"

KEYWORDS="x86 amd64"

RDEPEND="sys-boot/plymouth"

S="${WORKDIR}"

src_install() {
	insinto "/usr/share/plymouth/themes/"
	doins -r "${PN}"
}
