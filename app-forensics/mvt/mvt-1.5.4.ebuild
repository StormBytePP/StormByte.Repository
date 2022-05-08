# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{8..10} )

if [[ ${PV} == "9999" ]] ; then
        inherit git-r3 distutils-r1
        EGIT_REPO_URI="https://github.com/mvt-project/${PN}.git"
else
        inherit distutils-r1
        SRC_URI="https://github.com/mvt-project/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
        KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="Forensic traces to identify a potential compromise of Android and iOS devices"
HOMEPAGE="https://github.com/mvt-project/mvt"

LICENSE="MIT"
SLOT="0"

RDEPEND="
        dev-python/adb-shell[${PYTHON_USEDEP}]
        dev-python/biplist[${PYTHON_USEDEP}]
        dev-python/click[${PYTHON_USEDEP}]
        dev-python/iOSbackup[${PYTHON_USEDEP}]
        dev-python/libusb1[${PYTHON_USEDEP}]
        dev-python/requests[${PYTHON_USEDEP}]
        dev-python/rich[${PYTHON_USEDEP}]
        dev-python/simplejson[${PYTHON_USEDEP}]
        dev-python/tld[${PYTHON_USEDEP}]
        dev-python/tqdm[${PYTHON_USEDEP}]
"
BDEPEND="
        dev-python/setuptools[${PYTHON_USEDEP}]
"

