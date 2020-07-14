# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=7

inherit eutils unpacker

DESCRIPTION="Additional proprietary codecs for opera"
HOMEPAGE="http://ffmpeg.org/"
SRC_URI="https://ftp5.gwdg.de/pub/linux/archlinux/community/os/x86_64/opera-ffmpeg-codecs-83.0.4103.116-1-x86_64.pkg.tar.zst"

LICENSE="LGPL2.1"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND=""
RDEPEND="www-client/opera"

RESTRICT="mirror strip"

S="${WORKDIR}"

src_install() {
	cd "${S}"
	cp -R * "${D}"
}

