# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{8,9} )
PYTHON_REQ_USE="sqlite"
inherit desktop python-single-r1 qmake-utils xdg

DESCRIPTION="GUI administration and development platform for PostgreSQL"
HOMEPAGE="https://www.pgadmin.org/"
SRC_URI="https://ftp.postgresql.org/pub/pgadmin/${PN}/v${PV}/source/${P}.tar.gz"

LICENSE="POSTGRESQL"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RESTRICT="test"

# libsodium dep added because of 689678
COMMON_DEPEND="${PYTHON_DEPS}
	dev-libs/libsodium[-minimal]
	dev-qt/qtcore:5
	dev-qt/qtgui:5
	dev-qt/qtnetwork:5[ssl]
	dev-qt/qtwidgets:5
"
DEPEND="${COMMON_DEPEND}
	doc? (
		$(python_gen_cond_dep '
			dev-python/sphinx[${PYTHON_USEDEP}]
		')
	)
	virtual/imagemagick-tools[png]
"

BDEPEND="sys-apps/yarn"

# In 4.25's requirement.txt, bcrypt is listed as <=3.17, but upstream's
# git history shows this is just for compatibility with <python-3.6.
# In 4.26's requirement.txt, cryptography is listed as <=3.0, but upstream's
# git history shows this is just for compatibility with Windows.
# 4.28; requirement.txt: Flask-Security was renamed to
# Flask-Security-Too. This is still the same dev-python/flask-security.
#
# 5.6; requirements.txt: pytz up to 2021, itsdangerous still <=1.10,
#   flask-security-too 4.x, eventlet 0.31 seems new,
#   httpagentparser 1.9 like socketio, - added
#   user-agents (do not confuse with user_agent)
#   authlib?  requests 2.25? (have it)
#  switched flask from <2 to >=2 (don't know if <2 is still OK or not)
# other new depends flask-socketio, python-socketio (added below)
# is flask-socketio>=5.0.1 new? do we have it?
#    bidict
# authlib
#
# 5.7;

RDEPEND="${COMMON_DEPEND}
	$(python_gen_cond_dep '
		>=dev-python/Authlib-0.15.4[${PYTHON_USEDEP}]
		=dev-python/bcrypt-3*[${PYTHON_USEDEP}]
		>=dev-python/bidict-0.21.2[${PYTHON_USEDEP}]
		>=dev-python/blinker-1.4[${PYTHON_USEDEP}]
		=dev-python/cryptography-3*[${PYTHON_USEDEP}]
		>=dev-python/eventlet-0.31.0[${PYTHON_USEDEP}]
		<dev-python/flask-2.0.0[${PYTHON_USEDEP}]
		>=dev-python/flask-babelex-0.9.4[${PYTHON_USEDEP}]
		>=dev-python/flask-compress-1.4.0[${PYTHON_USEDEP}]
		>=dev-python/flask-gravatar-0.5.0[${PYTHON_USEDEP}]
		>=dev-python/flask-login-0.4.1[${PYTHON_USEDEP}]
		>=dev-python/flask-mail-0.9.1[${PYTHON_USEDEP}]
		>=dev-python/flask-migrate-2.4.0[${PYTHON_USEDEP}]
		>=dev-python/flask-paranoid-0.2.0[${PYTHON_USEDEP}]
		>=dev-python/flask-principal-0.4.0[${PYTHON_USEDEP}]
		>=dev-python/flask-security-4.0.0[${PYTHON_USEDEP}]
		>=dev-python/flask-socketio-5.0.1[${PYTHON_USEDEP}]
		>=dev-python/flask-sqlalchemy-2.4.1[${PYTHON_USEDEP}]
		>=dev-python/flask-wtf-0.14.3[${PYTHON_USEDEP}]
		=dev-python/gssapi-1.6*[${PYTHON_USEDEP}]
		>=dev-python/httpagentparser-1.9.1[${PYTHON_USEDEP}]
		<=dev-python/itsdangerous-1.1.1[${PYTHON_USEDEP}]
		>=dev-python/ldap3-2.5.1[${PYTHON_USEDEP}]
		>=dev-python/passlib-1.7.2[${PYTHON_USEDEP}]
		>=dev-python/psutil-5.7.0[${PYTHON_USEDEP}]
		>=dev-python/psycopg-2.8[${PYTHON_USEDEP}]
		>=dev-python/python-dateutil-2.8.0[${PYTHON_USEDEP}]
		>=dev-python/python-socketio-5.4.0[${PYTHON_USEDEP}]
		>=dev-python/pytz-2021.0[${PYTHON_USEDEP}]
		>=dev-python/requests-2.25[${PYTHON_USEDEP}]
		>=dev-python/simplejson-3.16.0[${PYTHON_USEDEP}]
		>=dev-python/six-1.12.0[${PYTHON_USEDEP}]
		>=dev-python/speaklater-1.3[${PYTHON_USEDEP}]
		>=dev-python/sqlalchemy-1.3.13[${PYTHON_USEDEP}]
		>=dev-python/sqlparse-0.3.0[${PYTHON_USEDEP}]
		>=dev-python/sshtunnel-0.1.5[${PYTHON_USEDEP}]
		>=dev-python/ua-parser-0.10.0[${PYTHON_USEDEP}]
		>=dev-python/user-agents-2.2.0[${PYTHON_USEDEP}]
		>=dev-python/werkzeug-0.15.0[${PYTHON_USEDEP}]
		>=dev-python/wtforms-2.2.1[${PYTHON_USEDEP}]
		dev-python/python-email-validator[${PYTHON_USEDEP}]
	')
"

S="${WORKDIR}"/${P}/runtime

src_prepare() {
	cd "${WORKDIR}"/${P} || die
	default
}

src_configure() {
	export PGADMIN_PYTHON_DIR="${EPREFIX}/usr"
#	eqmake5project
# do we need default?
}

src_compile() {
	default
	use doc && emake -C "${WORKDIR}"/${P} docs
	cd ${WORKDIR}/${P}/runtime
	yarn install
}

src_install() {
#	dobin pgAdmin4

	cd "${WORKDIR}"/${P} || die


	local APP_DIR=/usr/share/${PN}/runtime
	insinto "${APP_DIR}"
	doins -r runtime/.
	newins - dev_config.json <<-EOF
	{
		"pythonPath": "/usr/bin/python",
		"pgadminFile": "/usr/share/pgadmin4/web/pgAdmin4.py"
	}
	EOF
	python_optimize "${D}${APP_DIR}"
# wildcards can fail below if the folders don't exist on the actual system
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/crashpad_handler
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/nw
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/lib/libEGL.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/lib/libffmpeg.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/lib/libGLESv2.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/lib/libnode.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/lib/libnw.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/swiftshader/libEGL.so
	fperms 0755 /usr/share/pgadmin4/runtime/node_modules/nw/nwjs/swiftshader/libGLESv2.so
	# probably also want to strip all of these (some are but not most?)

	local APP_DIR=/usr/share/${PN}/web
	insinto "${APP_DIR}"
	doins -r web/.
	newins - config_local.py <<-EOF
		SERVER_MODE = False
		UPGRADE_CHECK_ENABLED = False
	EOF
	python_optimize "${D}${APP_DIR}"

	insinto /etc/xdg/pgadmin
	newins - pgadmin4.conf <<-EOF
		[General]
		ApplicationPath=${APP_DIR}
		PythonPath=$(python_get_sitedir)
	EOF

	insinto /usr/bin
	newins - pgAdmin4 <<-EOF
	#/bin/bash
	cd /usr/share/pgadmin4/runtime
	node_modules/nw/nwjs/nw .
	EOF
	fperms 0755 /usr/bin/pgAdmin4

	if use doc; then
		rm -r docs/en_US/_build/html/_sources || die
		insinto /usr/share/${PN}/docs/en_US/_build
		doins -r docs/en_US/_build/html
	fi

	local s
	for s in 16 32 48 64 72 96 128 192 256; do
		convert runtime/assets/pgAdmin4.png -resize ${s}x${s} ${PN}_${s}.png || die
		newicon -s ${s} ${PN}_${s}.png ${PN}.png
	done
	domenu "${FILESDIR}"/${PN}.desktop
}
