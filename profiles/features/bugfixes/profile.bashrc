source /lib/StormByte/functions.sh

local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
local FORCE_LD_UNDEFINED_VERSION="dev-java/openjdk dev-libs/totem-pl-parser media-libs/alsa-lib media-libs/libva media-libs/tremor net-analyzer/rrdtool net-firewall/nfacct net-fs/samba net-libs/gtk-vnc net-misc/spice-gtk net-wireless/bluez sys-libs/ldb sys-libs/libblockdev sys-libs/slang sys-libs/talloc sys-libs/tevent sys-libs/tdb sys-apps/util-linux"
local FORCE_BINUTILS_VARS="app-crypt/efitools dev-lang/ocaml"
local FORCE_GCC_VARS=""
local FORCE_BINUTILS_LINKER="app-crypt/efitools"

if [[ -z "$DISABLE_BUGFIXES" ]]; then
	list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
	list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
	list_contains "${FORCE_BINUTILS_VARS}" "${CATEGORY}/${PN}" && force_binutils_vars
	list_contains "${FORCE_GCC_VARS}" "${CATEGORY}/${PN}" && force_gcc_vars
	list_contains "${FORCE_BINUTILS_LINKER}" "${CATEGORY}/${PN}" && force_binutils_linker
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
