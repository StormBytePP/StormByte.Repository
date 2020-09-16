#! /bin/bash

# Version 1.0.1

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

# Useful variables
workdir="${0%/*}"
self=`basename $0`
parameters=("${@:1}")
current_dir=`pwd`
