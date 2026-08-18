#!/usr/bin/env bash
# =============================================================================
# StormByte Git helpers library
# =============================================================================
# Contains only git and repository related helpers.
# This file is intended to be sourced by StormByte scripts.
# Requires StormByte functions.sh >= 1.1.0 (semver / version_* helpers).
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_GIT_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_GIT_LOADED=1

# Library version (SEMVER)
readonly STORMBYTE_FUNCTIONS_GIT_VERSION="1.2.0"

# Minimum StormByte functions.sh version (version_plain, version_is_*, semver_*)
readonly _STORMBYTE_FUNCTIONS_GIT_NEED_FUNCTIONS="1.1.0"

if [[ -z "${STORMBYTE_FUNCTIONS_VERSION:-}" ]]; then
	printf 'ERROR: functions.sh must be sourced before git.sh\n' >&2
	return 1 2>/dev/null || exit 1
fi

if ! semver_ge "${STORMBYTE_FUNCTIONS_VERSION}" "${_STORMBYTE_FUNCTIONS_GIT_NEED_FUNCTIONS}"; then
	printf 'ERROR: git.sh %s requires functions.sh >= %s (have %s)\n' \
		"${STORMBYTE_FUNCTIONS_GIT_VERSION}" \
		"${_STORMBYTE_FUNCTIONS_GIT_NEED_FUNCTIONS}" \
		"${STORMBYTE_FUNCTIONS_VERSION}" >&2
	return 1 2>/dev/null || exit 1
fi

# -----------------------------------------------------------------------------
# Force English/C locale for every git invocation (this script + sourced libs).
# Keeps messages consistent regardless of the user's LANG/LC_MESSAGES.
# -----------------------------------------------------------------------------
git() {
	LC_ALL=C LANG=C command git "$@"
}

# -----------------------------------------------------------------------------
# Shell safety
# -----------------------------------------------------------------------------

# Quote a string so it is safe to embed in a shell command line (spaces, (), etc.).
# Usage: q="$(git_shell_quote "$name")"; eval "echo $q"   # prefer variables over eval
git_shell_quote() {
	printf '%q' "$1"
}

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

# -----------------------------------------------------------------------------
# .gitmodules / submodule helpers
# -----------------------------------------------------------------------------

