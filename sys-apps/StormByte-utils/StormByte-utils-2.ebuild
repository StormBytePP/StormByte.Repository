# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="StormByte's utils"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="+videoconvert"

RDEPEND="
	sys-apps/findutils
	sys-process/parallel
	media-video/ffmpeg
	media-video/hdr10plus_tool
	videoconvert? ( media-video/StormByte-VideoConvert )
"
DEPEND="${RDEPEND}
"

src_unpack() {
	#Since there are no downloaded files, this is dummy to prevent folder not exist error
	mkdir "${S}"
}

src_install() {
	for i in ${FILESDIR}/*; do
		dobin "$i"
	done
}

