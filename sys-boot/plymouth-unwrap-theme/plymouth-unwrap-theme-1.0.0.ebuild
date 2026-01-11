# Copyright 2020 David C. Manuelda a.k.a. StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Plymouth unwrap theme"

HOMEPAGE="https://github.com/adi1090x/plymouth-themes?tab=readme-ov-file"

SRC_URI="https://drive.google.com/uc?export=download&id=1uolhPkKSRgDKZ4Gtoc5qx2y9Y0hXs9pQ -> ${P}.tbz2"

LICENSE=""

SLOT="0"

KEYWORDS="x86 amd64"

RDEPEND="sys-boot/plymouth"

S="${WORKDIR}"

src_install() {
	insinto "/usr/share/plymouth/themes/"
	doins -r "${PN}"
}
