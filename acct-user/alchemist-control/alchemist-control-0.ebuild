# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="User for the StormByte Alchemist license server"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( alchemist-control )
ACCT_USER_HOME=/var/lib/alchemist-control
ACCT_USER_HOME_PERMS=0750

acct-user_add_deps
