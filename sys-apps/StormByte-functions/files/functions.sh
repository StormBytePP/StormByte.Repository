#! /bin/bash

function handleCommand() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	echo -n "${2} ... "
	eval $1 > /dev/null 2>&1
	
	if [ $? -eq 0 ]; then
		echo "OK"
	else
		echo "ERROR in command '$1'"
		cd "${current_folder}"
		exit 1
	fi
}

