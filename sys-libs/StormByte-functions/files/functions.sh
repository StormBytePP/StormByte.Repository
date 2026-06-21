# ANSI color codes (ANSI-C quoting for actual escape characters)
readonly _CLR_RESET=$'\033[0m'
readonly _CLR_BOLD=$'\033[1m'
readonly _CLR_DIM=$'\033[2m'
readonly _CLR_RED=$'\033[0;31m'
readonly _CLR_BOLD_RED=$'\033[1;31m'
readonly _CLR_GREEN=$'\033[0;32m'
readonly _CLR_BOLD_GREEN=$'\033[1;32m'
readonly _CLR_YELLOW=$'\033[0;33m'
readonly _CLR_BOLD_YELLOW=$'\033[1;33m'
readonly _CLR_CYAN=$'\033[0;36m'
readonly _CLR_BOLD_CYAN=$'\033[1;36m'
readonly _CLR_WHITE=$'\033[0;37m'
readonly _CLR_BOLD_WHITE=$'\033[1;37m'

function displayError() {
	printf "${_CLR_BOLD_RED}  ✗ ERROR:${_CLR_RESET} %s\n" "$1" >&2
	exit 1
}

function displayWarning() {
	printf "${_CLR_BOLD_YELLOW}  ⚠ WARNING:${_CLR_RESET} %s\n" "$1"
}

function printStep() {
	printf "  ${_CLR_CYAN}▸${_CLR_RESET} %s ... " "$1"
}

function printOK() {
	printf "${_CLR_BOLD_GREEN}[ OK ]${_CLR_RESET}\n"
}

function printFail() {
	printf "${_CLR_BOLD_RED}[ FAIL ]${_CLR_RESET}\n"
}

function printSkip() {
	printf "${_CLR_BOLD_YELLOW}[ SKIP ]${_CLR_RESET}${_CLR_DIM} %s${_CLR_RESET}\n" "$1"
}

function handleCommand() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	printf "  ${_CLR_CYAN}▸${_CLR_RESET} %s ... " "${2}"
	eval $1 > /dev/null 2>&1

	if [ $? -eq 0 ]; then
		printf "${_CLR_BOLD_GREEN}[ OK ]${_CLR_RESET}\n"
	else
		printf "${_CLR_BOLD_RED}[ FAIL ]${_CLR_RESET}\n"
		cd "${current_folder}"
		displayError "in command $1"
	fi
}

function handleCommandWithOutput() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	printf "\n  ${_CLR_BOLD_CYAN}▶${_CLR_RESET} ${_CLR_BOLD_WHITE}%s${_CLR_RESET}\n\n" "${2}"
	eval $1

	if [ $? -ne 0 ]; then
		cd "${current_folder}"
		displayError "in command $1"
	fi
}

function loadConfig() {
	if [ -f "${workdir}/${self}.conf" ]; then
		source "${workdir}/${self}.conf"
	elif [ -f "/etc/conf.d/${self}.conf" ]; then
		source "/etc/conf.d/${self}.conf"
	else
		displayError "Configuration file ${self}.conf not found in current directory or /etc/conf.d!"
	fi
}

function list_contains() { [[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]; }

# Useful variables
workdir="${0%/*}"
self=`basename $0`
parameters=("${@:1}")
current_dir=`pwd`