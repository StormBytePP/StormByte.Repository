#! /bin/bash

# Version 3.0.2

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
    RUSTFLAGS="${RUSTFLAGS} -Clinker-plugin-lto"
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
