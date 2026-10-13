# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit stormbyte-suite

DESCRIPTION="StormByte Multimedia module"
HOMEPAGE="https://suite.stormbyte.org/StormByte-Multimedia"

LICENSE="LGPL-3"
IUSE+=" +gpl +nonfree"

# Buffer public-links Logger and System; the core library is linked by all
# of them. FFmpeg 9.0.2 is the minimum upstream accepts for WITH_FFMPEG=SYSTEM.
# gpl/nonfree follow the bundled plugin gates: x264, x265 and rubberband are
# WITH_GPL; fdk-aac is WITH_NONFREE. The rest are always built.
DEPEND="
	$(stormbyte-suite_dep dev-libs/StormByte)
	$(stormbyte-suite_dep dev-libs/StormByte-Buffer)
	$(stormbyte-suite_dep dev-libs/StormByte-Logger)
	$(stormbyte-suite_dep dev-libs/StormByte-System)
	app-text/tesseract:=
	media-libs/libebur128:=
	media-libs/libvmaf:=
	media-libs/zimg:=
	>=media-video/ffmpeg-9.0.2:0=[bzip2,dav1d,kvazaar,lame,libaom,libass,openh264,opus,rav1e,srt,svt-av1,vorbis,vpx,webp]
	gpl? ( >=media-video/ffmpeg-9.0.2:0=[gpl,rubberband,x264,x265] )
	nonfree? ( >=media-video/ffmpeg-9.0.2:0=[fdk] )
	|| (
		app-text/tessdata_fast:=[l10n_ar,l10n_be,l10n_bg,l10n_bn,l10n_bs,l10n_ca,l10n_cs,l10n_cy,l10n_da,l10n_de,l10n_el,l10n_es,l10n_et,l10n_eu,l10n_fa,l10n_fi,l10n_fil,l10n_fr,l10n_ga,l10n_gl,l10n_he,l10n_hi,l10n_hr,l10n_hu,l10n_id,l10n_is,l10n_it,l10n_ja,l10n_ko,l10n_lt,l10n_lv,l10n_mk,l10n_ms,l10n_mt,l10n_nl,l10n_no,l10n_pl,l10n_pt,l10n_ro,l10n_ru,l10n_sk,l10n_sl,l10n_sq,l10n_sr,l10n_sv,l10n_ta,l10n_te,l10n_th,l10n_tr,l10n_uk,l10n_vi,l10n_zh]
		app-text/tessdata_best:=[l10n_ar,l10n_be,l10n_bg,l10n_bn,l10n_bs,l10n_ca,l10n_cs,l10n_cy,l10n_da,l10n_de,l10n_el,l10n_es,l10n_et,l10n_eu,l10n_fa,l10n_fi,l10n_fil,l10n_fr,l10n_ga,l10n_gl,l10n_he,l10n_hi,l10n_hr,l10n_hu,l10n_id,l10n_is,l10n_it,l10n_ja,l10n_ko,l10n_lt,l10n_lv,l10n_mk,l10n_ms,l10n_mt,l10n_nl,l10n_no,l10n_pl,l10n_pt,l10n_ro,l10n_ru,l10n_sk,l10n_sl,l10n_sq,l10n_sr,l10n_sv,l10n_ta,l10n_te,l10n_th,l10n_tr,l10n_uk,l10n_vi,l10n_zh]
	)
"
RDEPEND="${DEPEND}"

src_prepare() {
	# VAAPI/QSV tests open /dev/dri/renderD* read-write and then pass or skip.
	# A sandbox denial aborts the build instead of returning an error the
	# test can handle. PGO runs ctest from src_compile, so this has to be
	# in place before that phase.
	addwrite /dev/dri
	stormbyte-suite_src_prepare
}

stormbyte-suite_cmake_args() {
	STORMBYTE_CMAKEARGS=(
		-DWITH_EBUR128=SYSTEM
		-DWITH_FFMPEG=SYSTEM
		-DWITH_GPL=$(usex gpl ON OFF)
		-DWITH_NONFREE=$(usex nonfree ON OFF)
		-DWITH_OCR=SYSTEM
		-DWITH_STORMBYTE=SYSTEM
		-DWITH_TESSDATA=SYSTEM
		-DWITH_VMAF=SYSTEM
		-DWITH_ZIMG=SYSTEM
	)
}
