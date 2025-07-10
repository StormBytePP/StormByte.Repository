source /lib/StormByte/functions.sh

local FORCE_BINUTIL_VARS="app-crypt/efitools dev-libs/jansson"
local FORCE_LD_UNDEFINED_VERSION="dev-java/openjdk dev-libs/totem-pl-parser media-libs/alsa-lib media-libs/libva media-libs/tremor net-analyzer/rrdtool net-firewall/nfacct net-fs/samba net-libs/gtk-vnc net-misc/spice-gtk net-wireless/bluez x11-libs/wxGTK sys-libs/ldb sys-libs/libblockdev sys-libs/slang sys-libs/talloc sys-libs/tevent sys-libs/tdb sys-apps/util-linux"
local FORCE_GCC_VARS=""
local FORCE_PIC_VARS="llvm-runtimes/libcxx llvm-runtimes/libcxxabi"
local FORCE_OPENMP_VARS="media-sound/fluidsynth"
local FORCE_REDUCE_PARALLEL="net-im/telegram-desktop"

if [[ -z "$DISABLE_BUGFIXES" ]]; then
	list_contains "${FORCE_BINUTIL_VARS}" "${CATEGORY}/${PN}" && force_binutils_vars
	list_contains "${FORCE_PIC_VARS}" "${CATEGORY}/${PN}" && force_pic_vars
	list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
	list_contains "${FORCE_GCC_VARS}" "${CATEGORY}/${PN}" && force_gcc_vars
	list_contains "${FORCE_OPENMP_VARS}" "${CATEGORY}/${PN}" && force_openmp_vars
	list_contains "${FORCE_REDUCE_PARALLEL}" "${CATEGORY}/${PN}" && force_reduce_parallel
fi

# Glibc special options for valgrind
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi

if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]; then
	force_gcc_vars
	CFLAGS="$(resolve-march-native) ${COMPILER_OPTIMIZATION_BASE}"
	CXXFLAGS="${CFLAGS}"
    LDFLAGS="${LINKER_OPTIMIZATION_BASE}"
fi
