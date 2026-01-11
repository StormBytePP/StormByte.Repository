source /lib/StormByte/functions.sh

# Glibc special options for valgrind
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi