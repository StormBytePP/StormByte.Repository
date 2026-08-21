# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's GitHub CLI functions"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	dev-util/github-cli
	>=sys-libs/StormByte-functions-bash-1.3.0
	>=sys-libs/StormByte-functions-git-1.3.0
"
DEPEND="${RDEPEND}"

S="${WORKDIR}"

src_install() {
	insinto "/lib/StormByte"
	doins "${FILESDIR}/gh.sh"
}
