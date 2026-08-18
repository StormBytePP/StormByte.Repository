#!/usr/bin/env bash
# =============================================================================
# StormByte Git helpers library
# =============================================================================
# Contains only git and repository related helpers.
# This file is intended to be sourced by StormByte scripts.
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_GIT_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_GIT_LOADED=1

# Library version (SEMVER)
readonly STORMBYTE_FUNCTIONS_GIT_VERSION="1.0.0"

# -----------------------------------------------------------------------------
# Basic git information helpers
# -----------------------------------------------------------------------------

# Print the current branch name of a repository.
# Usage: git_current_branch "/path/to/repo"
# Returns the branch name or an empty string on failure.
git_current_branch() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

# Print the short SHA of HEAD.
# Usage: git_head_sha "/path/to/repo"
git_head_sha() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse --short HEAD 2>/dev/null || true
}

# Print the full SHA of HEAD.
# Usage: git_head_sha_full "/path/to/repo"
git_head_sha_full() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse HEAD 2>/dev/null || true
}

# Return 0 if the working tree has uncommitted changes.
# Usage: git_is_dirty "/path/to/repo" && echo "dirty"
git_is_dirty() {
	local dir="${1:-.}"
	[[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]
}

# -----------------------------------------------------------------------------
# Stash helpers
# -----------------------------------------------------------------------------

# Stash all changes (including untracked) if the working tree is dirty.
# Returns 0 if a stash was created, 1 otherwise.
# Usage: git_stash_if_dirty "/path/to/repo" "optional message"
git_stash_if_dirty() {
	local dir="${1:-.}"
	local msg="${2:-StormByte auto-stash}"

	if git_is_dirty "$dir"; then
		git -C "$dir" stash push -u -m "$msg" >/dev/null 2>&1
		return $?
	fi
	return 1
}

# Safely pop the latest stash.
# Warns on conflicts but does not abort the caller.
# Usage: git_stash_pop_safe "/path/to/repo"
git_stash_pop_safe() {
	local dir="${1:-.}"

	if ! git -C "$dir" stash pop >/dev/null 2>&1; then
		# We deliberately do not call displayError here so the caller can decide
		printf "  ${_CLR_BOLD_YELLOW}⚠  WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} stash pop produced conflicts in %s — resolve manually\n" "$dir" >&2
		return 1
	fi
	return 0
}

# -----------------------------------------------------------------------------
# Branch helpers
# -----------------------------------------------------------------------------

# Switch to a branch, creating a local tracking branch if necessary.
# Usage: git_checkout_branch "/path/to/repo" "master"
git_checkout_branch() {
	local dir="${1:-.}"
	local branch="${2:-master}"

	if git -C "$dir" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$dir" checkout "$branch" >/dev/null 2>&1
	else
		# Try to create a local branch tracking origin
		git -C "$dir" checkout -B "$branch" "origin/$branch" >/dev/null 2>&1 || \
		git -C "$dir" checkout -B "$branch" >/dev/null 2>&1
	fi
}

# -----------------------------------------------------------------------------
# Remote / repository identity helpers
# -----------------------------------------------------------------------------

# Extract the "owner/repo" identifier from the origin remote URL.
# Usage: git_remote_repo "/path/to/repo"
# Prints "owner/repo" or empty string on failure.
git_remote_repo() {
	local dir="${1:-.}"
	local url

	url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || return 1
	printf '%s' "$url" | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#'
}

# Extract only the owner part of the origin remote.
# Usage: git_remote_owner "/path/to/repo"
git_remote_owner() {
	local repo
	repo="$(git_remote_repo "$1")" || return 1
	printf '%s\n' "${repo%%/*}"
}

# Extract only the repository name part of the origin remote.
# Usage: git_remote_name "/path/to/repo"
git_remote_name() {
	local repo
	repo="$(git_remote_repo "$1")" || return 1
	printf '%s\n' "${repo##*/}"
}

# Return 0 if the origin owner matches the expected owner (case-insensitive).
# Usage: git_owner_matches "/path/to/repo" "ExpectedOwner"
git_owner_matches() {
	local dir="$1"
	local expected="$2"
	local actual

	actual="$(git_remote_owner "$dir")" || return 1
	[[ "${actual,,}" == "${expected,,}" ]]
}

# -----------------------------------------------------------------------------
# Repository validation
# -----------------------------------------------------------------------------

# Check that a directory is a usable git repository belonging to the expected owner.
# On success prints "owner/repo".
# On failure prints an error message to stderr and returns non-zero.
# Usage: git_resolve_repo "/path/to/dir" "ExpectedOwner"
git_resolve_repo() {
	local dir="$1"
	local expected_owner="$2"
	local repo owner

	if [[ ! -d "$dir" ]]; then
		printf "Not a directory: %s\n" "$dir" >&2
		return 1
	fi

	if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
		printf "Not a git repository: %s\n" "$dir" >&2
		return 1
	fi

	repo="$(git_remote_repo "$dir")" || {
		printf "No origin remote in %s\n" "$dir" >&2
		return 1
	}

	owner="${repo%%/*}"
	if [[ "${owner,,}" != "${expected_owner,,}" ]]; then
		printf "Origin owner is '%s', expected '%s': %s\n" "$owner" "$expected_owner" "$dir" >&2
		return 1
	fi

	printf '%s\n' "$repo"
}

# -----------------------------------------------------------------------------
# Fork helpers
# -----------------------------------------------------------------------------

# Return 0 if the repository is a fork (requires gh CLI).
# Usage: git_is_fork "owner/repo"
git_is_fork() {
	local repo="$1"
	local is_fork

	is_fork="$(gh repo view "$repo" --json isFork --jq '.isFork' 2>/dev/null || echo "false")"
	[[ "$is_fork" == "true" ]]
}

# Print the parent repository of a fork (owner/name).
# Usage: git_fork_parent "owner/repo"
git_fork_parent() {
	local repo="$1"
	gh repo view "$repo" --json parent --jq '.parent.owner.login + "/" + .parent.name' 2>/dev/null || true
}

# Print behind/ahead counts relative to the upstream default branch.
# Usage: git_fork_compare "owner/repo"
# Output format: "behind ahead"
git_fork_compare() {
	local repo="$1"
	local parent parent_owner default_branch fork_default cmp behind ahead

	parent="$(git_fork_parent "$repo")"
	[[ -z "$parent" || "$parent" == "null/null" ]] && return 1

	# GitHub compare cross-repo syntax is "owner:branch", NOT "owner/repo:branch"
	parent_owner="${parent%%/*}"

	default_branch="$(gh repo view "$parent" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "master")"
	fork_default="$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "master")"

	# base = upstream, head = fork (matches GitHub UI "X commits behind upstream:branch")
	cmp="$(gh api "repos/${repo}/compare/${parent_owner}:${default_branch}...${fork_default}" \
		--jq '{behind: .behind_by, ahead: .ahead_by}' 2>/dev/null || true)"

	if [[ -z "$cmp" || "$cmp" == "null" ]]; then
		return 1
	fi

	behind="$(printf '%s' "$cmp" | jq -r '.behind // 0')"
	ahead="$(printf '%s' "$cmp" | jq -r '.ahead // 0')"
	printf '%s %s\n' "$behind" "$ahead"
	return 0
}

# -----------------------------------------------------------------------------
# Sync helpers
# -----------------------------------------------------------------------------

# Synchronise only the master branch of a fork with its upstream.
# This is the safe equivalent of the GitHub web "Sync repository" button
# followed by a local pull --rebase, restricted to master.
#
# Usage: git_fork_sync_master "/path/to/repo" "owner/repo"
# Returns 0 on success.
git_fork_sync_master() {
	local dir="$1"
	local repo="$2"
	local current_branch stashed=0

	current_branch="$(git_current_branch "$dir")"
	[[ -z "$current_branch" ]] && return 1

	# Stash if dirty
	if git_stash_if_dirty "$dir" "StormByte fork-sync auto-stash"; then
		stashed=1
	fi

	# Switch to master
	if [[ "$current_branch" != "master" ]]; then
		git_checkout_branch "$dir" "master" || {
			[[ $stashed -eq 1 ]] && git_stash_pop_safe "$dir"
			return 1
		}
	fi

	# Perform the sync (remote side)
	if ! gh repo sync "$repo" -b master >/dev/null 2>&1; then
		# Still try a local pull in case the remote side partially succeeded
		git -C "$dir" pull --rebase origin master >/dev/null 2>&1 || true
	else
		git -C "$dir" pull --rebase origin master >/dev/null 2>&1 || true
	fi

	# Return to original branch
	if [[ "$current_branch" != "master" ]]; then
		git -C "$dir" checkout "$current_branch" >/dev/null 2>&1 || true
	fi

	# Restore stash
	if [[ $stashed -eq 1 ]]; then
		git_stash_pop_safe "$dir"
	fi

	return 0
}