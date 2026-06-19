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
	media-video/ffmpeg-chromium
	llvm-core/clang
	llvm-core/llvm
	llvm-runtimes/libcxx
	www-client/firefox
"
# Thunderbird and firefox fails with polly
local POLLY_FORCED_PACKAGES="
	app-office/libreoffice
	media-gfx/gimp
	media-libs/avidemux-core
	media-libs/avidemux-plugins
	media-video/ffmpeg
	media-video/ffmpeg-chromium
	media-video/mpv
	media-video/obs-studio
	media-sound/audacity
	media-sound/mixxx
"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
	list_contains "${POLLY_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_polly_vars
fi
