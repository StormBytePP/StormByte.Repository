source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang mail-client/thunderbird media-libs/x264 media-libs/x265 media-video/ffmpeg sys-libs/libcxx sys-libs/libcxxabi www-client/firefox"

    list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi

if [[ ${FEATURES} == *ccache* && ${EBUILD_PHASE_FUNC} == src_* ]]; then
	if [[ ${CCACHE_DIR} == /var/cache/ccache ]]; then
		export CCACHE_DIR=/var/cache/ccache/${CATEGORY}/${PN}:${SLOT}
		mkdir -p "${CCACHE_DIR}" || die
	fi
fi