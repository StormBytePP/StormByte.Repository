# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
DISTUTILS_USE_PEP517=poetry
inherit distutils-r1 virtualx

DESCRIPTION="CoolerControl is a program to monitor and control your cooling devices"
HOMEPAGE="https://gitlab.com/coolercontrol/coolercontrol"
SRC_URI="https://gitlab.com/coolercontrol/coolercontrol/-/archive/${PV}/${P}.tar.bz2"
LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=app-misc/liquidctl-1.11.1[${PYTHON_USEDEP}]
	dev-python/APScheduler[${PYTHON_USEDEP}]
	dev-python/jeepney[${PYTHON_USEDEP}]
	>=dev-python/matplotlib-3.6.2[${PYTHON_USEDEP}]
	>=dev-python/numpy-1.23.5[${PYTHON_USEDEP}]
	dev-python/psutil[${PYTHON_USEDEP}]
	dev-python/pyamdgpuinfo[${PYTHON_USEDEP}]
	>=dev-python/pyside6-6.4.1[${PYTHON_USEDEP},gui,svg,widgets]
	>=dev-python/setproctitle-1.3.2[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

src_test() {
	virtx distutils-r1_src_test || die
}
