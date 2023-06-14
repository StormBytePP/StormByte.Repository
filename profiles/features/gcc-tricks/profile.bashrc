# Helper function
function list_contains () { [[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]; }

# Packages known to fail to compile with GCC
# sys-libs/libxcrypt needs its own /etc/portage/env file as it fails here (investigate why)
export GCC_FORCED_PACKAGES="sys-devel/gcc sys-libs/glibc app-crypt/efitools"

## GCC will fail to compile with march=native and CET so we need to manually expand native flags and apply to all
COMPILER_OPTIMIZATION_GCC_NATIVE_EXPAND="-march=alderlake -mmmx -mpopcnt -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -mavx2 -mno-sse4a -mno-fma4 -mno-xop -mfma -mno-avx512f -mbmi -mbmi2 -maes -mpclmul -mno-avx512vl -mno-avx512bw -mno-avx512dq -mno-avx512cd -mno-avx512er -mno-avx512pf -mno-avx512vbmi -mno-avx512ifma -mno-avx5124vnniw -mno-avx5124fmaps -mno-avx512vpopcntdq -mno-avx512vbmi2 -mgfni -mvpclmulqdq -mno-avx512vnni -mno-avx512bitalg -mno-avx512bf16 -mno-avx512vp2intersect -mno-3dnow -madx -mabm -mno-cldemote -mclflushopt -mclwb -mno-clzero -mcx16 -mno-enqcmd -mf16c -mfsgsbase -mfxsr -mno-hle -msahf -mno-lwp -mlzcnt -mmovbe -mmovdir64b -mmovdiri -mno-mwaitx -mno-pconfig -mpku -mno-prefetchwt1 -mprfchw -mptwrite -mrdpid -mrdrnd -mrdseed -mno-rtm -mserialize -mno-sgx -msha -mshstk -mno-tbm -mno-tsxldtrk -mvaes -mwaitpkg -mno-wbnoinvd -mxsave -mxsavec -mxsaveopt -mxsaves -mno-amx-tile -mno-amx-int8 -mno-amx-bf16 -mno-uintr -mhreset -mno-kl -mno-widekl -mavxvnni -mno-avx512fp16 -mno-avxifma -mno-avxvnniint8 -mno-avxneconvert -mno-cmpccxadd -mno-amx-fp16 -mno-prefetchi -mno-raoint -mno-amx-complex --param l1-cache-size=48 --param l1-cache-line-size=64 --param l2-cache-size=36864 -mtune=alderlake"

if list_contains "${GCC_FORCED_PACKAGES}" "${CATEGORY}/${PN}"; then
    CC="gcc"
    CXX="g++"
    ADDR2LINE="addr2line"
    AS="as"
    AR="ar"
    NM="nm"
    OBJCOPY="objcopy"
    OBJDUMP="objdump"
    RANLIB="ranlib"
    READELF="readelf"
    STRINGS="strings"
    STRIP="strip"
    if [[ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]]; then
	    CFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_GCC_NATIVE_EXPAND} ${COMPILER_OPTIMIZATION_GCC} ${COMPILER_OPTIMIZATION_CET}";
    else
        CFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_CPU} ${COMPILER_OPTIMIZATION_GCC} ${COMPILER_OPTIMIZATION_CET}";
    fi
    CXXFLAGS="${CFLAGS}";
fi
