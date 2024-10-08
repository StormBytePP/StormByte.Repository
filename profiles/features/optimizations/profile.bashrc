source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang dev-lang/nasm media-libs/x264 media-libs/x265 media-video/ffmpeg sys-devel/clang sys-devel/llvm sys-libs/libcxx"

    list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi
