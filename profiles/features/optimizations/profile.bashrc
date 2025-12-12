source /lib/StormByte/functions.sh

# Don't include things containing rust for LTO like thunderbird, firefox, libreoffice, etc.
local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang dev-lang/nasm mail-client/thunderbird media-libs/x264 media-libs/x265 media-video/ffmpeg llvm-core/clang llvm-core/llvm llvm-runtimes/libcxx www-client/firefox"

list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars

# Glibc special options for valgrind
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi

# Gcc needs it for Intel's big little arch
if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]; then
	force_gcc_vars
	if [[ -n "$INTEL_BIG_LITTLE" ]]; then
		CFLAGS="$(resolve-march-native) ${COMPILER_OPTIMIZATION_BASE}"
		CXXFLAGS="${CFLAGS}"
	fi
    LDFLAGS="${LINKER_OPTIMIZATION_BASE}"
fi