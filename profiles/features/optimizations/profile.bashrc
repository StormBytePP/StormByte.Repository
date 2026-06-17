source /lib/StormByte/portage.sh

# Don't include things containing rust for LTO like thunderbird, firefox, libreoffice, etc.
local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang dev-lang/nasm mail-client/thunderbird media-libs/x264 media-libs/x265 media-video/ffmpeg llvm-core/clang llvm-core/llvm llvm-runtimes/libcxx www-client/firefox"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi
