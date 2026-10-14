source /lib/StormByte/portage.sh

# Glibc special options for valgrind, execute in all ebuild phases to ensure validity
if [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	CFLAGS="${CFLAGS} -fno-builtin-strlen"
	CXXFLAGS="${CXXFLAGS} -fno-builtin-strlen"
fi