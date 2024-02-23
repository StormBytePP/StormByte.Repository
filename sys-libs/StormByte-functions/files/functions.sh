#! /bin/bash

# Version 1.4.1

function displayError() {
	echo $1
	exit
}

function handleCommand() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	echo -n "${2} ... "
	eval $1 > /dev/null 2>&1

	if [ $? -eq 0 ]; then
		echo "OK"
	else
		cd "${current_folder}"
		displayError "ERROR in command $1"
	fi
}

function handleCommandWithOutput() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	echo "${2} ... "
	eval $1

	if [ $? -ne 0 ]; then
		cd "${current_folder}"
		displayError "ERROR in command $1"
	fi
}

function loadConfig() {
	if [ -f "${workdir}/${self}.conf" ]; then
		source "${workdir}/${self}.conf"
	elif [ -f "/etc/conf.d/${self}.conf" ]; then
		source "/etc/conf.d/${self}.conf"
	else
		echo "Configuration file ${self}.conf not found neither in current directory neither in /etc/conf.d!"
		exit 1
	fi
}

function list_contains() { [[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]; }

function force_binutils_vars() {
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
}

function force_gcc_vars() {
    OCC="gcc"
    OCXX="g++"
	CC="gcc"
	CXX="g++"
	CPP="cpp"
    CFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_CPU} ${COMPILER_OPTIMIZATION_GCC} ${COMPILER_OPTIMIZATION_CET} -fno-builtin-strlen"
    CXXFLAGS="${CFLAGS}"
    LDFLAGS="${LINKER_OPTIMIZATION_BASE} ${LINKER_OPTIMIZATION_BFD}"
    force_binutils_vars
}

function force_cxx11_vars() {
    CXXFLAGS="${CXXFLAGS} -std=c++11"
}

function force_pic_vars() {
    CFLAGS="${CFLAGS} -fPIC"
    CXXFLAGS="${CXXFLAGS} -fPIC"
}

function force_lto_vars() {
    CFLAGS="${CFLAGS} ${COMPILER_OPTIMIZATION_LTO}"
    CXXFLAGS="${CXXFLAGS} ${COMPILER_OPTIMIZATION_LTO}"
    LDFLAGS="${LDFLAGS} ${COMPILER_OPTIMIZATION_LTO}"
    RUSTFLAGS="${RUSTFLAGS} -Clinker-plugin-lto"
}

function force_polly_disable {
	CFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_CPU} -Wno-unused-command-line-argument ${COMPILER_OPTIMIZATION_CET}"
	CXXFLAGS="${COMPILER_OPTIMIZATION_BASE} ${COMPILER_OPTIMIZATION_CPU} -Wno-unused-command-line-argument ${COMPILER_OPTIMIZATION_CET}"
	LDFLAGS="${LINKER_OPTIMIZATION_BASE}"
}

function force_ld_undefined_version {
	LDFLAGS="${LINKER_OPTIMIZATION_BASE} -Wl,--undefined-version" 
}

# Useful variables
workdir="${0%/*}"
self=`basename $0`
parameters=("${@:1}")
current_dir=`pwd`
