source /lib/StormByte/functions.sh

if [[ "${EBUILD_PHASE}" == "configure" ]] ; then
    local LTO_FORCED_PACKAGES="media-video/ffmpeg www-client/firefox app-office/libreoffice mail-client/thunderbird media-libs/x264 media-libs/x265"

    list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
fi

if [[ ${FEATURES} == *ccache* && ${EBUILD_PHASE_FUNC} == src_* ]]; then
	if [[ ${CCACHE_DIR} == /var/cache/ccache ]]; then
		export CCACHE_DIR=/var/cache/ccache/${CATEGORY}/${PN}:${SLOT}
		mkdir -p "${CCACHE_DIR}" || die
	fi
fi