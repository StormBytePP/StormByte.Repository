# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7
MY_P="pencil-${PV}"

inherit fdo-mime

DESCRIPTION="A simple GUI prototyping tool to create mockups"
HOMEPAGE="http://pencil.evolus.vn/"
SRC_URI="
x86? ( http://pencil.evolus.vn/dl/V${PV}/Pencil_${PV}_i386.deb )
amd64? ( http://pencil.evolus.vn/dl/V${PV}/Pencil_${PV}_amd64.deb )
"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND="app-arch/alien"
RDEPEND="|| ( www-client/firefox www-client/firefox-bin )"

S=${WORKDIR}/${MY_P}

src_unpack() {
	# convert first to tgz package
	alien --to-tgz "${DISTDIR}/${A}" > /dev/null 2>&1 || die "Can't convert deb package via alien!"
	A="pencil-${PV}.tgz"
	mkdir -p ${S}
	cd ${S}
	unpack "${WORKDIR}/${A}"
	rm "${WORKDIR}/${A}"
}

src_install() {
	insinto /
	rm -r usr/share/doc
	doins -r usr
	doins -r opt
	chmod 0755 "${D}/opt/Pencil/pencil"
	echo "Chmodded ${D}/opt/Pencil/pencil"
}

pkg_postinst() {
	fdo-mime_desktop_database_update
}

pkg_postrm() {
	fdo-mime_desktop_database_update
}
