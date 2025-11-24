source /lib/StormByte/functions.sh

if [ "${CATEGORY}/${PN}" == "sys-kernel/gentoo-kernel" ]; then
	export CC=gcc
    export CXX=g++
    export LD=bfd
	export LLVM=0
fi