source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang net-libs/webkit-gtk mail-client/thunderbird media-libs/x264 media-libs/x265 media-video/ffmpeg www-client/firefox"

    list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi

if [[ ! -z ${CCACHE_DIR} ]]; then
	export CCACHE_DIR="/var/cache/ccache/${CATEGORY}/${P}"
	mkdir -p "${CCACHE_DIR}"
fi