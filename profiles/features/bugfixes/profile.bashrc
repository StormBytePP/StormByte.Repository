source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local GCC_FORCED_PACKAGES="sys-devel/gcc"
    local CXX11_FORCED_PACKAGES=""
    local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
    local FORCE_LD_UNDEFINED_VERSION="dev-libs/libbsd net-analyzer/rrdtool sys-apps/keyutils sys-libs/binutils-libs media-libs/mesa sys-libs/slang media-libs/libva media-libs/alsa-lib dev-libs/libcdio net-wireless/bluez"

    list_contains "${GCC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_gcc_vars
    list_contains "${CXX11_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_cxx11_vars
    list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
    list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version

    # Glibc special options for valgrind
    if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
        force_gcc_vars
        CFLAGS="${CFLAGS} -fno-builtin-strlen"
        CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
    fi
fi