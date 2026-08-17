# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic toolchain-funcs

DESCRIPTION="StormByte Crypto module"
HOMEPAGE="https://dev.stormbyte.org/StormByte-Crypto"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"
else
	SRC_URI="https://github.com/StormBytePP/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86 ~arm ~arm64"
fi

LICENSE="LGPL-3"
SLOT="0"
IUSE="pgo lto"

DEPEND="
	app-arch/bzip2
	dev-libs/crypto++
	dev-libs/StormByte
	dev-libs/StormByte-Buffer
	dev-libs/StormByte-Logger
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

# Helper to get the correct LTO flags
_get_lto_flags() {
	if use lto; then
		if tc-is-clang; then
			echo "-flto=thin"
		else
			echo "-flto"
		fi
	fi
}

src_prepare() {
	cmake_src_prepare

	# Tarball lacks for submodules
	local empty_submodules=(
		thirdparty/buildmaster/CMakeLists.txt
		thirdparty/buildmaster/helpers.cmake
	)

	local file
	for file in "${empty_submodules[@]}"; do
		touch "${file}" || die
	done
}

src_configure() {
	# Only used when USE=-pgo
	local mycmakeargs=(
		-DWITH_BZIP2=SYSTEM
		-DWITH_CRYPTOPP=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DENABLE_TEST=OFF
	)

	# Apply LTO when not doing PGO
	if ! use pgo; then
		local lto_flags=$(_get_lto_flags)
		if [[ -n ${lto_flags} ]]; then
			append-flags ${lto_flags}
			append-ldflags ${lto_flags}
		fi
	fi

	cmake_src_configure
}

src_compile() {
	if ! use pgo; then
		cmake_src_compile
		return
	fi

	# === PGO first pass: instrumentation + training ===
	einfo "PGO: first pass (instrumentation + running tests)"

	local pgo_dir="${T}/pgo"
	mkdir -p "${pgo_dir}" || die

	filter-flags -fprofile-* -flto*

	local pgo_generate_flags
	if tc-is-clang; then
		pgo_generate_flags="-fprofile-instr-generate"
	else
		pgo_generate_flags="-fprofile-generate=${pgo_dir} -fprofile-dir=${pgo_dir} -fprofile-update=atomic"
		pgo_generate_flags+=" $(test-flags-CC -fprofile-partial-training)"
	fi

	local mycmakeargs=(
		-DWITH_BZIP2=SYSTEM
		-DWITH_CRYPTOPP=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DENABLE_TEST=ON
		-DCMAKE_C_FLAGS="${CFLAGS} ${pgo_generate_flags}"
		-DCMAKE_CXX_FLAGS="${CXXFLAGS} ${pgo_generate_flags}"
		-DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} ${pgo_generate_flags}"
		-DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} ${pgo_generate_flags}"
	)

	cmake_src_configure
	cmake_src_compile

	# Force profile output location (important for Clang)
	export LLVM_PROFILE_FILE="${pgo_dir}/default-%p-%m.profraw"

	ctest --test-dir "${BUILD_DIR}/test" --output-on-failure \
		|| die "PGO training (ctest) failed"

	# Collect profile data
	local profraw_files=( $(find "${pgo_dir}" -name '*.profraw' 2>/dev/null) )

	if [[ ${#profraw_files[@]} -eq 0 ]]; then
		profraw_files=( $(find "${WORKDIR}" -name '*.profraw' 2>/dev/null) )
	fi

	if [[ ${#profraw_files[@]} -eq 0 ]]; then
		die "No profile data (*.profraw) was generated. Tests did not exercise instrumented code."
	fi

	einfo "Collected ${#profraw_files[@]} profile file(s)"

	if tc-is-clang; then
		llvm-profdata merge -output="${pgo_dir}/default.profdata" \
			"${profraw_files[@]}" || die
	fi

	# === PGO second pass: optimized build ===
	einfo "PGO: second pass (using profile data)"

	rm -rf "${BUILD_DIR}" || die
	filter-flags -fprofile-* -flto*

	local pgo_use_flags
	if tc-is-clang; then
		pgo_use_flags="-fprofile-instr-use=${pgo_dir}/default.profdata"
	else
		pgo_use_flags="-fprofile-use=${pgo_dir} -fprofile-dir=${pgo_dir}"
		pgo_use_flags+=" $(test-flags-CC -fprofile-partial-training)"
	fi

	# Apply LTO in the final (use) pass
	local lto_flags=$(_get_lto_flags)
	pgo_use_flags+=" ${lto_flags}"

	local mycmakeargs=(
		-DWITH_BZIP2=SYSTEM
		-DWITH_CRYPTOPP=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DENABLE_TEST=OFF
		-DCMAKE_C_FLAGS="${CFLAGS} ${pgo_use_flags}"
		-DCMAKE_CXX_FLAGS="${CXXFLAGS} ${pgo_use_flags}"
		-DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} ${pgo_use_flags}"
		-DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} ${pgo_use_flags}"
	)

	cmake_src_configure
	cmake_src_compile
}
