source /lib/StormByte/functions.sh

local GCC_FORCED_PACKAGES="sys-devel/gcc sys-libs/glibc"
local CXX11_FORCED_PACKAGES=""
local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
local FORCE_LD_UNDEFINED_VERSION="dev-java/openjdk dev-libs/totem-pl-parser media-libs/tremor net-analyzer/rrdtool net-firewall/nfacct net-libs/gtk-vnc net-misc/spice-gtk net-wireless/bluez sys-libs/slang"

list_contains "${GCC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_gcc_vars

if [[ -z "$DISABLE_BUGFIXES" ]]; then
	list_contains "${CXX11_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_cxx11_vars
	list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
	list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
fi

# Glibc special options for valgrind
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi
