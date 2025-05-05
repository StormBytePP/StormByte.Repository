EAPI=8

DESCRIPTION="Unofficial WhatsApp client using Electron"
HOMEPAGE="https://github.com/dagmoller/whatsapp-electron"
SRC_URI="https://github.com/dagmoller/whatsapp-electron/releases/download/v${PV}/whatsapp-electron-${PV}.tar.xz -> ${P}.tar.xz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND="net-libs/nodejs[npm]"
RDEPEND="${DEPEND}"

S="${WORKDIR}/whatsapp-electron-${PV}"

src_compile() {
    einfo "S is: ${S}"
    npm install
}

src_install() {
    mv "${S}/whatsapp-electron" "${S}/WhatsApp"
    dobin "${S}/WhatsApp"
}
