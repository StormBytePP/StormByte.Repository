# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's Git functions"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="dev-vcs/git"
DEPEND="${RDEPEND}"

S="${WORKDIR}"

src_install() {
	insinto "/lib/StormByte"
	doins "${FILESDIR}/git.sh"
}
