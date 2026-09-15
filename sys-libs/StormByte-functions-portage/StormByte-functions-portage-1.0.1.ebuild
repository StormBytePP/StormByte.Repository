# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's portage functions"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	sys-apps/portage
	sys-libs/StormByte-functions-bash
"
DEPEND="${RDEPEND}"

S="${WORKDIR}"

src_install() {
	insinto "/lib/StormByte"
	doins "${FILESDIR}/portage.sh"
}
