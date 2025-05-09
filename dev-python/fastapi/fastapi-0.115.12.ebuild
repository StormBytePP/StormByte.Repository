# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=pdm-backend
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1

DESCRIPTION="High performance, easy to learn, fast to code, ready for production"
HOMEPAGE="https://fastapi.tiangolo.com/ https://github.com/tiangolo/fastapi"
SRC_URI="https://github.com/tiangolo/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT=0
KEYWORDS="~amd64"

RESTRICT="test"

BDEPEND=">=dev-python/hatchling-1.13.0[${PYTHON_USEDEP}]"
RDEPEND="
	>=dev-python/anyio-3.7.1[${PYTHON_USEDEP}]
	>=dev-python/pydantic-1.7.4[${PYTHON_USEDEP}]
	>=dev-python/starlette-0.40.0[${PYTHON_USEDEP}]
	>=dev-python/typing-extensions-4.8.0[${PYTHON_USEDEP}]
"
