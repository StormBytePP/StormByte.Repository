source /lib/StormByte/portage.sh

# Don't include things containing rust for LTO like thunderbird, firefox, libreoffice, etc.
local LTO_FORCED_PACKAGES="app-office/libreoffice dev-lang/erlang dev-lang/nasm dev-lang/rust mail-client/thunderbird media-libs/x264 media-libs/x265 media-video/ffmpeg llvm-core/clang llvm-core/llvm llvm-runtimes/libcxx www-client/firefox"
local POLLY_FORCED_PACKAGES="app-office/libreoffice dev-lang/rust mail-client/thunderbird www-client/firefox"

if [[ ${EBUILD_PHASE} == "configure" ]]; then
	list_contains "${LTO_FORCED_PACKAGES}" "${CATEGORY}/${PN}" && force_lto_vars
	if list_contains "${POLLY_FORCED_PACKAGES}" "${CATEGORY}/${PN}"; then
		CXXFLAGS="${CXXFLAGS} ${POLLY_FLAGS}"
		LDFLAGS="${LDFLAGS} ${LINKER_POLLY}"
	fi
fi
