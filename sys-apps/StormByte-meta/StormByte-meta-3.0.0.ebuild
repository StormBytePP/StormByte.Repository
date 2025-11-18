# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's utils"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="portageconfig stagemanager utils videoconvert"

RDEPEND="
	sys-libs/StormByte-functions
	portageconfig? ( app-portage/StormByte-portageconfig )
	stagemanager? ( sys-apps/StormByte-StageManager )
	utils? ( sys-apps/StormByte-utils )
	videoconvert? ( media-video/StormByte-VideoConvert )
"
DEPEND="${RDEPEND}"


