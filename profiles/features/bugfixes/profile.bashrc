source /lib/StormByte/functions.sh

local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
local FORCE_LD_UNDEFINED_VERSION="dev-java/openjdk dev-libs/totem-pl-parser media-libs/libva media-libs/tremor net-analyzer/rrdtool net-firewall/nfacct net-fs/samba net-libs/gtk-vnc net-misc/spice-gtk net-wireless/bluez sys-libs/ldb sys-libs/libblockdev sys-libs/slang sys-libs/talloc sys-libs/tevent sys-libs/tdb sys-apps/util-linux"

if [[ -z "$DISABLE_BUGFIXES" ]]; then
	list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
	list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
fi

# Glibc special options for valgrind
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi

if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]; then
	force_gcc_vars
	CFLAGS="-march=alderlake -mabm -mno-cldemote -mno-kl -mno-pconfig -mno-sgx -mno-widekl -mshstk --param=l1-cache-line-size=64 --param=l1-cache-size=32 --param=l2-cache-size=36864 -O2 -pipe"
	CXXFLAGS="${CFLAGS}"
fi
