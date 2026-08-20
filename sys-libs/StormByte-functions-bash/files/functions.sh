#!/usr/bin/env bash
# =============================================================================
# StormByte shared functions library
# =============================================================================
# This file is sourced by multiple StormByte scripts.
# Existing functions must not be modified. Only new generic helpers are added.
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_LOADED=1

# Library version (SEMVER)
readonly STORMBYTE_FUNCTIONS_VERSION="1.1.0"

# -----------------------------------------------------------------------------
# ANSI color codes (ANSI-C quoting for actual escape characters)
# -----------------------------------------------------------------------------
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
readonly _CLR_BLUE=$'\033[0;34m'
readonly _CLR_BOLD_BLUE=$'\033[1;34m'
readonly _CLR_MAGENTA=$'\033[0;35m'
readonly _CLR_BOLD_MAGENTA=$'\033[1;35m'

# -----------------------------------------------------------------------------
# Existing display helpers (DO NOT MODIFY)
# -----------------------------------------------------------------------------

# Display an error message and exit with status 1.
# Usage: displayError "message"
function displayError() {
	printf "  ${_CLR_BOLD_RED}✗  ERROR${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$1" >&2
	exit 1
}

# Display a warning message.
# Usage: displayWarning "message"
function displayWarning() {
	printf "  ${_CLR_BOLD_YELLOW}⚠  WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$1"
}

# Print a step indicator (no newline).
# Usage: printStep "Doing something"
function printStep() {
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET} " "$1"
}

# Print a green OK mark.
function printOK() {
	printf "${_CLR_BOLD_GREEN}✓ OK${_CLR_RESET}\n"
}

# Print a red FAIL mark.
function printFail() {
	printf "${_CLR_BOLD_RED}✗ FAIL${_CLR_RESET}\n"
}

# Print a yellow SKIP mark with optional reason.
# Usage: printSkip "reason"
function printSkip() {
	printf "${_CLR_BOLD_YELLOW}○ SKIP${_CLR_RESET}${_CLR_DIM} %s${_CLR_RESET}\n" "$1"
}

# Execute a command silently and show OK/FAIL.
# $1 = command string, $2 = description
# Usage: handleCommand 'mount ...' "Mounting system..."
function handleCommand() {
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET} " "${2}"
	eval $1 > /dev/null 2>&1

	if [ $? -eq 0 ]; then
		printf "${_CLR_BOLD_GREEN}✓ OK${_CLR_RESET}\n"
	else
		printf "${_CLR_BOLD_RED}✗ FAIL${_CLR_RESET}\n"
		cd "${current_folder}"
		displayError "in command $1"
	fi
}

# Execute a command showing its output.
# $1 = command string, $2 = description
function handleCommandWithOutput() {
	printf "\n  ${_CLR_BOLD_MAGENTA}▶${_CLR_RESET} ${_CLR_BOLD_WHITE}%s${_CLR_RESET}\n\n" "${2}"
	eval $1

	if [ $? -ne 0 ]; then
		cd "${current_folder}"
		displayError "in command $1"
	fi
}

# Load a classic configuration file (source).
# Looks first in the script directory, then in /etc/conf.d/
function loadConfig() {
	if [ -f "${workdir}/${self}.conf" ]; then
		source "${workdir}/${self}.conf"
	elif [ -f "/etc/conf.d/${self}.conf" ]; then
		source "/etc/conf.d/${self}.conf"
	else
		displayError "Configuration file ${self}.conf not found in current directory or /etc/conf.d!"
	fi
}

# Return true if the second argument is present in the space-separated list $1.
# Usage: list_contains "a b c" "b"
function list_contains() {
	[[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]
}

# Useful variables (kept for compatibility with older scripts)
workdir="${0%/*}"
self=`basename $0`
parameters=("${@:1}")
current_dir=`pwd`

# =============================================================================
# NEW GENERIC HELPERS (added in 1.0.0)
# All new functions are documented in English and intended to be reusable.
# =============================================================================

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------

# Print a plain log line.
# Usage: log "message"
log() {
	printf '%s\n' "$*"
}

# Print a success line.
# Usage: ok "message"
ok() {
	printf "  ${_CLR_BOLD_GREEN}✓  OK${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*"
}

# Print a warning line (does not exit).
# Usage: warn "message"
warn() {
	printf "  ${_CLR_BOLD_YELLOW}⚠  WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*"
}

# Print an error line (does not exit).
# Usage: err "message"
err() {
	printf "  ${_CLR_BOLD_RED}✗  ERROR${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*" >&2
}

# Print a section header.
# Usage: section "Title"
section() {
	printf '\n  %s━━ %s ━━%s\n' "${_CLR_BOLD_CYAN}" "$*" "${_CLR_RESET}"
}

# Print a key-value information line.
# Usage: info "Key" "Value"
info() {
	printf "  ${_CLR_DIM}%-14s${_CLR_RESET} %s\n" "$1" "$2"
}

# -----------------------------------------------------------------------------
# Human-readable size
# -----------------------------------------------------------------------------

# Convert a number of bytes into a human-readable string (B, KiB, MiB, GiB).
# Usage: human_size 1234567
human_size() {
	local b="${1:-0}"
	[[ "$b" =~ ^[0-9]+$ ]] || b=0

	if [[ "$b" -lt 1024 ]]; then
		printf '%s B' "$b"
	elif [[ "$b" -lt $((1024 * 1024)) ]]; then
		printf '%s KiB' "$(( (b + 512) / 1024 ))"
	elif [[ "$b" -lt $((1024 * 1024 * 1024)) ]]; then
		printf '%s MiB' "$(awk -v b="$b" 'BEGIN { printf "%.1f", b / (1024*1024) }')"
	else
		printf '%s GiB' "$(awk -v b="$b" 'BEGIN { printf "%.2f", b / (1024*1024*1024) }')"
	fi
}

# -----------------------------------------------------------------------------
# Safe configuration loader (KEY=VALUE only – never executes code)
# -----------------------------------------------------------------------------

# Load only simple KEY=VALUE pairs from a file.
# Comments and blank lines are ignored. No code is executed.
# Usage: load_safe_config "/path/to/file.conf" VAR1 VAR2 ...
load_safe_config() {
	local conf="$1"
	shift
	local allowed=("$@")
	local line key value allowed_key

	[[ -f "$conf" ]] || return 0

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and empty lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// }" ]] && continue

		if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"
			# Strip optional surrounding quotes
			value="${value#\"}" ; value="${value%\"}"
			value="${value#\'}" ; value="${value%\'}"

			for allowed_key in "${allowed[@]}"; do
				if [[ "$key" == "$allowed_key" ]]; then
					printf -v "$key" '%s' "$value"
					break
				fi
			done
		fi
	done < "$conf"
}

# -----------------------------------------------------------------------------
# Selection / exclusion parsing
# -----------------------------------------------------------------------------

# Parse a selection specification into two global arrays:
#   INCLUDE_ITEMS  – explicit includes
#   EXCLUDE_ITEMS  – exclusions
#
# Supported forms:
#   "item"                  → include only that item
#   "!item"                 → exclude that item
#   "!item1+!item2+!item3"  → exclude multiple items
#
# Usage: parse_selection_spec "spec"
parse_selection_spec() {
	local spec="${1:-}"
	INCLUDE_ITEMS=()
	EXCLUDE_ITEMS=()

	[[ -z "$spec" ]] && return 0

	# Multiple exclusions joined by +
	if [[ "$spec" == *'+'* && "$spec" == '!'* ]]; then
		local part
		local -a parts
		IFS='+' read -ra parts <<< "$spec"
		for part in "${parts[@]}"; do
			part="${part#"${part%%[![:space:]]*}"}"
			part="${part%"${part##*[![:space:]]}"}"
			if [[ "$part" == '!'* ]]; then
				EXCLUDE_ITEMS+=("${part#!}")
			else
				INCLUDE_ITEMS+=("$part")
			fi
		done
		return 0
	fi

	if [[ "$spec" == '!'* ]]; then
		EXCLUDE_ITEMS+=("${spec#!}")
	else
		INCLUDE_ITEMS+=("$spec")
	fi
}

# Return 0 if the given item should be processed according to
# the current INCLUDE_ITEMS / EXCLUDE_ITEMS arrays.
# Usage: should_process_item "name" && do_something
should_process_item() {
	local name="$1"
	local n

	# Explicit include list has priority
	if [[ ${#INCLUDE_ITEMS[@]} -gt 0 ]]; then
		for n in "${INCLUDE_ITEMS[@]}"; do
			[[ "${name,,}" == "${n,,}" ]] && return 0
		done
		return 1
	fi

	# Exclusion list
	if [[ ${#EXCLUDE_ITEMS[@]} -gt 0 ]]; then
		for n in "${EXCLUDE_ITEMS[@]}"; do
			[[ "${name,,}" == "${n,,}" ]] && return 1
		done
	fi

	return 0
}

# -----------------------------------------------------------------------------
# Directory helpers
# -----------------------------------------------------------------------------

# Ensure a directory exists. Creates it if necessary.
# Calls displayError and exits on failure.
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
	local dir="$1"
	if [[ ! -d "$dir" ]]; then
		if ! mkdir -p "$dir" 2>/dev/null; then
			displayError "Cannot create directory: $dir"
		fi
	fi
}

# -----------------------------------------------------------------------------
# Generic topological sort (Kahn’s algorithm)
# -----------------------------------------------------------------------------

# Perform a topological sort using Kahn’s algorithm.
#
# Parameters (passed by name):
#   $1 – name of an array containing all node identifiers
#   $2 – name of an associative array where deps[node]="dep1 dep2 ..."
#
# Prints the ordered list of nodes (one per line) to stdout.
# If a cycle is detected a warning is emitted and remaining nodes
# are appended at the end.
#
# Usage example:
#   nodes=(a b c)
#   declare -A deps=([a]="b" [b]="c")
#   topological_sort nodes deps
topological_sort() {
	local nodes_name="$1"
	local deps_name="$2"

	local -n nodes_ref="$nodes_name"
	local -n deps_ref="$deps_name"

	local -A indeg=()
	local -A children=()
	local -a zero=() queue=() result=()
	local n d cur child seen

	# Initialise indegree
	for n in "${nodes_ref[@]}"; do
		indeg["$n"]=0
	done

	# Build reverse edges and indegrees
	for n in "${nodes_ref[@]}"; do
		for d in ${deps_ref[$n]:-}; do
			[[ -z "$d" ]] && continue
			children["$d"]="${children[$d]:+${children[$d]} }$n"
			indeg["$n"]=$(( ${indeg[$n]:-0} + 1 ))
		done
	done

	# Nodes with indegree 0
	for n in "${nodes_ref[@]}"; do
		if [[ ${indeg[$n]:-0} -eq 0 ]]; then
			zero+=("$n")
		fi
	done

	queue=("${zero[@]}")

	while [[ ${#queue[@]} -gt 0 ]]; do
		cur="${queue[0]}"
		queue=("${queue[@]:1}")
		result+=("$cur")

		for child in ${children[$cur]:-}; do
			[[ -z "$child" ]] && continue
			indeg["$child"]=$(( ${indeg[$child]:-0} - 1 ))
			if [[ ${indeg[$child]:-0} -eq 0 ]]; then
				queue+=("$child")
			fi
		done
	done

	# Cycle detection: append remaining nodes
	if [[ ${#result[@]} -lt ${#nodes_ref[@]} ]]; then
		warn "Dependency cycle detected — appending remaining nodes"
		for n in "${nodes_ref[@]}"; do
			seen=0
			for cur in "${result[@]}"; do
				[[ "$cur" == "$n" ]] && { seen=1; break; }
			done
			[[ $seen -eq 0 ]] && result+=("$n")
		done
	fi

	printf '%s\n' "${result[@]}"
}

# -----------------------------------------------------------------------------
# SEMVER helpers
# -----------------------------------------------------------------------------

# Compare two SEMVER strings.
# Returns:
#   -1 if $1 < $2
#    0 if $1 == $2
#    1 if $1 > $2
# Usage: semver_compare "1.2.3" "1.3.0"
semver_compare() {
	local a="$1" b="$2"
	local -a pa pb
	local i

	# Ignore pre-release / build metadata for the basic comparison
	IFS='.' read -ra pa <<< "${a%%-*}"
	IFS='.' read -ra pb <<< "${b%%-*}"

	# Pad with zeros
	while [[ ${#pa[@]} -lt 3 ]]; do pa+=("0"); done
	while [[ ${#pb[@]} -lt 3 ]]; do pb+=("0"); done

	for i in 0 1 2; do
		local na="${pa[$i]//[^0-9]/}"
		local nb="${pb[$i]//[^0-9]/}"
		na=$((10#${na:-0}))
		nb=$((10#${nb:-0}))
		if (( na < nb )); then
			echo -1
			return
		elif (( na > nb )); then
			echo 1
			return
		fi
	done
	echo 0
}

# Return true (exit 0) if $1 >= $2
semver_ge() {
	[[ "$(semver_compare "$1" "$2")" -ge 0 ]]
}

# Return true (exit 0) if $1 > $2
semver_gt() {
	[[ "$(semver_compare "$1" "$2")" -gt 0 ]]
}

# Return true (exit 0) if $1 <= $2
semver_le() {
	[[ "$(semver_compare "$1" "$2")" -le 0 ]]
}

# Return true (exit 0) if $1 < $2
semver_lt() {
	[[ "$(semver_compare "$1" "$2")" -lt 0 ]]
}

# Return true (exit 0) if $1 == $2
semver_eq() {
	[[ "$(semver_compare "$1" "$2")" -eq 0 ]]
}

# Require that a version meets a minimum requirement.
# Calls displayError and exits if the requirement is not satisfied.
# Usage: require_version "$HAVE" "$NEED" "Component name"
require_version() {
	local have="$1"
	local need="$2"
	local name="${3:-component}"

	if ! semver_ge "$have" "$need"; then
		displayError "$name version $have is too old (requires >= $need)"
	fi
}

# -----------------------------------------------------------------------------
# Version string helpers (1.1.0)
# -----------------------------------------------------------------------------

# Strip optional leading "v" (v1.0.0 → 1.0.0).
# Usage: version_plain "v1.2.3"
version_plain() {
	local v="${1:-}"
	printf '%s\n' "${v#v}"
}

# Return 0 if string looks like SEMVER core + optional pre-release/build
# (optional leading v). Examples: 1.0.0, v1.0.0, 1.0.0-rc.1, 1.0.0+build
# Usage: version_is_valid "1.0.0-rc.1"
version_is_valid() {
	local v
	v="$(version_plain "${1:-}")"
	[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.-]*)?$ ]]
}

# Return 0 if version has a pre-release segment (contains '-' in the plain form).
# Usage: version_is_prerelease "1.0.0-rc.1"
version_is_prerelease() {
	local v
	v="$(version_plain "${1:-}")"
	[[ "$v" == *-* ]]
}
