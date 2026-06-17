source /lib/StormByte/portage.sh

local LTO_FORCED_PACKAGES="
	app-office/libreoffice
	dev-lang/erlang
	dev-lang/nasm
	mail-client/thunderbird
	media-libs/avidemux-core
	media-libs/x264
	media-libs/x265
	media-video/ffmpeg
	llvm-core/clang
	llvm-core/llvm
	llvm-runtimes/libcxx
	www-client/firefox
"
local POLLY_FORCED_PACKAGES="
	app-office/libreoffice
	mail-client/thunderbird
	media-gfx/gimp
	media-libs/avidemux-core
	media-libs/avidemux-plugins
	media-video/ffmpeg
	media-video/mpv
	media-video/obs-studio
	media-sound/audacity
	media-sound/mixxx
	www-client/firefox
"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
	list_contains "${POLLY_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_polly_vars
fi
