# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit git-r3

EGIT_REPO_URI="https://github.com/dirkvdb/ps3netsrv--.git"
EGIT_BRANCH="origin/HEAD"
EGIT_COMMIT="HEAD"
EGIT_CHECKOUT_DIR="${S}"

SRC_URI=""


DESCRIPTION="XXXXX"
HOMEPAGE="XXXXX"


LICENSE="LGPL-2.1"
SLOT="${PV}"
IUSE=""


DEPEND="
	sys-libs/libcxx
	sys-devel/clang
"
RDEPEND=""

src_unpack() {
	git-r3_src_unpack
}

src_compile() {
	emake CXX=g++
}

src_install() {
	dobin ps3netsrv++
}