# Return 0 if a submodule checkout path is safe for "git submodule add".
# Must be relative to the repository root: no absolute path, no ".." anywhere.
# Usage: git_submodule_path_is_safe "thirdparty/foo" || echo bad
git_submodule_path_is_safe() {
	local path="$1"

	[[ -n "$path" ]] || return 1
	[[ "$path" == /* ]] && return 1
	[[ "$path" == *..* ]] && return 1
	return 0
}

# True if dir/.gitmodules defines at least one submodule URL.
# Usage: git_has_submodules "/path/to/repo"
git_has_submodules() {
	local dir="${1:-.}"
	local file="$dir/.gitmodules"

	[[ -f "$file" ]] || return 1
	git config --file "$file" --get-regexp '^submodule\..*\.url$' >/dev/null 2>&1
}

# List entries from dir/.gitmodules.
# Prints one line per submodule: name<TAB>path<TAB>url
# Missing or empty file → no output, exit 0.
# Usage: git_gitmodules_list "/path/to/repo"
git_gitmodules_list() {
	local dir="${1:-.}"
	local file="$dir/.gitmodules"
	local names name path url

	[[ -f "$file" ]] || return 0

	mapfile -t names < <(
		git config --file "$file" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null \
			| sed -E 's/^submodule\.(.*)\.path$/\1/' \
			|| true
	)

	for name in "${names[@]:-}"; do
		[[ -z "$name" ]] && continue
		path="$(git config --file "$file" --get "submodule.${name}.path" 2>/dev/null || true)"
		url="$(git config --file "$file" --get "submodule.${name}.url" 2>/dev/null || true)"
		printf '%s\t%s\t%s\n' "$name" "${path:-}" "${url:-}"
	done
}

# Find a submodule by exact name in .gitmodules.
# Prints: name<TAB>path<TAB>url  — returns 1 if not found.
# Usage: git_gitmodules_find_by_name "/path/to/repo" "Bzip2"
git_gitmodules_find_by_name() {
	local dir="${1:-.}"
	local want="$2"
	local name path url

	[[ -n "$want" ]] || return 1

	while IFS=$'\t' read -r name path url; do
		[[ -z "$name" ]] && continue
		if [[ "$name" == "$want" ]]; then
			printf '%s\t%s\t%s\n' "$name" "$path" "$url"
			return 0
		fi
	done < <(git_gitmodules_list "$dir")

	return 1
}

# Find a submodule by exact URL in .gitmodules.
# Prints: name<TAB>path<TAB>url  — returns 1 if not found.
# Usage: git_gitmodules_find_by_url "/path/to/repo" "https://github.com/org/repo.git"
git_gitmodules_find_by_url() {
	local dir="${1:-.}"
	local want="$2"
	local name path url

	[[ -n "$want" ]] || return 1

	while IFS=$'\t' read -r name path url; do
		[[ -z "$name" ]] && continue
		if [[ "$url" == "$want" ]]; then
			printf '%s\t%s\t%s\n' "$name" "$path" "$url"
			return 0
		fi
	done < <(git_gitmodules_list "$dir")

	return 1
}

# Find a submodule by exact path in .gitmodules.
# Path must already be safe (relative, no ".."); comparison is string-exact
# against the path stored in .gitmodules.
# Prints: name<TAB>path<TAB>url  — returns 1 if not found.
# Usage: git_gitmodules_find_by_path "/path/to/repo" "thirdparty/Bzip2/src"
git_gitmodules_find_by_path() {
	local dir="${1:-.}"
	local want="$2"
	local name path url

	[[ -n "$want" ]] || return 1
	git_submodule_path_is_safe "$want" || return 1

	while IFS=$'\t' read -r name path url; do
		[[ -z "$name" ]] && continue
		if [[ "$path" == "$want" ]]; then
			printf '%s\t%s\t%s\n' "$name" "$path" "$url"
			return 0
		fi
	done < <(git_gitmodules_list "$dir")

	return 1
}

# Resolve which branch a submodule should track.
# Order: preferred (e.g. from .gitmodules) → current branch → origin/HEAD
#        → origin/main → origin/master.
# Prints the branch name; returns 1 if none can be resolved.
# Usage: git_submodule_resolve_branch "/abs/path/to/submodule" ["preferred"]
git_submodule_resolve_branch() {
	local sm_dir="$1"
	local preferred="${2:-}"
	local branch=""

	[[ -d "$sm_dir" ]] || return 1

	if [[ -n "$preferred" ]]; then
		branch="$preferred"
	fi

	if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
		branch="$(git -C "$sm_dir" symbolic-ref -q --short HEAD 2>/dev/null || true)"
	fi

	if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
		branch="$(
			git -C "$sm_dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null \
				| sed 's#^origin/##' || true
		)"
	fi

	if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
		if git -C "$sm_dir" rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
			branch=main
		elif git -C "$sm_dir" rev-parse --verify refs/remotes/origin/master >/dev/null 2>&1; then
			branch=master
		else
			return 1
		fi
	fi

	printf '%s\n' "$branch"
}

# Force one submodule checkout to the tip of origin/<branch>.
# Discards local commits in that submodule (force-push recovery).
# preferred_branch may be empty (auto-resolve). Soft-fail: returns 1 on skip/error.
# Usage: git_submodule_force_to_remote_tip "/abs/sm" ["master"]
git_submodule_force_to_remote_tip() {
	local sm_dir="$1"
	local preferred="${2:-}"
	local branch

	[[ -d "$sm_dir" ]] || return 1

	if ! git -C "$sm_dir" remote get-url origin >/dev/null 2>&1; then
		return 1
	fi

	if ! git -C "$sm_dir" fetch origin --prune --force >/dev/null 2>&1; then
		return 1
	fi

	branch="$(git_submodule_resolve_branch "$sm_dir" "$preferred")" || return 1

	# After fetch, preferred might still be missing — re-probe main/master
	if ! git -C "$sm_dir" rev-parse --verify "refs/remotes/origin/${branch}" >/dev/null 2>&1; then
		branch="$(git_submodule_resolve_branch "$sm_dir" "")" || return 1
	fi

	if ! git -C "$sm_dir" rev-parse --verify "refs/remotes/origin/${branch}" >/dev/null 2>&1; then
		return 1
	fi

	git -C "$sm_dir" checkout -B "$branch" "refs/remotes/origin/${branch}" >/dev/null 2>&1 || return 1
	git -C "$sm_dir" reset --hard "refs/remotes/origin/${branch}" >/dev/null 2>&1 || return 1
	git -C "$sm_dir" clean -fd >/dev/null 2>&1 || true
	return 0
}

# Force all submodules (recursive) under a superproject to their remote branch tips.
# Names with spaces/() are safe: we never embed them in an eval'd foreach script;
# we only pass paths and optional branch hints as bash variables.
# Prints progress lines to stdout: "→ <name>: ok|skip (reason)"
# Usage: git_submodules_force_all_to_remote "/path/to/superproject"
git_submodules_force_all_to_remote() {
	local dir="${1:-.}"
	local toplevel name sm_abs preferred rc

	[[ -f "$dir/.gitmodules" ]] || return 0

	# Ensure checkouts exist
	git -C "$dir" submodule update --init --recursive >/dev/null 2>&1 || true

	# One record per submodule: superproject TAB name TAB absolute path
	# (name may contain spaces/(); tabs/newlines in names are not supported)
	while IFS=$'\t' read -r toplevel name sm_abs; do
		[[ -z "$sm_abs" || ! -d "$sm_abs" ]] && continue

		preferred=""
		if [[ -n "$toplevel" && -f "$toplevel/.gitmodules" && -n "$name" ]]; then
			preferred="$(
				git config -f "$toplevel/.gitmodules" --get "submodule.${name}.branch" 2>/dev/null || true
			)"
		fi

		if git_submodule_force_to_remote_tip "$sm_abs" "$preferred"; then
			printf '→ %s: ok\n' "${name:-$sm_abs}"
		else
			printf '→ %s: skip\n' "${name:-$sm_abs}"
		fi
	done < <(
		git -C "$dir" submodule foreach --recursive --quiet \
			'printf "%s\t%s\t%s\n" "$toplevel" "$name" "$(pwd)"' 2>/dev/null || true
	)

	return 0
}

# -----------------------------------------------------------------------------
# Local tracking / mergeability helpers
# -----------------------------------------------------------------------------

# Print the upstream tracking ref of the current branch (e.g. origin/master).
# Empty output and non-zero status if there is no upstream.
# Usage: git_upstream_ref "/path/to/repo"
git_upstream_ref() {
	local dir="${1:-.}"
	local up

	up="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || return 1
	[[ -n "$up" ]] || return 1
	printf '%s\n' "$up"
}

# Print local ahead/behind counts relative to the current branch upstream.
# Output format: "ahead behind" (two integers).
# Returns non-zero if there is no upstream or the counts cannot be computed.
# Usage: git_ahead_behind "/path/to/repo"
git_ahead_behind() {
	local dir="${1:-.}"
	local counts ahead behind

	git_upstream_ref "$dir" >/dev/null || return 1

	counts="$(git -C "$dir" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)" || return 1
	# rev-list --left-right --count prints: "<ahead>\t<behind>"
	ahead="${counts%%[$'\t ]*}"
	behind="${counts##*[$'\t ]}"
	[[ "$ahead" =~ ^[0-9]+$ && "$behind" =~ ^[0-9]+$ ]] || return 1
	printf '%s %s\n' "$ahead" "$behind"
}

# Return 0 if merging <head> into <base> would be conflict-free (GitHub-style).
# Does not touch the working tree, index, or refs (uses git merge-tree only).
# Usage: git_merge_tree_clean "/path/to/repo" "master" "feature-branch"
git_merge_tree_clean() {
	local dir="${1:-.}"
	local base="${2:-}"
	local head="${3:-}"

	[[ -n "$base" && -n "$head" ]] || return 1

	# Ensure both tips resolve
	git -C "$dir" rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || return 1
	git -C "$dir" rev-parse --verify "$head^{commit}" >/dev/null 2>&1 || return 1

	git -C "$dir" merge-tree --write-tree "$base" "$head" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Tag helpers (1.1.0)
# -----------------------------------------------------------------------------

# Print the latest tag by version sort (v-aware). Empty if none.
# Usage: git_latest_tag "/path/to/repo"
git_latest_tag() {
	local dir="${1:-.}"
	git -C "$dir" tag -l --sort=-v:refname 2>/dev/null | head -n1 || true
}

# Return 0 if the tag exists locally.
# Usage: git_tag_exists_local "/path/to/repo" "1.0.0"
git_tag_exists_local() {
	local dir="${1:-.}"
	local tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1
}

# Return 0 if the tag exists on origin.
# Usage: git_tag_exists_remote "/path/to/repo" "1.0.0"
git_tag_exists_remote() {
	local dir="${1:-.}"
	local tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q .
}

# Delete a tag locally and on origin (best-effort).
# Usage: git_tag_delete_local_remote "/path/to/repo" "1.0.0"
git_tag_delete_local_remote() {
	local dir="${1:-.}"
	local tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" tag -d "$tag" >/dev/null 2>&1 || true
	git -C "$dir" push origin ":refs/tags/$tag" >/dev/null 2>&1 || true
	return 0
}

# -----------------------------------------------------------------------------
# CHANGELOG helpers (1.1.0) — Keep a Changelog style
# -----------------------------------------------------------------------------

# Extract release notes for a version from CHANGELOG.md.
# Requires a header of the form:
#   ## [1.0.0] - YYYY-MM-DD
#   ## [v1.0.0] - YYYY-MM-DD
# Uses version_plain() from functions.sh for matching.
# Prints the section body (no header). Returns 1 if missing or empty.
# Usage: git_changelog_extract_notes "/path/CHANGELOG.md" "1.0.0"
git_changelog_extract_notes() {
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
# CI wait helper (1.1.0) — requires gh
# -----------------------------------------------------------------------------

# Wait until all workflow runs for a commit have completed successfully.
# Polls periodically. Safe to interrupt with Ctrl-C (returns non-zero; no side effects).
# Usage: git_wait_ci_success "owner/repo" "fullsha" [timeout_sec=3600]
git_wait_ci_success() {
	local repo="$1"
	local sha="$2"
	local timeout="${3:-3600}"
	local start now elapsed pending failed
	local -a runs
	local line st conc name rest

	start="$(date +%s)"
	printf '  Waiting for CI on %s (commit %s)…\n' "$repo" "${sha:0:12}" >&2
	printf '  This may take a while. Ctrl-C cancels cleanly (no tag should exist yet).\n' >&2

	while true; do
		now="$(date +%s)"
		elapsed=$((now - start))
		if ((elapsed > timeout)); then
			printf '  CI wait timed out after %ss\n' "$timeout" >&2
			return 1
		fi

		mapfile -t runs < <(
			gh run list -R "$repo" --commit "$sha" --limit 50 \
				--json status,conclusion,name \
				--jq '.[] | "\(.status)\t\(.conclusion // "-")\t\(.name // "?")"' \
				2>/dev/null || true
		)

		if [[ ${#runs[@]} -eq 0 ]]; then
			printf '  No workflow runs found yet for this commit (waiting)…\n' >&2
			sleep 15
			continue
		fi

		pending=0
		failed=0
		for line in "${runs[@]}"; do
			st="${line%%$'\t'*}"
			rest="${line#*$'\t'}"
			conc="${rest%%$'\t'*}"
			name="${rest#*$'\t'}"
			case "$st" in
				queued|pending|in_progress|waiting|requested)
					pending=$((pending + 1))
					;;
				completed)
					case "$conc" in
						success|skipped|neutral) ;;
						*)
							failed=$((failed + 1))
							printf '  CI failed: %s (%s)\n' "$name" "$conc" >&2
							;;
					esac
					;;
			esac
		done

		if ((failed > 0)); then
			return 1
		fi
		if ((pending == 0)); then
			printf '  CI green (%s run(s))\n' "${#runs[@]}" >&2
			return 0
		fi
		printf '  … %s run(s) still in progress (%ss elapsed)\n' "$pending" "$elapsed" >&2
		sleep 20
	done
}

# -----------------------------------------------------------------------------
# Pin / tag family helpers (append-only; used by StormByte-GitHub submodules update)
# -----------------------------------------------------------------------------

## @brief Fetch origin tags and prune stale remote refs.
## @param[in] dir Repository path.
## @return 0 on success.
git_fetch_origin_tags() {
	local dir="$1"
	git -C "$dir" fetch origin --tags --prune --force --prune-tags >/dev/null 2>&1
}

## @brief Whether an object exists in the repository.
## @param[in] dir Repository path.
## @param[in] spec SHA or ref.
## @return 0 if present.
git_object_exists() {
	local dir="$1" spec="$2"
	git -C "$dir" cat-file -e "${spec}^{object}" >/dev/null 2>&1
}

## @brief Exact tag name at HEAD, if any.
## @param[in] dir Repository path.
## @stdout Tag name or empty.
git_exact_tag_at_head() {
	local dir="$1"
	git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || true
}

## @brief Exact tag pointing at a SHA, if any.
## @param[in] dir Repository path.
## @param[in] sha Commit SHA.
## @stdout Tag name or empty.
git_exact_tag_at_sha() {
	local repo="$1" sha="$2"
	local t best="" fam
	[[ -n "$repo" && -n "$sha" ]] || return 0
	while IFS= read -r t; do
		[[ -z "$t" ]] && continue
		fam="$(git_pin_family_name "$t" 2>/dev/null || true)"
		if [[ -z "$best" ]]; then
			best="$t"
		elif [[ -n "$fam" ]]; then
			best="$t"
		fi
	done < <(git -C "$repo" tag --points-at "$sha" 2>/dev/null)
	printf '%s' "$best"
}

## @brief Strip a leading origin/ prefix from a ref name.
## @param[in] ref Ref name.
## @stdout Bare name.
git_ref_basename() {
	local ref="$1"
	ref="${ref#refs/tags/}"
	ref="${ref#refs/heads/}"
	ref="${ref#refs/remotes/origin/}"
	ref="${ref#origin/}"
	printf '%s\n' "$ref"
}

## @brief Whether a ref name looks unstable (alpha/beta/rc/pre/MS/…).
## @param[in] name Bare ref name.
## @return 0 if unstable.
git_ref_is_unstable() {
	local name="${1,,}"
	[[ "$name" =~ (alpha|beta|rc[0-9]*|pre|preview|snapshot|dev|test|^.*-ms[0-9]*$|_pre|_ms) ]]
}

## @brief Configurable pin families: name|pin_regex|cand_regex|kind
## kind is tag or branch.
## First matching pin_regex wins.
git_pin_family_table() {
	cat <<'EOF'
semver|^v?[0-9]+\.[0-9]+\.[0-9]+$|^v?[0-9]+\.[0-9]+\.[0-9]+$|tag
rel_stable|^REL_[0-9]+_STABLE$|^REL_[0-9]+_STABLE$|branch
rel_legacy|^REL[0-9]+_[0-9]+_STABLE$|^REL[0-9]+_[0-9]+_STABLE$|branch
EOF
}

## @brief Family name for a pin, or empty if unclassified.
## @param[in] pin Bare pin name (tag or branch).
## @stdout Family name or empty.
git_pin_family_name() {
	local pin="$1" line name pin_re
	pin="$(git_ref_basename "$pin")"
	while IFS='|' read -r name pin_re _ _; do
		[[ -z "$name" ]] && continue
		if [[ "$pin" =~ $pin_re ]]; then
			printf '%s\n' "$name"
			return 0
		fi
	done < <(git_pin_family_table)
	return 0
}

## @brief Kind (tag|branch) for a family name.
## @param[in] family Family name.
## @stdout tag or branch.
git_pin_family_kind() {
	local family="$1" line name kind
	while IFS='|' read -r name _ _ kind; do
		[[ "$name" == "$family" ]] || continue
		printf '%s\n' "$kind"
		return 0
	done < <(git_pin_family_table)
	printf '%s\n' "tag"
}

## @brief Candidate regex for a family.
## @param[in] family Family name.
## @stdout Regex.
git_pin_family_cand_regex() {
	local family="$1" name cand
	while IFS='|' read -r name _ cand _; do
		[[ "$name" == "$family" ]] || continue
		printf '%s\n' "$cand"
		return 0
	done < <(git_pin_family_table)
}

## @brief Sort key for a pin (space-separated integers).
## @param[in] pin Bare name.
## @stdout Key or empty.
git_pin_sort_key() {
	local pin="$1"
	pin="$(git_ref_basename "$pin")"
	if [[ "$pin" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
		printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
		return 0
	fi
	if [[ "$pin" =~ ^REL_([0-9]+)_STABLE$ ]]; then
		printf '%s\n' "${BASH_REMATCH[1]}"
		return 0
	fi
	if [[ "$pin" =~ ^REL([0-9]+)_([0-9]+)_STABLE$ ]]; then
		printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
		return 0
	fi
	return 1
}

## @brief Compare two sort keys (space-separated integers).
## @return 0 if a < b, 1 if a == b, 2 if a > b.
git_pin_key_cmp() {
	local -a a=($1) b=($2)
	local i n
	n=${#a[@]}
	(( ${#b[@]} > n )) && n=${#b[@]}
	for ((i = 0; i < n; i++)); do
		local av="${a[i]:-0}" bv="${b[i]:-0}"
		if ((10#$av < 10#$bv)); then
			return 0
		fi
		if ((10#$av > 10#$bv)); then
			return 2
		fi
	done
	return 1
}

## @brief List tag names in a repo (local after fetch).
## @param[in] dir Repository path.
## @stdout One tag per line.
git_list_tags() {
	local dir="$1"
	git -C "$dir" tag --list 2>/dev/null | sed '/^$/d'
}

## @brief List origin branch names without origin/ prefix.
## @param[in] dir Repository path.
## @stdout One branch per line.
git_list_origin_branches() {
	local dir="$1" line
	git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
		| while IFS= read -r line; do
			[[ "$line" == origin/* ]] || continue
			[[ "$line" == origin/HEAD ]] && continue
			git_ref_basename "$line"
		done
}

## @brief Best successor in the same family, or empty if none/ambiguous.
## @param[in] dir Repository path.
## @param[in] pin Current bare pin.
## @stdout Next ref, or empty.
## @return 0 if unique successor or pin is already latest (stdout empty if latest).
##         1 if unclassified or ambiguous.
git_pin_next_in_family() {
	local repo="$1" pin="$2"
	local prefix="${3:-refs/tags}"
	local fam kind regex pin_key cand ckey
	local best="" best_key=""

	[[ -n "$repo" && -n "$pin" ]] || return 1
	fam="$(git_pin_family_name "$pin")" || return 1
	kind="$(git_pin_family_kind "$fam")"
	regex="$(git_pin_family_cand_regex "$fam")"
	pin_key="$(git_pin_sort_key "$pin")"
	[[ -n "$regex" && -n "$pin_key" ]] || return 1

	while IFS= read -r cand; do
		[[ -z "$cand" ]] && continue
		git_ref_is_unstable "$cand" && continue
		[[ "$cand" =~ $regex ]] || continue
		ckey="$(git_pin_sort_key "$cand")"
		[[ -n "$ckey" ]] || continue
		if git_pin_key_cmp "$pin_key" "$ckey"; then
			if [[ -z "$best" ]] || git_pin_key_cmp "$ckey" "$best_key"; then
				best="$cand"
				best_key="$ckey"
			fi
		fi
	done < <(git_list_tag_names "$repo" "$prefix")

	if [[ -z "$best" ]]; then
		printf '%s' "$pin"
		return 0
	fi
	printf '%s' "$best"
}

## @brief Classify a checked-out submodule: float | tag | sha
## @param[in] parent Superproject path.
## @param[in] sm_name Submodule name in .gitmodules.
## @param[in] abs Absolute submodule path.
## @stdout One line: kind<TAB>label<TAB>sha
##         kind is branch, tag or sha.
git_sm_classify() {
	local parent="$1" name="$2" abs="$3"
	local path branch sha tip tag

	path="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.path" 2>/dev/null || true)"
	branch="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.branch" 2>/dev/null || true)"
	branch="$(git_ref_basename "$branch")"

	sha=""
	if [[ -n "$path" ]]; then
		sha="$(git -C "$parent" rev-parse "HEAD:${path}" 2>/dev/null || true)"
	fi
	if [[ -z "$sha" ]] && { [[ -d "$abs/.git" ]] || [[ -f "$abs/.git" ]]; }; then
		sha="$(git -C "$abs" rev-parse HEAD 2>/dev/null || true)"
	fi

	tag="$(git_exact_tag_at_sha "$abs" "$sha")"
	if [[ -n "$tag" ]]; then
		printf 'tag\t%s\t%s\n' "$tag" "$sha"
		return 0
	fi

	if [[ -n "$branch" ]]; then
		tip="$(git -C "$abs" rev-parse --verify "origin/${branch}" 2>/dev/null || true)"
		if [[ -z "$tip" ]]; then
			tip="$(git_peel_ref "$abs" "refs/sb-gh/heads/${branch}" 2>/dev/null || true)"
		fi
		if [[ -n "$tip" && -n "$sha" && "$tip" == "$sha" ]]; then
			printf 'branch\t%s\t%s\n' "$branch" "$sha"
			return 0
		fi
	fi

	printf 'sha\t%s\t%s\n' "${sha:0:7}" "$sha"
}

git_shadow_fetch() {
	local repo="$1"
	[[ -n "$repo" && -d "$repo" ]] || return 1
	git -C "$repo" fetch origin --prune \
		'+refs/heads/*:refs/sb-gh/heads/*' \
		'+refs/tags/*:refs/sb-gh/tags/*' >/dev/null 2>&1
}

git_shadow_delete() {
	local repo="$1"
	local ref
	[[ -n "$repo" && -d "$repo" ]] || return 0
	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		git -C "$repo" update-ref -d "$ref" >/dev/null 2>&1 || true
	done < <(git -C "$repo" for-each-ref --format='%(refname)' refs/sb-gh 2>/dev/null)
}

git_list_tag_names() {
	local repo="$1"
	local prefix="${2:-refs/tags}"
	local ref
	prefix="${prefix%/}"
	[[ -n "$repo" && -d "$repo" ]] || return 0
	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		printf '%s\n' "${ref#${prefix}/}"
	done < <(git -C "$repo" for-each-ref --format='%(refname)' "$prefix" 2>/dev/null)
}

git_peel_ref() {
	local repo="$1" ref="$2"
	[[ -n "$repo" && -n "$ref" ]] || return 1
	git -C "$repo" rev-parse --verify "${ref}^{}" 2>/dev/null
}
