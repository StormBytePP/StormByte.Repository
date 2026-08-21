#!/usr/bin/env bash
# =============================================================================
# StormByte shared functions library
# =============================================================================
# This file is sourced by multiple StormByte scripts.
# Existing public helpers are kept for compatibility. Output helpers used by
# StageManager (handleCommand*) were tightened in 1.2.0 for a single UI style.
# 1.3.0 adds version tuples, Keep-a-Changelog extraction, TTY prompts,
# path normalisation and required-command checks — used by git helpers and
# any other StormByte CLI.
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_LOADED=1

# Library version (SEMVER)
readonly STORMBYTE_FUNCTIONS_VERSION="1.3.0"

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
# Display helpers
# -----------------------------------------------------------------------------

# Display an error message and exit with status 1.
# Usage: displayError "message"
function displayError() {
	printf "  ${_CLR_BOLD_RED}ERROR${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$1" >&2
	exit 1
}

# Display a warning message.
# Usage: displayWarning "message"
function displayWarning() {
	printf "  ${_CLR_BOLD_YELLOW}WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$1"
}

# Print a step indicator (no newline) — same prefix as handleCommand.
# Usage: printStep "Doing something"
function printStep() {
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET} " "$1"
}

# Print a green OK mark (continues a printStep / handleCommand line, or alone).
function printOK() {
	printf "${_CLR_BOLD_GREEN}OK${_CLR_RESET}\n"
}

# Print a red FAIL mark.
function printFail() {
	printf "${_CLR_BOLD_RED}FAIL${_CLR_RESET}\n"
}

# Print a yellow SKIP mark with optional reason.
# Usage: printSkip "reason"
function printSkip() {
	printf "${_CLR_BOLD_YELLOW}SKIP${_CLR_RESET}${_CLR_DIM} %s${_CLR_RESET}\n" "$1"
}

# Execute a command silently and show OK/FAIL on the same line.
# $1 = command string, $2 = description
# Usage: handleCommand 'mount ...' "Mounting system"
function handleCommand() {
	local cmd="$1"
	local desc="$2"
	local rc=0
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET} " "${desc}"
	eval "${cmd}" > /dev/null 2>&1 || rc=$?
	if [[ "${rc}" -eq 0 ]]; then
		printf "${_CLR_BOLD_GREEN}OK${_CLR_RESET}\n"
	else
		printf "${_CLR_BOLD_RED}FAIL${_CLR_RESET}\n"
		cd "${current_folder}" 2>/dev/null || true
		displayError "in command ${cmd}"
	fi
}

# Execute a command showing its output (progress bars, etc.).
# Layout (unified with handleCommand):
#   ◆ Description …
#   <command stdout/stderr>
#   OK
# $1 = command string, $2 = description
# Usage: handleCommandWithOutput 'pv file | tar …' "Extracting …"
function handleCommandWithOutput() {
	local cmd="$1"
	local desc="$2"
	local rc=0
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET}\n" "${desc}"
	eval "${cmd}" || rc=$?
	if [[ "${rc}" -eq 0 ]]; then
		printf "  ${_CLR_BOLD_GREEN}OK${_CLR_RESET}\n"
	else
		printf "  ${_CLR_BOLD_RED}FAIL${_CLR_RESET}\n"
		cd "${current_folder}" 2>/dev/null || true
		displayError "in command ${cmd}"
	fi
}

# Soft variant: same layout as handleCommandWithOutput but does not exit on failure.
# Returns the command exit status. Prints FAIL + optional warn via caller.
# Usage: handleCommandWithOutputSoft '…' "Packing …" || warn "pack failed"
function handleCommandWithOutputSoft() {
	local cmd="$1"
	local desc="$2"
	local rc=0
	printf "  ${_CLR_BOLD_CYAN}◆${_CLR_RESET} ${_CLR_WHITE}%s${_CLR_RESET} ${_CLR_DIM}…${_CLR_RESET}\n" "${desc}"
	eval "${cmd}" || rc=$?
	if [[ "${rc}" -eq 0 ]]; then
		printf "  ${_CLR_BOLD_GREEN}OK${_CLR_RESET}\n"
	else
		printf "  ${_CLR_BOLD_RED}FAIL${_CLR_RESET}\n"
	fi
	return "${rc}"
}

# Load a classic configuration file (source).
# Looks first in the script directory, then in /etc/conf.d/
# Relies on workdir / self set below (or by the caller).
function loadConfig() {
	if [ -f "${workdir}/${self}.conf" ]; then
		# shellcheck source=/dev/null
		source "${workdir}/${self}.conf"
	elif [ -f "/etc/conf.d/${self}.conf" ]; then
		# shellcheck source=/dev/null
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
self="$(basename "$0")"
parameters=("${@:1}")
current_dir="$(pwd)"
# Alias used by older StageManager paths
current_folder="${current_folder:-${current_dir}}"

# =============================================================================
# NEW GENERIC HELPERS (1.0.0+)
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
	printf "  ${_CLR_BOLD_GREEN}OK${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*"
}

