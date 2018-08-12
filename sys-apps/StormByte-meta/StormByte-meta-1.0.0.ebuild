# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's utils"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="utils stagemanager portageconfig makekernel"

RDEPEND="
	utils? ( sys-apps/StormByte-utils )
	stagemanager? ( sys-apps/StormByte-stagemanager )
	makekernel? ( sys-kernel/StormByte-makekernel )
	portageconfig? ( app-portage/StormByte-portageconfig )
"
DEPEND="${RDEPEND}
"


