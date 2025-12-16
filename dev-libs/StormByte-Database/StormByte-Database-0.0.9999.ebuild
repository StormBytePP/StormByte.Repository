EAPI=8

inherit git-r3 cmake

DESCRIPTION="StormByte C++ Library"
HOMEPAGE="https://dev.stormbyte.org/StormByteDatabase"
EGIT_REPO_URI="https://github.com/StormBytePP/${PN}.git"

LICENSE="GPL"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+mariadb pgo +postgres +sqlite"

DEPEND="
	mariadb? ( dev-db/mariadb-connector-c )
	postgres? ( dev-db/postgresql )
	sqlite? ( dev-db/sqlite:3 )
	dev-libs/StormByte
	dev-libs/StormByte-Logger
"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-build/cmake-3.12.0"

src_configure() {
	# Allow callers to override test enabling via FORCE_ENABLE_TEST (ON/OFF).
	local enable_tests=OFF
	if [[ -n "${FORCE_ENABLE_TEST}" ]]; then
		enable_tests="${FORCE_ENABLE_TEST}"
	else
		if use pgo ; then
			enable_tests=ON
		fi
	fi
	local mycmakeargs=(
		-DWITH_SYSTEM_STORMBYTE=ON
		-DWITH_SQLITE=$(usex sqlite SYSTEM OFF)
		-DWITH_MARIADB=$(usex mariadb SYSTEM OFF)
		-DWITH_POSTGRES=$(usex postgres SYSTEM OFF)
		-DENABLE_TEST=${enable_tests}
	)
	cmake_src_configure
}

# PGO: when USE=pgo, perform an instrumented build, run unit tests to
# collect profile data, then rebuild using the generated profile.
src_compile() {
	if use pgo ; then
		ewarn "Building with PGO: phase 1 (instrumented build + tests)"

		# Make environment more stable for long-running tests/profile tasks.
		# Match Python ebuild behavior around timeouts/sandboxing.
		local -x COLUMNS=80
		local -x TMPDIR=/var/tmp
		local -x LC_ALL=C

		# Use a separate build dir for the instrumented run so we can
		# generate profiles there and then do a clean profile-use rebuild
		# in the normal build dir.
		local _pgo_dir="${S}/pgo-data"
		mkdir -p "${_pgo_dir}"

		local _old_cflags="${CFLAGS}"
		local _old_cxxflags="${CXXFLAGS}"

		# Determine full, absolute original build dir. Prefer BUILD_DIR,
		# then B, then fall back to the conventional WORKDIR/${PN}_build.
		local _orig_B
		if [[ -n "${BUILD_DIR}" ]]; then
			_orig_B="${BUILD_DIR}"
		elif [[ -n "${B}" ]]; then
			_orig_B="${B}"
		else
			_orig_B="${WORKDIR}/${PN}_build"
		fi

		local _instr_B="${_orig_B}_pgo_instr"

		# Instrumented build in separate build dir
		mkdir -p "${_instr_B}"

		if tc-is-clang ; then
			export CFLAGS="${_old_cflags} -fprofile-instr-generate"
			export CXXFLAGS="${_old_cxxflags} -fprofile-instr-generate"
			# Ensure clang writes .profraw files into our pgo dir.
			export LLVM_PROFILE_FILE="${_pgo_dir}/%m-%p.profraw"
		else
			export CFLAGS="${_old_cflags} -fprofile-generate=${_pgo_dir}"
			export CXXFLAGS="${_old_cxxflags} -fprofile-generate=${_pgo_dir}"
		fi

		FORCE_ENABLE_TEST=ON BUILD_DIR="${_instr_B}" src_configure || die "PGO: instrumented configure failed"
		BUILD_DIR="${_instr_B}" cmake_src_compile || die "PGO: instrumented build failed"

		ewarn "PGO requested — running unit tests to collect profile data"
		BUILD_DIR="${_instr_B}" cmake_src_test || die "PGO: running unit tests failed"
		# Unset LLVM_PROFILE_FILE here so it doesn't leak into later phases
		if tc-is-clang ; then
			unset LLVM_PROFILE_FILE
		fi

		# Profile-use rebuild in the original build dir (clean)
		ewarn "Building with PGO: phase 2 (profile-use rebuild)"

		# Verify profile data was produced (look for .profraw files)
		if ! find "${_pgo_dir}" -name '*.profraw' -print -quit >/dev/null 2>&1 ; then
			die "PGO: no .profraw profile data generated in ${_pgo_dir}"
		fi

		# Merge raw profiles into a single profdata file for use by clang.
		if ! command -v llvm-profdata >/dev/null 2>&1 ; then
			die "PGO: llvm-profdata not found; please ensure llvm-profdata is available for merging profiles"
		fi

		llvm-profdata merge -o "${_pgo_dir}/default.profdata" "${_pgo_dir}"/*.profraw || die "PGO: llvm-profdata merge failed"

		# ensure original build dir is clean so CMake regenerates everything
		rm -rf "${_orig_B}" || die "PGO: failed to remove original build dir"
		mkdir -p "${_orig_B}"

		if tc-is-clang ; then
			BUILD_DIR="${_orig_B}" export CFLAGS="${_old_cflags} -fprofile-instr-use=${_pgo_dir}/default.profdata"
			BUILD_DIR="${_orig_B}" export CXXFLAGS="${_old_cxxflags} -fprofile-instr-use=${_pgo_dir}/default.profdata"
		else
			BUILD_DIR="${_orig_B}" export CFLAGS="${_old_cflags} -fprofile-use=${_pgo_dir} -fprofile-correction"
			BUILD_DIR="${_orig_B}" export CXXFLAGS="${_old_cxxflags} -fprofile-use=${_pgo_dir} -fprofile-correction"
		fi

		FORCE_ENABLE_TEST=OFF BUILD_DIR="${_orig_B}" src_configure || die "PGO: profile-use configure failed"
		BUILD_DIR="${_orig_B}" cmake_src_compile || die "PGO: profile-use build failed"

		# restore flags for later phases
		export CFLAGS="${_old_cflags}"
		export CXXFLAGS="${_old_cxxflags}"
	else
		cmake_src_compile
	fi
}
