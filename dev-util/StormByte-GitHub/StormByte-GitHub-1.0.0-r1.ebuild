# Copyright 1999-2026 StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Unified CLI for StormBytePP GitHub Actions caches, CI runs, git ops and source dumps"
HOMEPAGE="https://github.com/StormBytePP"
SRC_URI=""

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# No upstream tarball: install from FILESDIR only
S="${WORKDIR}"

RDEPEND="
	app-misc/jq
	dev-util/github-cli
	sys-libs/StormByte-functions-bash
	sys-libs/StormByte-functions-git
"
DEPEND="${RDEPEND}"

src_unpack() {
	:
}

src_install() {
	dobin "${FILESDIR}/StormByte-GitHub"

	insinto /usr/share/bash-completion/completions
	newins "${FILESDIR}/StormByte-GitHub.bash-completion" StormByte-GitHub

	# Man page (section 1)
	doman "${FILESDIR}/StormByte-GitHub.1"
}