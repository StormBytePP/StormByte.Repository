source /lib/StormByte/functions.sh

# Gcc needs -march=native expanded with CET as of bug #908523
if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ]; then
    force_gcc_vars
    CFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_GCC_NATIVE_EXPAND} ${COMPILER_OPTIMIZATION_GCC} ${COMPILER_OPTIMIZATION_CET}";
    CXXFLAGS="${CFLAGS}";
fi
