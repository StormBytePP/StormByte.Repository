source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local GCC_FORCED_PACKAGES="sys-devel/gcc app-crypt/efitools"
    local CXX11_FORCED_PACKAGES="dev-util/ddd media-libs/gexiv2"
    local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
    local CCACHE_DISABLE_PACKAGES="dev-java/openjdk"

    list_contains "${GCC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_gcc_vars
    list_contains "${CXX11_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_cxx11_vars
    list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
    list_contains "${CCACHE_DISABLE_PACKAGES}" "${CATEGORY}/${PN}" && force_ccache_disable
    [ "${CATEGORY}/${PN}:${SLOT}" == "gui-libs/gtk:4" ] && force_binutils_vars
    [ "${CATEGORY}/${PN}:${SLOT}" == "x11-libs/wxGTK:3.0-gtk3" ] && force_cxx11_vars

    # Glibc special options for valgrind
    if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
        force_gcc_vars
        CFLAGS="${CFLAGS} -fno-builtin-strlen"
        CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
    fi
elif [[ "${EBUILD_PHASE}" == "pretend" ]] ; then
    list_contains "${CCACHE_DISABLE_PACKAGES}" "${CATEGORY}/${PN}" && force_ccache_disable
fi