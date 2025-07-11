# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{11..13} )

inherit cmake fcaps linux-info optfeature python-single-r1 systemd

DLIB_VER="19.24.8"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/netdata/${PN}.git"
	inherit git-r3
else
	SRC_URI="
		https://github.com/netdata/${PN}/releases/download/v${PV}/${PN}-v${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/davisking/dlib/archive/v${DLIB_VER}.tar.gz -> dlib-${DLIB_VER}.tar.gz
		https://app.netdata.cloud/agent.tar.gz
		"
	S="${WORKDIR}/${PN}-v${PV}"
	KEYWORDS="~amd64 ~arm64 ~ppc64 ~riscv ~x86"
fi

DESCRIPTION="Linux real time system monitoring, done right!"
HOMEPAGE="https://github.com/netdata/netdata https://my-netdata.io/"

LICENSE="GPL-3+ MIT BSD"
SLOT="0"
IUSE="cups +dbengine ipmi jemalloc lto mold mongodb mysql nfacct nodejs postgres prometheus +python systemd xen"
REQUIRED_USE="
	mysql? ( python )
	python? ( ${PYTHON_REQUIRED_USE} )"

# most unconditional dependencies are for plugins.d/charts.d.plugin:
RDEPEND="
	acct-group/netdata
	acct-user/netdata
	app-alternatives/awk
	app-arch/brotli:=
	app-arch/lz4:=
	app-arch/zstd:=
	app-misc/jq
	>=app-shells/bash-4:0
	dev-libs/json-c:=
	dev-libs/libpcre2:=
	dev-libs/libuv:=
	dev-libs/libyaml
	dev-libs/protobuf:=
	|| (
		net-analyzer/openbsd-netcat
		net-analyzer/netcat
	)
	net-libs/libwebsockets
	net-misc/curl
	net-misc/wget
	sys-apps/util-linux
	sys-libs/libcap
	sys-libs/zlib:=
	cups? ( net-print/cups )
	dbengine? (
		dev-libs/judy
		dev-libs/openssl:=
	)
	ipmi? ( sys-libs/freeipmi )
	jemalloc? ( dev-libs/jemalloc:= )
	mongodb? ( dev-libs/mongo-c-driver )
	nfacct? (
		net-firewall/nfacct
		net-libs/libmnl:=
	)
	nodejs? ( net-libs/nodejs )
	postgres? ( net-analyzer/netdata-go-plugin )
	prometheus? (
		app-arch/snappy:=
	)
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep 'dev-python/pyyaml[${PYTHON_USEDEP}]')
		mysql? ( $(python_gen_cond_dep 'dev-python/mysqlclient[${PYTHON_USEDEP}]') )
	)
	xen? (
		app-emulation/xen-tools
		dev-libs/yajl
	)
	systemd? ( sys-apps/systemd )"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	mold? ( sys-devel/mold )
"

FILECAPS=(
	'cap_dac_read_search,cap_sys_ptrace+ep'
	'usr/libexec/netdata/plugins.d/apps.plugin'
	'usr/libexec/netdata/plugins.d/debugfs.plugin'
)

pkg_setup() {
	use python && python-single-r1_pkg_setup
	linux-info_pkg_setup
}

#PATCHES=(
#	"${FILESDIR}"/${PN}-dlib-global_optimization-add-template-argument-list.patch
#)

src_configure() {
	local mycmakeargs=(
		-DNETDATA_DLIB_SOURCE_PATH="${WORKDIR}/dlib-${DLIB_VER}"
		-DCMAKE_DISABLE_FIND_PACKAGE_Git=ON
		-DCMAKE_INSTALL_PREFIX=/
		-DFETCHCONTENT_FULLY_DISCONNECTED=ON
		-DFETCHCONTENT_UPDATES_DISCONNECTED=ON
		-DENABLE_BUNDLED_JSONC=OFF
		-DENABLE_BUNDLED_PROTOBUF=OFF
		-DENABLE_BUNDLED_YAML=OFF
		-DENABLE_DASHBOARD=OFF # handle manually in install phase
		-DENABLE_DBENGINE=$(usex dbengine)
		-DENABLE_EXPORTER_MONGODB=$(usex mongodb)
		-DENABLE_EXPORTER_PROMETHEUS_REMOTE_WRITE=$(usex prometheus)
		-DENABLE_JEMALLOC=$(usex jemalloc)
		-DENABLE_LIBBACKTRACE=OFF
		-DENABLE_MIMALLOC=OFF
		-DENABLE_ML=ON
		-DENABLE_PLUGIN_APPS=ON
		-DENABLE_PLUGIN_CGROUP_NETWORK=ON
		-DENABLE_PLUGIN_CHARTS=ON
		-DENABLE_PLUGIN_CUPS=$(usex cups)
		-DENABLE_PLUGIN_DEBUGFS=ON
		-DENABLE_PLUGIN_EBPF=OFF # bundles libbpf
		-DENABLE_PLUGIN_GO=OFF
		-DENABLE_PLUGIN_FREEIPMI=$(usex ipmi)
		-DENABLE_PLUGIN_NFACCT=$(usex nfacct)
		-DENABLE_PLUGIN_OTEL=OFF
		-DENABLE_PLUGIN_PERF=ON
		-DENABLE_PLUGIN_PYTHON=$(usex python)
		-DENABLE_PLUGIN_SLABINFO=ON
		-DENABLE_PLUGIN_SYSTEMD_JOURNAL=$(usex systemd)
		-DENABLE_PLUGIN_SYSTEMD_UNITS=$(usex systemd)
		-DENABLE_PLUGIN_XENSTAT=$(usex xen)
		-DUSE_LTO=$(usex lto)
		-DUSE_MOLD=$(usex mold)
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	rm -rf "${D}/var/cache" || die
	rm -rf "${D}/var/run" || die

	keepdir /var/log/netdata
	fowners -Rc netdata:netdata /var/log/netdata
	keepdir /var/lib/netdata
	keepdir /var/lib/netdata/registry
	keepdir /var/lib/netdata/cloud.d
	fowners -Rc netdata:netdata /var/lib/netdata

	insinto /usr/share/netdata/web
	for i in index.html registry-access.html registry-alert-redirect.html registry-hello.html
	do
		doins "${WORKDIR}/dist/agent/${i}"
	done
	doins -r "${WORKDIR}/dist/agent/static"
	doins -r "${WORKDIR}/dist/agent/v3"

	newinitd "${D}/usr/lib/netdata/system/openrc/init.d/netdata" "${PN}"
	newconfd "${D}/usr/lib/netdata/system/openrc/conf.d/netdata" "${PN}"
	systemd_newunit "${D}/usr/lib/netdata/system/systemd/netdata.service.v235" netdata.service
	systemd_dounit "${D}/usr/lib/netdata/system/systemd/netdata-updater.service"
	systemd_dounit "${D}/usr/lib/netdata/system/systemd/netdata-updater.timer"
	insinto /etc/netdata
	doins system/netdata.conf

	# Opt-out anonymous statistics
	touch "${D}/etc/netdata/.opt-out-from-anonymous-statistics"
}

pkg_postinst() {
	fcaps_pkg_postinst

	if use nfacct ; then
		fcaps 'cap_net_admin' 'usr/libexec/netdata/plugins.d/nfacct.plugin'
	fi

	if use xen ; then
		fcaps 'cap_dac_override' 'usr/libexec/netdata/plugins.d/xenstat.plugin'
	fi

	if use ipmi ; then
	    fcaps 'cap_dac_override' 'usr/libexec/netdata/plugins.d/freeipmi.plugin'
	fi

	optfeature "go.d external plugin" net-analyzer/netdata-go-plugin
}
