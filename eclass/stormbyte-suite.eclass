# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: stormbyte-suite.eclass
# @MAINTAINER:
# David C. Manuelda <stormbyte@gmail.com>
# @SUPPORTED_EAPIS: 8
# @BLURB: Shared packaging for the StormByte C++ suite
# @DESCRIPTION:
# Live and release ebuilds of one module share this eclass:
# slotting, explicit rebuilds, and the LTO flag.
#
# Release slot is "<major>.<minor>/<PV>" (2.0.1 -> 2.0/2.0.1, multimedia
# 1.0.0 -> 1.0/1.0.0). The subslot is the full version because upstream
# sets SOVERSION to the project version, so a patch release changes the
# SONAME. Live ebuilds use slot 9999.
#
# stormbyte-suite_dep expands to:
#   release: <cat/pkg-9999:=     any release slot, rebuild on slot/subslot change
#   live:    cat/pkg:9999=       never a release build
# So a Buffer 2.1.0 (slot 2.1) forces every release consumer to rebuild,
# and a 9999 install is not a candidate for those atoms. A release
# ebuild may pass a minimum version to reject an incompatible ABI.
#
# LTO is the USE flag, not CMake IPO. cmake.eclass pins
# CMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF. The suite's optimizations.cmake
# turns it back on when ENABLE_LTO is ON, and that fights the flag this
# eclass injects. ENABLE_LTO stays OFF. With USE=lto the eclass appends
# -flto=thin (Clang) or -flto after stripping any -flto the user injected.
#
# USE=pgo passes -DENABLE_PGO=ON. Training runs inside cmake configure:
# the project builds an instrumented tree, runs ctest, then configures
# this directory against the profile. An ebuild that needs services for
# that ctest defines stormbyte-suite_pgo_start and stormbyte-suite_pgo_stop.
# They are called around configure, and stop also runs if configure dies.
#
# Third-party code is never built from the bundled trees. Consumers pass
# WITH_*=SYSTEM, or WITH_*=OFF behind a USE flag when upstream allows OFF.
#
# An ebuild may define stormbyte-suite_cmake_args, which fills
# STORMBYTE_CMAKEARGS.
#
# Do not set SLOT, KEYWORDS or SRC_URI in the ebuild. Append to BDEPEND
# with BDEPEND+= ; assigning BDEPEND= replaces this eclass's dependencies.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_STORMBYTE_SUITE_ECLASS} ]]; then
_STORMBYTE_SUITE_ECLASS=1

inherit cmake flag-o-matic toolchain-funcs

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormByte-Suite/${PN}.git"
	# System libraries only. Fetching the bundled submodules would pull
	# ffmpeg, crypto++, postgres, ... which these ebuilds must not build.
	EGIT_SUBMODULES=()
	SLOT="9999"
else
	SRC_URI="https://github.com/StormByte-Suite/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~x86"
	SLOT="$(ver_cut 1-2)/${PV}"
fi

# Applications without a training workflow can opt out before inheriting.
IUSE="lto"
if [[ ${STORMBYTE_SUITE_NO_PGO} != yes ]]; then
	IUSE+=" pgo"
fi

BDEPEND="
	>=dev-build/cmake-3.28
	>=dev-build/StormByte-BuildMaster-2.1.5
	virtual/pkgconfig
"

# @FUNCTION: stormbyte-suite_dep
# @USAGE: <category/package> [minimum-version] [post]
# @DESCRIPTION:
# Atom that tracks this suite's slot and rebuilds the consumer.
# See the eclass description for the release vs 9999 split. A minimum
# version adds >=cat/pkg-<version> to release atoms; live atoms ignore
# it. "post" omits the rebuild operator, which is not permitted in PDEPEND.
stormbyte-suite_dep() {
	[[ ${#} -ge 1 && ${#} -le 3 ]] \
		|| die "${FUNCNAME}: expected category/package, optional minimum version and optional post"

	local pkg=${1} min="" post=""
	shift
	if [[ ${#} -gt 0 && ${1} != post ]]; then
		min=${1}
		shift
	fi
	if [[ ${#} -gt 0 ]]; then
		[[ ${#} -eq 1 && ${1} == post ]] \
			|| die "${FUNCNAME}: unexpected arguments: ${*}"
		post=yes
	fi

	local rebuild="="
	[[ ${post} == yes ]] && rebuild=""
	if [[ ${PV} == 9999 ]]; then
		echo "${pkg}:9999${rebuild}"
		return
	fi

	local slot=":="
	[[ ${post} == yes ]] && slot=""
	if [[ -n ${min} ]]; then
		echo ">=${pkg}-${min}${slot} <${pkg}-9999"
	else
		echo "<${pkg}-9999${slot}"
	fi
}

# @FUNCTION: _stormbyte-suite_apply_lto
# @INTERNAL
# @DESCRIPTION:
# USE=lto is authoritative: drop any -flto the user injected and add the
# one flag that matches the compiler. CMake IPO stays off.
_stormbyte-suite_apply_lto() {
	filter-lto
	filter-flags '-fprofile-*'
	filter-ldflags '-fprofile-*'

	if use lto; then
		local flag
		if tc-is-clang; then
			flag="-flto=thin"
		else
			flag="-flto"
		fi
		append-flags "${flag}"
		append-ldflags "${flag}"
	fi
}

# @FUNCTION: _stormbyte-suite_configure
# @INTERNAL
# @USAGE: <ON|OFF>
# @DESCRIPTION:
# Configure once. The argument is ENABLE_PGO. Tests stay off here; the
# instrumented tree turns them on itself.
_stormbyte-suite_configure() {
	if declare -F stormbyte-suite_cmake_args >/dev/null; then
		stormbyte-suite_cmake_args
	fi
	if ! declare -p STORMBYTE_CMAKEARGS >/dev/null 2>&1; then
		local -a STORMBYTE_CMAKEARGS=()
	fi

	local mycmakeargs=(
		-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
		-DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=OFF
		-DENABLE_LTO=OFF
		-DENABLE_PGO=${1}
		-DENABLE_TEST=OFF
		"${STORMBYTE_CMAKEARGS[@]}"
	)
	cmake_src_configure
}

# @FUNCTION: stormbyte-suite_src_prepare
# @DESCRIPTION:
# Prepare the tree and require the system BuildMaster package. Never use
# the bundled fallback, including when configuring PGO's nested build.
stormbyte-suite_src_prepare() {
	cmake_src_prepare

	if [[ -f cmake/load_buildmaster.cmake ]]; then
		sed -i -E \
			-e 's/(find_package\(StormByte-BuildMaster [0-9.]+ CONFIG) QUIET\)/\1 REQUIRED)/' \
			cmake/load_buildmaster.cmake || die
		grep -qE 'find_package\(StormByte-BuildMaster [0-9.]+ CONFIG REQUIRED\)' \
			cmake/load_buildmaster.cmake \
			|| die "cmake/load_buildmaster.cmake no longer matches the system BuildMaster lookup"
	fi
}

# @FUNCTION: stormbyte-suite_src_configure
# @DESCRIPTION:
# Apply USE=lto, optionally start PGO services, then configure.
# USE=pgo trains during this configure.
stormbyte-suite_src_configure() {
	_stormbyte-suite_apply_lto

	local pgo=OFF
	if [[ ${STORMBYTE_SUITE_NO_PGO} != yes ]] && use pgo; then
		pgo=ON
		if declare -F stormbyte-suite_pgo_start >/dev/null; then
			# Armed first, so a failure while starting still stops what came up.
			trap 'stormbyte-suite_pgo_stop' EXIT
			stormbyte-suite_pgo_start
		fi
	fi

	_stormbyte-suite_configure "${pgo}"

	if [[ ${pgo} == ON ]] && declare -F stormbyte-suite_pgo_stop >/dev/null; then
		trap - EXIT
		stormbyte-suite_pgo_stop
	fi
}

fi

EXPORT_FUNCTIONS src_prepare src_configure
