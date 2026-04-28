source /lib/StormByte/portage.sh

# Don't include things containing rust for LTO like thunderbird, firefox, libreoffice, etc.
local LTO_FORCED_PACKAGES="dev-lang/erlang dev-lang/nasm media-libs/x264 media-libs/x265 media-video/ffmpeg llvm-core/clang llvm-core/llvm llvm-runtimes/libcxx"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi
