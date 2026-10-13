# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: stormbyte-suite.eclass
# @MAINTAINER:
# David C. Manuelda <stormbyte@gmail.com>
# @SUPPORTED_EAPIS: 8
# @BLURB: Shared packaging for the StormByte C++ suite
# @DESCRIPTION:
# Live and release ebuilds of one module share this eclass:
# slotting, explicit rebuilds, LTO and the two-pass PGO build.
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
# and a 9999 install is not a candidate for those atoms.
#
# LTO is the USE flag, not CMake IPO. cmake.eclass pins
# CMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF and the suite's
# optimizations.cmake turns the Release variant back on; this eclass
# forces both off and, with USE=lto, appends -flto=thin (Clang) or -flto.
#
# Third-party code is never built from the bundled trees. Consumers pass
# WITH_*=SYSTEM, or WITH_*=OFF behind a USE flag when upstream allows OFF.
#
# An ebuild may set STORMBYTE_NO_PGO=1 before inherit when the test suite
# cannot train a profile (Database needs servers, users and credentials).
# It may also define stormbyte-suite_cmake_args, which fills STORMBYTE_CMAKEARGS.
#
# Do not set SLOT, KEYWORDS, SRC_URI or BDEPEND in the ebuild.

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

: "${STORMBYTE_NO_PGO:=0}"
if [[ ${STORMBYTE_NO_PGO} == 1 ]]; then
	IUSE="lto"
else
	IUSE="lto pgo"
fi

BDEPEND="
	>=dev-build/cmake-3.28
	>=dev-build/StormByte-BuildMaster-2.0.3
	virtual/pkgconfig
"

# @FUNCTION: stormbyte-suite_dep
# @USAGE: <category/package>
# @DESCRIPTION:
# Atom that tracks this suite's slot and rebuilds the consumer.
# See the eclass description for the release vs 9999 split.
stormbyte-suite_dep() {
	[[ ${#} -eq 1 ]] || die "${FUNCNAME}: expected one category/package argument"

	local pkg=${1}
	if [[ ${PV} == 9999 ]]; then
		echo "${pkg}:9999="
	else
		echo "<${pkg}-9999:="
	fi
}

# @FUNCTION: _stormbyte-suite_pgo
# @INTERNAL
# @DESCRIPTION:
# True when this package trains a profile.
_stormbyte-suite_pgo() {
	in_iuse pgo && use pgo
}

# @FUNCTION: _stormbyte-suite_apply_lto
# @INTERNAL
# @DESCRIPTION:
# USE=lto is authoritative: drop any -flto the user injected and add the
# one flag that matches the compiler.
_stormbyte-suite_apply_lto() {
	filter-lto

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
# Configure once. The argument is ENABLE_TEST.
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
		-DENABLE_TEST=${1}
		"${STORMBYTE_CMAKEARGS[@]}"
	)
	cmake_src_configure
}

# @FUNCTION: _stormbyte-suite_profdata
# @INTERNAL
# @DESCRIPTION:
# llvm-profdata matching the active Clang major, else the unversioned tool.
_stormbyte-suite_profdata() {
	local major profdata
	major=$(clang-major-version)
	profdata="llvm-profdata-${major}"
	if ! type -P "${profdata}" >/dev/null 2>&1; then
		profdata="llvm-profdata"
	fi
	type -P "${profdata}" >/dev/null 2>&1 || die "llvm-profdata not found"
	echo "${profdata}"
}

# @FUNCTION: stormbyte-suite_src_prepare
# @DESCRIPTION:
# Prepare the tree, stub a missing BuildMaster checkout and disable CMake IPO
# so LTO comes only from USE=lto.
stormbyte-suite_src_prepare() {
	cmake_src_prepare

	# Release tarballs omit the BuildMaster submodule. The system package
	# satisfies find_package; the empty files only cover the fallback
	# add_subdirectory() when that package is missing.
	if [[ -d buildmaster ]]; then
		local stub
		for stub in CMakeLists.txt helpers.cmake; do
			if [[ ! -e buildmaster/${stub} ]]; then
				touch "buildmaster/${stub}" || die
			fi
		done
	fi

	if [[ -f cmake/optimizations.cmake ]]; then
		sed -i -E \
			's/set\((CMAKE_INTERPROCEDURAL_OPTIMIZATION(_RELEASE)?)[[:space:]]+TRUE\)/set(\1 FALSE)/' \
			cmake/optimizations.cmake || die
	fi
}

# @FUNCTION: stormbyte-suite_src_configure
# @DESCRIPTION:
# Normal configure. With USE=pgo both passes are done from src_compile,
# where the profile flags are applied.
stormbyte-suite_src_configure() {
	if _stormbyte-suite_pgo; then
		return
	fi

	_stormbyte-suite_apply_lto
	_stormbyte-suite_configure OFF
}

# @FUNCTION: stormbyte-suite_src_compile
# @DESCRIPTION:
# Build. USE=pgo instruments, runs ctest as the training workload, then
# rebuilds with the profile. LTO is applied only on that second pass.
stormbyte-suite_src_compile() {
	if ! _stormbyte-suite_pgo; then
		cmake_src_compile
		return
	fi

	local pgo_dir="${T}/pgo"
	mkdir -p "${pgo_dir}" || die

	einfo "PGO: instrumentation pass"
	filter-flags '-fprofile-*'
	filter-ldflags '-fprofile-*'
	filter-lto

	local -a gen=()
	if tc-is-clang; then
		gen+=( -fprofile-instr-generate )
	else
		gen+=(
			"-fprofile-generate=${pgo_dir}"
			"-fprofile-dir=${pgo_dir}"
			-fprofile-update=atomic
		)
		local partial
		partial=$(test-flags-CC -fprofile-partial-training)
		[[ -n ${partial} ]] && gen+=( "${partial}" )
	fi
	append-flags "${gen[@]}"
	append-ldflags "${gen[@]}"

	_stormbyte-suite_configure ON
	cmake_src_compile

	if tc-is-clang; then
		export LLVM_PROFILE_FILE="${pgo_dir}/default-%p-%m.profraw"
	fi

	ctest --test-dir "${BUILD_DIR}/test" --output-on-failure \
		|| die "PGO training (ctest) failed"

	if tc-is-clang; then
		local -a profraw=()
		local raw
		while IFS= read -r -d '' raw; do
			profraw+=( "${raw}" )
		done < <(find "${pgo_dir}" "${WORKDIR}" -name '*.profraw' -print0)
		[[ ${#profraw[@]} -gt 0 ]] || die "PGO produced no .profraw profiles"
		einfo "PGO: merging ${#profraw[@]} Clang profile(s)"
		"$(_stormbyte-suite_profdata)" merge -output="${pgo_dir}/default.profdata" \
			"${profraw[@]}" || die "llvm-profdata merge failed"
	else
		local gcda
		gcda=$(find "${pgo_dir}" "${BUILD_DIR}" -name '*.gcda' -print -quit)
		[[ -n ${gcda} ]] || die "PGO produced no .gcda profiles"
	fi

	einfo "PGO: optimized pass"
	rm -rf "${BUILD_DIR}" || die
	filter-flags '-fprofile-*'
	filter-ldflags '-fprofile-*'
	filter-lto

	local -a use_flags=()
	if tc-is-clang; then
		use_flags+=( "-fprofile-instr-use=${pgo_dir}/default.profdata" )
	else
		use_flags+=(
			"-fprofile-use=${pgo_dir}"
			"-fprofile-dir=${pgo_dir}"
			-fprofile-correction
		)
		local partial
		partial=$(test-flags-CC -fprofile-partial-training)
		[[ -n ${partial} ]] && use_flags+=( "${partial}" )
	fi
	append-flags "${use_flags[@]}"
	append-ldflags "${use_flags[@]}"
	_stormbyte-suite_apply_lto

	_stormbyte-suite_configure OFF
	cmake_src_compile
}

fi

EXPORT_FUNCTIONS src_prepare src_configure src_compile
