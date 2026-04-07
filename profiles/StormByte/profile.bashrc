source /lib/StormByte/functions.sh

if [ "${CATEGORY}/${PN}" == "sys-devel/gcc" ] || [ "${CATEGORY}/${PN}" == "sys-libs/glibc" ]; then
	force_gcc_vars
fi