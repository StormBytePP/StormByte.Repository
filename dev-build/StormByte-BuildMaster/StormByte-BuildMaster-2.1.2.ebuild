EAPI=8

DESCRIPTION="Declarative CMake build orchestration for CMake and Meson projects"
HOMEPAGE="https://suite.StormByte.org/StormByte-BuildMaster"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormByte-Suite/${PN}.git"
	EGIT_SUBMODULES=()
else
	SRC_URI="https://github.com/StormByte-Suite/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~x86"
fi

LICENSE="MIT"
SLOT="0"

RDEPEND="
	>=dev-build/cmake-3.21
	dev-build/meson
	dev-build/ninja
	dev-vcs/git
	virtual/pkgconfig
"

src_compile() { :; }

src_install() {
	local version
	version=$(< VERSION)
	[[ -n ${version} ]] || die "Missing BuildMaster version"

	sed "s/@VERSION@/${version}/g" \
		"${FILESDIR}/${PN}ConfigVersion.cmake.in" \
		> "${T}/${PN}ConfigVersion.cmake" || die

	insinto "/usr/share/cmake/${PN}"
	doins "${FILESDIR}/${PN}Config.cmake" "${T}/${PN}ConfigVersion.cmake"

	insinto "/usr/share/cmake/${PN}/modules"
	doins CMakeLists.txt VERSION *.cmake
	doins -r component env report toolchain tools

	dodoc README.md CHANGELOG.md MIGRATE.md public_functions.md
}
