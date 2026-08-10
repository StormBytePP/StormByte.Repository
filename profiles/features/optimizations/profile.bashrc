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

local POLLY_FORCED_PACKAGES="
    app-office/libreoffice
    media-gfx/gimp
    media-sound/audacity
    media-sound/mixxx
    media-video/avidemux
    media-video/mpv
    media-video/obs-studio
    sci-visualization/gnuplot
"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
	list_contains "${POLLY_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_polly_vars
fi