# Print a warning line (does not exit).
# Usage: warn "message"
warn() {
	printf "  ${_CLR_BOLD_YELLOW}WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*"
}

# Print an error line (does not exit).
# Usage: err "message"
err() {
	printf "  ${_CLR_BOLD_RED}ERROR${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} %s\n" "$*" >&2
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
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// }" ]] && continue

		if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"
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

	if [[ ${#INCLUDE_ITEMS[@]} -gt 0 ]]; then
		for n in "${INCLUDE_ITEMS[@]}"; do
			[[ "${name,,}" == "${n,,}" ]] && return 0
		done
		return 1
	fi

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

	for n in "${nodes_ref[@]}"; do
		indeg["$n"]=0
	done

	for n in "${nodes_ref[@]}"; do
		for d in ${deps_ref[$n]:-}; do
			[[ -z "$d" ]] && continue
			children["$d"]="${children[$d]:+${children[$d]} }$n"
			indeg["$n"]=$(( ${indeg[$n]:-0} + 1 ))
		done
	done

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
# Numeric compare of the X.Y.Z core only. A pre-release suffix (-rc.1) is
# stripped before comparison, so 1.0.0-rc.1 and 1.0.0 compare equal here.
# Use version_is_prerelease if you need to distinguish them.

# Compare two SEMVER strings.
# Prints:
#   -1 if $1 < $2
#    0 if $1 == $2
#    1 if $1 > $2
# Usage: semver_compare "1.2.3" "1.3.0"
semver_compare() {
	local a="$1" b="$2"
	local -a pa pb
	local i

	IFS='.' read -ra pa <<< "${a%%-*}"
	IFS='.' read -ra pb <<< "${b%%-*}"

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

# Return 0 if $1 >= $2 (core SEMVER only; see semver_compare).
semver_ge() {
	[[ "$(semver_compare "$1" "$2")" -ge 0 ]]
}

# Return 0 if $1 > $2 (core SEMVER only).
semver_gt() {
	[[ "$(semver_compare "$1" "$2")" -gt 0 ]]
}

# Return 0 if $1 <= $2 (core SEMVER only).
semver_le() {
	[[ "$(semver_compare "$1" "$2")" -le 0 ]]
}

# Return 0 if $1 < $2 (core SEMVER only).
semver_lt() {
	[[ "$(semver_compare "$1" "$2")" -lt 0 ]]
}

# Return 0 if $1 == $2 (core SEMVER only).
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

# =============================================================================
# ADDITIONS (1.3.0)
# =============================================================================

# -----------------------------------------------------------------------------
# Strings / TTY / paths
# -----------------------------------------------------------------------------

# Return 0 if file descriptor 0 is a terminal.
# Usage: is_tty && echo interactive
is_tty() {
	[[ -t 0 ]]
}

# Strip leading and trailing ASCII whitespace.
# Usage: trim "  foo  "   → stdout: foo
trim() {
	local s="${1-}"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

# Expand a leading ~ or ~/ to $HOME. Does not resolve the path.
# Usage: path_expand_tilde "~/src"
path_expand_tilde() {
	local p
	p="$(trim "${1-}")"
	case "$p" in
		"~")   p="$HOME" ;;
		"~/"*) p="$HOME/${p:2}" ;;
	esac
	printf '%s\n' "$p"
}

# Expand tilde, drop a trailing slash (except "/"), optionally require existence.
# Usage: path_normalize "~/src/"
#        path_normalize "/tmp/out" --must-exist
path_normalize() {
	local p must=0
	p="$(path_expand_tilde "${1-}")"
	shift || true
	[[ "${1-}" == "--must-exist" ]] && must=1
	while [[ "$p" == */ && "$p" != / ]]; do
		p="${p%/}"
	done
	if [[ "$must" -eq 1 && ! -e "$p" ]]; then
		return 1
	fi
	printf '%s\n' "$p"
}

# Exit via displayError unless every name is an executable on PATH.
# Usage: require_cmd git jq gh
require_cmd() {
	local c
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || displayError "Required command not found: $c"
	done
}

# -----------------------------------------------------------------------------
# Version tuples (generic — tags, packages, pins)
# -----------------------------------------------------------------------------
# Turn "16.4", "v1.2.3-rc.1" or "8.9.0" into three integers. Missing
# components become 0. Pre-release / build suffixes are dropped.
# This is the numeric engine; prefix stripping (REL_, CRYPTOPP_) stays in git.sh.

# Print "major minor patch" for any dotted numeric version (1–3 components).
# Usage: version_components "16.4"     → 16 4 0
#        version_components "v1.2.3-rc.1" → 1 2 3
version_components() {
	local v core
	local -a p
	v="$(version_plain "${1-}")"
	core="${v%%-*}"
	core="${core%%+*}"
	IFS='.' read -ra p <<< "$core"
	printf '%s %s %s\n' \
		"${p[0]:-0}" "${p[1]:-0}" "${p[2]:-0}"
}

# Pad a dotted version to X.Y.Z (no leading v, no suffix).
# Usage: version_pad "16.4" → 16.4.0
version_pad() {
	local a b c
	read -r a b c < <(version_components "$1")
	printf '%s.%s.%s\n' "$a" "$b" "$c"
}

# Compare two space-separated integer tuples of any length (missing = 0).
# Return: 0 if A < B, 1 if A == B, 2 if A > B.
# Usage: int_tuple_cmp "16 4 0" "16 5" ; echo $?
int_tuple_cmp() {
	local -a a=($1) b=($2)
	local i n av bv
	n=${#a[@]}
	(( ${#b[@]} > n )) && n=${#b[@]}
	for ((i = 0; i < n; i++)); do
		av="${a[i]:-0}"
		bv="${b[i]:-0}"
		[[ "$av" =~ ^[0-9]+$ ]] || av=0
		[[ "$bv" =~ ^[0-9]+$ ]] || bv=0
		if ((10#$av < 10#$bv)); then
			return 0
		fi
		if ((10#$av > 10#$bv)); then
			return 2
		fi
	done
	return 1
}

# Convenience wrappers around int_tuple_cmp (0 = true).
int_tuple_lt() { int_tuple_cmp "$1" "$2"; [[ $? -eq 0 ]]; }
int_tuple_eq() { int_tuple_cmp "$1" "$2"; [[ $? -eq 1 ]]; }
int_tuple_gt() { int_tuple_cmp "$1" "$2"; [[ $? -eq 2 ]]; }

# -----------------------------------------------------------------------------
# Keep a Changelog
# -----------------------------------------------------------------------------

# Extract the body of a Keep-a-Changelog section.
# Looks for a heading:
#   ## [1.0.0] - YYYY-MM-DD
#   ## [v1.0.0] - YYYY-MM-DD
# Matching uses version_plain so "v1.0.0" and "1.0.0" are the same.
# Prints the section body (no header). Returns 1 if missing or empty.
# Usage: changelog_extract_notes "/path/CHANGELOG.md" "1.0.0"
changelog_extract_notes() {
	local changelog="$1"
	local version="$2"
	local ver body tmp rc

	ver="$(version_plain "$version")"
	[[ -f "$changelog" ]] || return 1

	tmp="$(mktemp)"
	awk -v ver="$ver" '
		BEGIN { want = 0; found = 0 }
		/^##[ \t]+\[/ {
			if (want == 1) exit
			line = $0
			if (match(line, /^##[ \t]+\[v?([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z._-]*)\][ \t]*-[ \t]*[0-9]{4}-[0-9]{2}-[0-9]{2}/, m)) {
				if (m[1] == ver) { want = 1; found = 1; next }
			}
			next
		}
		/^##[ \t]+/ {
			if (want == 1) exit
			next
		}
		want == 1 { print }
		END { exit(found ? 0 : 1) }
	' "$changelog" > "$tmp"
	rc=$?
	if [[ "$rc" -ne 0 ]]; then
		rm -f "$tmp"
		return 1
	fi
	body="$(sed -e '/./,$!d' "$tmp" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
	rm -f "$tmp"
	[[ -n "${body//[:space:]/}" ]] || return 1
	printf '%s\n' "$body"
}

# -----------------------------------------------------------------------------
# Prompts / tables
# -----------------------------------------------------------------------------

# Ask a yes/no question. Default is NO.
# Returns 0 for y/yes (any case). Empty, n, anything else → 1.
# Non-TTY or CONFIRM=1 / SM_CONFIRM=1 → 0 without reading (callers that
# want "skip prompts" pass that). Non-TTY without CONFIRM → 1.
# Usage: confirm_yes "Apply this plan?" || return 0
confirm_yes() {
	local prompt="${1:-Proceed?}"
	local reply=""

	if [[ "${CONFIRM:-0}" == "1" || "${SM_CONFIRM:-0}" == "1" ]]; then
		return 0
	fi
	if ! is_tty; then
		return 1
	fi
	printf "  %s [y/N] " "$prompt"
	read -r reply || reply=""
	[[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# Read a single line from the TTY. Empty / EOF / non-TTY → return 1.
# Usage: reply="$(prompt_line "Enter ref (empty = skip)")" || return 1
prompt_line() {
	local prompt="${1:-}"
	local reply=""
	is_tty || return 1
	[[ -n "$prompt" ]] && printf "  %s " "$prompt"
	read -r reply || return 1
	[[ -n "$reply" ]] || return 1
	printf '%s\n' "$reply"
}

# Print an aligned three-column row (used for MODULE / CURRENT / PLANNED).
# First call with --header prints a dim header line.
# Usage: print_columns --header MODULE CURRENT PLANNED
#        print_columns "StormByte" "1.2.3 (abc)" "1.2.4"
print_columns() {
	local w1=36 w2=22
	if [[ "${1-}" == "--header" ]]; then
		shift
		printf "  ${_CLR_DIM}%-${w1}s  %-${w2}s  %s${_CLR_RESET}\n" "${1-}" "${2-}" "${3-}"
		return 0
	fi
	printf "  %-${w1}s  %-${w2}s  %s\n" "${1-}" "${2-}" "${3-}"
}


# =============================================================================
# ADDITIONS (append-only, 1.3.0)
# =============================================================================
# Path resolution against a root. Tilde and trailing-slash live in
# path_normalize (already in this file). These wrap that for CLIs that
# have a ROOT / FORK_ROOT and accept "name", "~/x", "/abs" or "./rel".

# -----------------------------------------------------------------------------
# path_is_rooted
# -----------------------------------------------------------------------------
# @brief Whether a path is already rooted (absolute, ./ or ../).
# @param[in] 1  Path (tilde should already be expanded).
# @return 0 if rooted.
path_is_rooted() {
	local p="${1-}"
	case "$p" in
		/*|./*|../*) return 0 ;;
		*)           return 1 ;;
	esac
}

# -----------------------------------------------------------------------------
# path_join
# -----------------------------------------------------------------------------
# @brief Join two path pieces with a single slash. Empty base → second piece.
# @param[in] 1  Base.
# @param[in] 2  Child.
# @stdout       Joined path (not resolved, not required to exist).
path_join() {
	local base child
	base="$(path_normalize "${1-}")"
	child="$(trim "${2-}")"
	child="${child#/}"
	if [[ -z "$base" || "$base" == . ]]; then
		printf '%s\n' "$child"
		return 0
	fi
	if [[ -z "$child" ]]; then
		printf '%s\n' "$base"
		return 0
	fi
	printf '%s/%s\n' "$base" "$child"
}

# -----------------------------------------------------------------------------
# path_under_root
# -----------------------------------------------------------------------------
# @brief Resolve a user spec against a root.
#        Expands ~, strips trailing slashes, then joins to root unless rooted.
# @param[in] 1  Root directory.
# @param[in] 2  Spec (~, absolute, ./, ../, or name under root).
# @stdout       Normalised path (existence not required).
path_under_root() {
	local root spec
	root="$(path_normalize "${1-}")"
	spec="$(path_normalize "${2-}")"
	if path_is_rooted "$spec"; then
		printf '%s\n' "$spec"
	else
		path_join "$root" "$spec"
	fi
}

# -----------------------------------------------------------------------------
# require_dir
# -----------------------------------------------------------------------------
# @brief Exit via displayError unless path is an existing directory.
# @param[in] 1  Path to test.
# @param[in] 2  Optional original spec quoted in the error.
require_dir() {
	local path="${1-}" spec="${2-}"
	[[ -d "$path" ]] && return 0
	if [[ -n "$spec" && "$spec" != "$path" ]]; then
		displayError "Not a directory: $spec (tried: $path)"
	fi
	displayError "Not a directory: $path"
}

# -----------------------------------------------------------------------------
# dir_realpath
# -----------------------------------------------------------------------------
# @brief Canonical absolute path of an existing directory (cd && pwd).
# @param[in] 1  Directory.
# @stdout       Absolute path.
# @return 1 if not a directory.
dir_realpath() {
	local d="${1-}"
	[[ -d "$d" ]] || return 1
	(cd "$d" && pwd)
}

# -----------------------------------------------------------------------------
# resolve_dir_under
# -----------------------------------------------------------------------------
# @brief path_under_root + must be a directory + realpath.
# @param[in] 1  Root.
# @param[in] 2  Spec.
# @stdout       Absolute directory.
# @note         Calls displayError (exits) if missing.
resolve_dir_under() {
	local root="${1-}" spec="${2-}" candidate
	candidate="$(path_under_root "$root" "$spec")"
	require_dir "$candidate" "$spec"
	dir_realpath "$candidate"
}
