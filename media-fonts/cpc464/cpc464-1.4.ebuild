# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit font

DESCRIPTION="Standard font for Android 4.0 (Ice Cream Sandwich) and later"
HOMEPAGE="https://github.com/damianvila/font-cpc464"
SRC_URI="https://github.com/googlefonts/${PN}/releases/download/v${PV}/roboto-unhinted.zip -> ${P}.zip"
SRC_URI="https://github.com/damianvila/font-cpc464/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/font-${P}/fonts"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64 ~arm arm64 ~loong ~ppc64 ~riscv x86 ~amd64-linux ~x86-linux ~x64-macos"

BDEPEND="
    app-alternatives/tar
    app-alternatives/gzip
"

FONT_CONF=( "${FILESDIR}"/90-amstrad-cpc464-regular.conf )
FONT_SUFFIX="ttf"
