# Copyright 1999-2026 StormByte
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Unified CLI for GitHub Actions caches, CI runs, git ops, submodules, dumps and releases"
HOMEPAGE="https://github.com/StormBytePP/StormByte-GitHub"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormBytePP/StormByte-GitHub.git"
	KEYWORDS=""
else
	SRC_URI="https://github.com/StormBytePP/StormByte-GitHub/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"

RDEPEND="
	app-misc/jq
	dev-util/github-cli
	>=sys-libs/StormByte-functions-bash-1.1.0
	>=sys-libs/StormByte-functions-git-1.1.0
"
DEPEND="${RDEPEND}"

src_install() {
	dobin StormByte-GitHub

	insinto /usr/share/bash-completion/completions
	newins StormByte-GitHub.bash-completion StormByte-GitHub

	doman StormByte-GitHub.1

	dodoc README.md CHANGELOG.md
}

pkg_postinst() {
	elog "On first run the tool writes ~/.StormByte-GitHub.conf (OWNER, ROOT, OUT, optional FORK_ROOT)."
	elog "Requires an authenticated GitHub CLI (gh auth login)."
	elog "Example: StormByte-GitHub help"
}