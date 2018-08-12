# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's utils"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="stagemanager portageconfig makekernel"

RDEPEND="
	sys-apps/StormByte-functions
	sys-apps/findutils
	stagemanager? ( sys-apps/StormByte-stagemanager )
	makekernel? ( sys-kernel/StormByte-makekernel )
	portageconfig? ( app-portage/StormByte-portageconfig )
"
DEPEND="${RDEPEND}
"

src_unpack() {
	#Since there are no downloaded files, this is dummy to prevent folder not exist error
	mkdir "${S}"
}

src_install() {
	dobin "${FILESDIR}/stormbyte-findcontent"
}

