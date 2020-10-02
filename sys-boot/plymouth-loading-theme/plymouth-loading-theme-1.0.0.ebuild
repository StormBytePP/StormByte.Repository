# Copyright 2020 David C. Manuelda a.k.a. StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Plymouth loading theme"

HOMEPAGE="https://store.kde.org/p/1184062/"

SRC_URI="https://drive.google.com/uc?export=download&id=1NCHtIVH9jkx1ojy0e0cmOzFYG2rDCWKe -> ${P}.tbz2"

LICENSE=""

SLOT="0"

KEYWORDS="x86 amd64"

RDEPEND="sys-boot/plymouth"

S="${WORKDIR}"

src_install() {
	insinto "/usr/share/plymouth/themes/"
	doins -r "${PN}"
}
