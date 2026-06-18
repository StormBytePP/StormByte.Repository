#! /bin/bash

# Version 4.1.0

function list_contains() { [[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]; }

function force_binutils_vars() {
	local binutils_prefix="$(binutils-config -B)"
	ADDR2LINE="${binutils_prefix}/addr2line"
	AS="${binutils_prefix}/as"
	AR="${binutils_prefix}/ar"
	NM="${binutils_prefix}/nm"
	OBJCOPY="${binutils_prefix}/objcopy"
	OBJDUMP="${binutils_prefix}/objdump"
	RANLIB="${binutils_prefix}/ranlib"
	READELF="${binutils_prefix}/readelf"
	STRINGS="${binutils_prefix}/strings"
	STRIP="${binutils_prefix}/strip"
	LDFLAGS="${LINKER_BASE} ${LINKER_BFD}"
}

function force_gcc_vars() {
	OCC="gcc"
	OCXX="g++"
	CC="gcc"
	CXX="g++"
	CPP="cpp"
	CFLAGS="${FLAGS_BASE} ${FLAGS_CPU} ${FLAGS_GCC} ${FLAGS_SECURITY} ${FLAGS_GRAPHITE}"
	CXXFLAGS="${CFLAGS}"
	force_binutils_vars
}

function force_pic_vars() {
	CFLAGS="${CFLAGS} -fPIC"
	CXXFLAGS="${CXXFLAGS} -fPIC"
}

function force_lto_vars() {
	CFLAGS="${CFLAGS} ${FLAGS_LTO}"
	CXXFLAGS="${CXXFLAGS} ${FLAGS_LTO}"
	LDFLAGS="${LDFLAGS} ${FLAGS_LTO}"
}

function force_polly_vars() {
	CFLAGS="${CFLAGS} ${POLLY_FLAGS}"
	CXXFLAGS="${CXXFLAGS} ${POLLY_FLAGS}"
	LDFLAGS="${LDFLAGS} ${LINKER_POLLY}"
}

function force_ld_undefined_version {
	LDFLAGS="${LINKER_BASE} -Wl,--undefined-version" 
}

function force_openmp_vars() {
	CFLAGS="${CFLAGS} -fopenmp"
	CXXFLAGS="${CXXFLAGS} -fopenmp"
}

function force_reduce_parallel() {
	MAKEFLAGS="-j8"
}

# Useful variables
cores=$(nproc)
