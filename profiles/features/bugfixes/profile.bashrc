source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local GCC_FORCED_PACKAGES="sys-devel/gcc"
    local CXX11_FORCED_PACKAGES="dev-util/ddd media-libs/gexiv2"
    local PIC_FORCED_PACKAGES="sys-libs/libcxx sys-libs/libcxxabi"
    local POLLY_DISABLE_PACKAGES="media-libs/libmad dev-util/valgrind media-video/ffmpeg"
    local FORCE_LD_UNDEFINED_VERSION="dev-libs/libbsd"

    list_contains "${GCC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_gcc_vars
    list_contains "${CXX11_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_cxx11_vars
    list_contains "${PIC_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_pic_vars
    #list_contains "${POLLY_DISABLE_PACKAGES}" "${CATEGORY}/${PN}" && force_polly_disable
    list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
    [ "${CATEGORY}/${PN}:${SLOT}" == "x11-libs/wxGTK:3.0-gtk3" ] && force_cxx11_vars

    # Glibc special options for valgrind
    if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
        force_gcc_vars
        CFLAGS="${CFLAGS} -fno-builtin-strlen"
        CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
    fi
fi