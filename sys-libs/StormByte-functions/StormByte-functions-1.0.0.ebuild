# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="StormByte's functions"
HOMEPAGE="https://blog.stormbyte.org"
SRC_URI=""

SLOT="0"
KEYWORDS="amd64 x86"
IUSE="bash datacenter git portage"

RDEPEND="app-shells/bash"
DEPEND="${RDEPEND}"
PDEPEND="
	bash? ( app-shells/bash )
	datacenter? ( sys-libs/StormByte-functions-datacenter )
	git? ( sys-libs/StormByte-functions-git )
	portage? ( sys-libs/StormByte-functions-portage )
"

