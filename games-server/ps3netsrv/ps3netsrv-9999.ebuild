# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit flag-o-matic git-r3

EGIT_REPO_URI="https://github.com/aldostools/webMAN-MOD.git"
EGIT_BRANCH="origin/HEAD"
EGIT_COMMIT="HEAD"
EGIT_CHECKOUT_DIR="${S}"

SRC_URI=""


DESCRIPTION="XXXXX"
HOMEPAGE="XXXXX"


LICENSE="LGPL-2.1"
SLOT="${PV}"
IUSE=""


DEPEND=""
RDEPEND=""

src_unpack() {
	git-r3_src_unpack
	cd "${S}"
}

src_compile() {
	cd "_Projects_/ps3netsrv/"
	emake -f Makefile.linux
}

src_install() {
	cd "_Projects_/ps3netsrv/"
	dobin ps3netsrv
	doinitd ${FILESDIR}/init.d/ps3netsrv
	doconfd ${FILESDIR}/conf.d/ps3netsrv
}

