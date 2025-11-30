source /lib/StormByte/functions.sh

local FORCE_BINUTIL_VARS="app-crypt/efitools dev-lang/ocaml dev-libs/jansson"
local FORCE_LD_UNDEFINED_VERSION="media-libs/tremor net-analyzer/rrdtool net-firewall/nfacct"
local FORCE_GCC_VARS="sys-power/iasl sys-apps/apparmor"
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

