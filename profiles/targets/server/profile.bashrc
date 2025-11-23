source /lib/StormByte/functions.sh

if [ "${CATEGORY}/${PN}" == "sys-kernel/gentoo-kernel" ]; then
	force_gcc_vars
fi