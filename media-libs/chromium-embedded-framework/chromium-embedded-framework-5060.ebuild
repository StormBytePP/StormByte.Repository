# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

CEF_DIR="cef_binary_${PV}_linux_x86_64"
CEF_REVISION="_v3"

SRC_URI="https://cdn-fastly.obsproject.com/downloads/${CEF_DIR}${CEF_REVISION}.tar.xz"

DESCRIPTION="Chromium Embeddeed Framework"
HOMEPAGE="https://bitbucket.org/chromiumembedded/cef"

LICENSE="GPL-2+"
SLOT="0"
IUSE=""

REQUIRED_USE=""

BDEPEND=""

DEPEND=""
RDEPEND="${DEPEND}"

KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"

QA_PREBUILT=""

S="${WORKDIR}/${CEF_DIR}"

PATCHES="${FILESDIR}/remove-rpath.patch"

src_prepare() {
	if tc-is-clang; then
		eapply "${FILESDIR}/clang-update-deprecated-builtins.patch"
	fi

	cmake_src_prepare
}

src_configure() {
	cmake_src_configure
}

src_install() {
	dolib.so "${BUILD_DIR}/libcef_dll_wrapper/libcef_dll_wrapper.so"
}
