# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Auto-Generated by cargo-ebuild 0.5.2

EAPI=8

CRATES="
	ab_glyph-0.2.21
	ab_glyph_rasterizer-0.1.8
	adler-1.0.2
	aho-corasick-0.7.20
	aho-corasick-1.0.2
	anstream-0.3.2
	anstyle-1.0.0
	anstyle-parse-0.2.0
	anstyle-query-1.0.0
	anstyle-wincon-1.0.1
	anyhow-1.0.71
	assert_cmd-2.0.11
	assert_fs-1.0.13
	autocfg-1.1.0
	bitflags-1.3.2
	bitstream-io-1.6.0
	bitvec_helpers-3.1.2
	bstr-1.5.0
	bumpalo-3.13.0
	bytemuck-1.13.1
	byteorder-1.4.3
	cc-1.0.79
	cfg-if-1.0.0
	clap-4.3.4
	clap_builder-4.3.4
	clap_derive-4.3.2
	clap_lex-0.5.0
	cmake-0.1.50
	color_quant-1.1.0
	colorchoice-1.0.0
	console-0.15.7
	const-cstr-0.3.0
	core-foundation-0.9.3
	core-foundation-sys-0.8.4
	core-graphics-0.22.3
	core-graphics-types-0.1.1
	core-text-19.2.0
	crc32fast-1.3.2
	difflib-0.4.0
	dirs-next-2.0.0
	dirs-sys-next-0.1.2
	dlib-0.5.2
	doc-comment-0.3.3
	dwrote-0.11.0
	either-1.8.1
	encode_unicode-0.3.6
	errno-0.3.1
	errno-dragonfly-0.1.2
	fastrand-1.9.0
	fdeflate-0.3.0
	flate2-1.0.26
	float-cmp-0.9.0
	float-ord-0.2.0
	fnv-1.0.7
	font-kit-0.11.0
	foreign-types-0.3.2
	foreign-types-shared-0.1.1
	freetype-0.7.0
	freetype-sys-0.13.1
	getrandom-0.2.10
	globset-0.4.10
	globwalk-0.8.1
	hashbrown-0.12.3
	heck-0.4.1
	hermit-abi-0.3.1
	hevc_parser-0.6.1
	ignore-0.4.20
	image-0.24.6
	indexmap-1.9.3
	indicatif-0.17.5
	instant-0.1.12
	io-lifetimes-1.0.11
	is-terminal-0.4.7
	itertools-0.10.5
	itoa-1.0.6
	jpeg-decoder-0.3.0
	js-sys-0.3.64
	lazy_static-1.4.0
	libc-0.2.146
	libloading-0.8.0
	linux-raw-sys-0.3.8
	log-0.4.19
	memchr-2.5.0
	minimal-lexical-0.2.1
	miniz_oxide-0.7.1
	nom-7.1.3
	normalize-line-endings-0.3.0
	num-integer-0.1.45
	num-rational-0.4.1
	num-traits-0.2.15
	number_prefix-0.4.0
	once_cell-1.18.0
	owned_ttf_parser-0.19.0
	pathfinder_geometry-0.5.1
	pathfinder_simd-0.5.1
	pest-2.6.0
	pkg-config-0.3.27
	plotters-0.3.5
	plotters-backend-0.3.5
	plotters-bitmap-0.3.3
	png-0.17.9
	portable-atomic-1.3.3
	predicates-2.1.5
	predicates-3.0.3
	predicates-core-1.0.6
	predicates-tree-1.0.9
	proc-macro2-1.0.60
	quote-1.0.28
	redox_syscall-0.2.16
	redox_syscall-0.3.5
	redox_users-0.4.3
	regex-1.8.4
	regex-automata-0.1.10
	regex-syntax-0.7.2
	rustc_version-0.3.3
	rustix-0.37.20
	ryu-1.0.13
	same-file-1.0.6
	semver-0.11.0
	semver-parser-0.10.2
	serde-1.0.164
	serde_derive-1.0.164
	serde_json-1.0.97
	simd-adler32-0.3.5
	strsim-0.10.0
	syn-2.0.18
	tempfile-3.6.0
	terminal_size-0.2.6
	termtree-0.4.1
	thiserror-1.0.40
	thiserror-impl-1.0.40
	thread_local-1.1.7
	ttf-parser-0.17.1
	ttf-parser-0.19.0
	ucd-trie-0.1.5
	unicode-ident-1.0.9
	unicode-width-0.1.10
	utf8parse-0.2.1
	wait-timeout-0.2.0
	walkdir-2.3.3
	wasi-0.11.0+wasi-snapshot-preview1
	wasm-bindgen-0.2.87
	wasm-bindgen-backend-0.2.87
	wasm-bindgen-macro-0.2.87
	wasm-bindgen-macro-support-0.2.87
	wasm-bindgen-shared-0.2.87
	web-sys-0.3.64
	winapi-0.3.9
	winapi-i686-pc-windows-gnu-0.4.0
	winapi-util-0.1.5
	winapi-x86_64-pc-windows-gnu-0.4.0
	windows-sys-0.45.0
	windows-sys-0.48.0
	windows-targets-0.42.2
	windows-targets-0.48.0
	windows_aarch64_gnullvm-0.42.2
	windows_aarch64_gnullvm-0.48.0
	windows_aarch64_msvc-0.42.2
	windows_aarch64_msvc-0.48.0
	windows_i686_gnu-0.42.2
	windows_i686_gnu-0.48.0
	windows_i686_msvc-0.42.2
	windows_i686_msvc-0.48.0
	windows_x86_64_gnu-0.42.2
	windows_x86_64_gnu-0.48.0
	windows_x86_64_gnullvm-0.42.2
	windows_x86_64_gnullvm-0.48.0
	windows_x86_64_msvc-0.42.2
	windows_x86_64_msvc-0.48.0
	wio-0.2.2
	yeslogic-fontconfig-sys-3.2.0
"

inherit cargo

DESCRIPTION="HDR10+ manipulation software"
HOMEPAGE="https://github.com/quietvoid/hdr10plus_tool"
SRC_URI="
	$(cargo_crate_uris)
	https://github.com/quietvoid/hdr10plus_tool/archive/refs/tags/$PV.tar.gz -> $P.tar.gz
"

LICENSE="Apache-2.0 BSD Boost-1.0 MIT Unlicense"
SLOT="0"
KEYWORDS="~amd64"

PATCHES=( "${FILESDIR}/${PV}-update-deps.patch" )
