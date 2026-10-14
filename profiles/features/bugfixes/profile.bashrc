source /lib/StormByte/portage.sh

local FORCE_BINUTIL_VARS="dev-java/openjdk app-crypt/efitools dev-lang/ocaml dev-libs/jansson net-analyzer/rrdtool sys-libs/libnvidia-container"
local FORCE_LD_UNDEFINED_VERSION="dev-java/openjdk media-libs/tremor media-gfx/gimp net-firewall/nfacct media-libs/tremor"
local FORCE_GCC_VARS="sys-power/iasl sys-apps/apparmor"
local FORCE_PIC_VARS="llvm-runtimes/libcxx llvm-runtimes/libcxxabi"
local FORCE_OPENMP_VARS="media-sound/fluidsynth"
local FORCE_REDUCE_PARALLEL=""

if [[ -z "$DISABLE_BUGFIXES" ]]; then
	if [[ ${EBUILD_PHASE} == "configure" ]]; then
		list_contains "${FORCE_BINUTIL_VARS}" "${CATEGORY}/${PN}" && force_binutils_vars
		list_contains "${FORCE_PIC_VARS}" "${CATEGORY}/${PN}" && force_pic_vars
		list_contains "${FORCE_LD_UNDEFINED_VERSION}" "${CATEGORY}/${PN}" && force_ld_undefined_version
		list_contains "${FORCE_GCC_VARS}" "${CATEGORY}/${PN}" && force_gcc_vars
		list_contains "${FORCE_OPENMP_VARS}" "${CATEGORY}/${PN}" && force_openmp_vars
		list_contains "${FORCE_REDUCE_PARALLEL}" "${CATEGORY}/${PN}" && force_reduce_parallel
	fi
	# Gcc needs it for Intel's big little arch
	if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]; then
		force_gcc_vars
		if [[ -n "$INTEL_BIG_LITTLE" ]]; then
			local FLAGS_MARCH
			FLAGS_MARCH="$(resolve-march-native --drop-cache-sizes)"

			# Drop shadow-stack and CET flags (they break GCC 16 bootstrap, especially
			# the static TLS test in libgomp)
			FLAGS_MARCH="${FLAGS_MARCH//-mshstk/}"
			FLAGS_MARCH="${FLAGS_MARCH//-fcf-protection=full/}"
			FLAGS_MARCH="${FLAGS_MARCH//-fcf-protection=return/}"
			FLAGS_MARCH="${FLAGS_MARCH//-fcf-protection=branch/}"

			# Collapse any double spaces left after removing the flags
			FLAGS_MARCH="$(echo "$FLAGS_MARCH" | tr -s ' ')"

			# FLAGS_SECURITY is removed for gcc as of gcc bug failing to compile with them
			CFLAGS="${FLAGS_BASE} ${FLAGS_GRAPHITE} ${FLAGS_DEBUG} ${FLAGS_MARCH}"
			CXXFLAGS="${CFLAGS}"
		fi
		LDFLAGS="${LINKER_BASE}"
	fi
fi

