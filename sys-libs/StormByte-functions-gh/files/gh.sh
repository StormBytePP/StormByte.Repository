#!/usr/bin/env bash
# =============================================================================
# StormByte GitHub (gh) helpers library
# =============================================================================
# Source AFTER functions.sh (>= 1.3.0) and git.sh (>= 1.3.0).
# Talks to GitHub via `gh`. No CLI UI, no DRY_RUN, no ROOT/OWNER.
# Stable TSV so callers do not embed jq.
# Forks and CI-wait used to live in git.sh; they belong here.
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_GH_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_GH_LOADED=1

readonly STORMBYTE_FUNCTIONS_GH_VERSION="1.0.0"
readonly _STORMBYTE_FUNCTIONS_GH_NEED_FUNCTIONS="1.3.0"
readonly _STORMBYTE_FUNCTIONS_GH_NEED_GIT="1.3.0"

if [[ -z "${STORMBYTE_FUNCTIONS_VERSION:-}" ]]; then
	printf 'ERROR: functions.sh must be sourced before gh.sh\n' >&2
	return 1 2>/dev/null || exit 1
fi

if ! semver_ge "${STORMBYTE_FUNCTIONS_VERSION}" "${_STORMBYTE_FUNCTIONS_GH_NEED_FUNCTIONS}"; then
	printf 'ERROR: gh.sh %s requires functions.sh >= %s (have %s)\n' \
		"${STORMBYTE_FUNCTIONS_GH_VERSION}" \
		"${_STORMBYTE_FUNCTIONS_GH_NEED_FUNCTIONS}" \
		"${STORMBYTE_FUNCTIONS_VERSION}" >&2
	return 1 2>/dev/null || exit 1
fi

if [[ -z "${STORMBYTE_FUNCTIONS_GIT_VERSION:-}" ]]; then
	printf 'ERROR: git.sh must be sourced before gh.sh\n' >&2
	return 1 2>/dev/null || exit 1
fi

if ! semver_ge "${STORMBYTE_FUNCTIONS_GIT_VERSION}" "${_STORMBYTE_FUNCTIONS_GH_NEED_GIT}"; then
	printf 'ERROR: gh.sh %s requires git.sh >= %s (have %s)\n' \
		"${STORMBYTE_FUNCTIONS_GH_VERSION}" \
		"${_STORMBYTE_FUNCTIONS_GH_NEED_GIT}" \
		"${STORMBYTE_FUNCTIONS_GIT_VERSION}" >&2
	return 1 2>/dev/null || exit 1
fi

# -----------------------------------------------------------------------------
# gh_require
# -----------------------------------------------------------------------------
# @brief Exit unless gh is on PATH (does not check auth).
gh_require() {
	command -v gh >/dev/null 2>&1 || displayError "Required command not found: gh"
}

# =============================================================================
# Caches
# =============================================================================

# -----------------------------------------------------------------------------
# gh_cache_list
# -----------------------------------------------------------------------------
# @brief Actions caches for a repo.
# @param[in] 1  owner/repo
# @param[in] 2  Page limit (default: 100)
# @stdout       id<TAB>bytes<TAB>key
gh_cache_list() {
	local repo="$1" limit="${2:-100}"
	[[ -n "$repo" ]] || return 0
	gh cache list -R "$repo" --limit "$limit" \
		--json id,key,sizeInBytes \
		--jq '.[] | "\(.id)\t\(.sizeInBytes // 0)\t\(.key)"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_cache_list_ids
# -----------------------------------------------------------------------------
# @brief id + key only (delete loop).
# @param[in] 1  owner/repo
# @param[in] 2  Page limit (default: 100)
# @stdout       id<TAB>key
gh_cache_list_ids() {
	local repo="$1" limit="${2:-100}"
	[[ -n "$repo" ]] || return 0
	gh cache list -R "$repo" --limit "$limit" \
		--json id,key \
		--jq '.[] | "\(.id)\t\(.key)"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_cache_delete
# -----------------------------------------------------------------------------
# @brief Delete one cache by id.
# @param[in] 1  owner/repo
# @param[in] 2  Cache id
# @return 0 on success.
gh_cache_delete() {
	local repo="$1" id="$2"
	[[ -n "$repo" && -n "$id" ]] || return 1
	gh cache delete "$id" -R "$repo" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_key_matches
# -----------------------------------------------------------------------------
# @brief Bash glob match. Empty pattern matches everything.
# @param[in] 1  Key
# @param[in] 2  Glob (optional)
# @return 0 if matches.
gh_key_matches() {
	local key="$1" pattern="${2-}"
	[[ -z "$pattern" ]] && return 0
	# shellcheck disable=SC2254
	[[ "$key" == $pattern ]]
}

# =============================================================================
# Workflow runs
# =============================================================================

# -----------------------------------------------------------------------------
# gh_run_list_commit
# -----------------------------------------------------------------------------
# @brief Runs for a commit SHA.
# @param[in] 1  owner/repo
# @param[in] 2  Full SHA
# @param[in] 3  Limit (default: 100)
# @stdout       id<TAB>status<TAB>conclusion<TAB>headSha<TAB>workflow<TAB>title
gh_run_list_commit() {
	local repo="$1" sha="$2" limit="${3:-100}"
	[[ -n "$repo" && -n "$sha" ]] || return 0
	gh run list -R "$repo" --commit "$sha" --limit "$limit" \
		--json databaseId,status,conclusion,headSha,displayTitle,workflowName \
		--jq '.[] | "\(.databaseId)\t\(.status)\t\(.conclusion // "-")\t\(.headSha // "")\t\(.workflowName // "-")\t\(.displayTitle // "")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_run_list_branch
# -----------------------------------------------------------------------------
# @brief Runs on a branch.
# @param[in] 1  owner/repo
# @param[in] 2  Branch
# @param[in] 3  Limit (default: 100)
# @stdout       same columns as gh_run_list_commit
gh_run_list_branch() {
	local repo="$1" branch="$2" limit="${3:-100}"
	[[ -n "$repo" && -n "$branch" ]] || return 0
	gh run list -R "$repo" --branch "$branch" --limit "$limit" \
		--json databaseId,status,conclusion,headSha,displayTitle,workflowName \
		--jq '.[] | "\(.databaseId)\t\(.status)\t\(.conclusion // "-")\t\(.headSha // "")\t\(.workflowName // "-")\t\(.displayTitle // "")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_run_list_for_start
# -----------------------------------------------------------------------------
# @brief Commit list, or branch list if the commit has no runs yet.
# @param[in] 1  owner/repo
# @param[in] 2  Branch
# @param[in] 3  Full SHA
# @param[in] 4  Limit (default: 100)
# @stdout       same columns as gh_run_list_commit
gh_run_list_for_start() {
	local repo="$1" branch="$2" sha="$3" limit="${4:-100}" out
	out="$(gh_run_list_commit "$repo" "$sha" "$limit")"
	if [[ -n "$out" ]]; then
		printf '%s\n' "$out"
		return 0
	fi
	gh_run_list_branch "$repo" "$branch" "$limit"
}

# -----------------------------------------------------------------------------
# gh_run_list_status
# -----------------------------------------------------------------------------
# @brief Runs on a branch with a given Actions status.
# @param[in] 1  owner/repo
# @param[in] 2  Branch
# @param[in] 3  Status (in_progress, queued, …)
# @param[in] 4  Limit (default: 100)
# @stdout       id<TAB>status<TAB>workflow<TAB>title
gh_run_list_status() {
	local repo="$1" branch="$2" status="$3" limit="${4:-100}"
	[[ -n "$repo" && -n "$branch" && -n "$status" ]] || return 0
	gh run list -R "$repo" --branch "$branch" --status "$status" --limit "$limit" \
		--json databaseId,status,displayTitle,workflowName \
		--jq '.[] | "\(.databaseId)\t\(.status)\t\(.workflowName // "-")\t\(.displayTitle // "")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_run_list_active
# -----------------------------------------------------------------------------
# @brief Unique active runs on a branch.
# @param[in] 1  owner/repo
# @param[in] 2  Branch
# @param[in] 3  Limit per status (default: 100)
# @stdout       id<TAB>status<TAB>workflow<TAB>title
gh_run_list_active() {
	local repo="$1" branch="$2" limit="${3:-100}"
	local st entry id
	local -A seen=()

	for st in in_progress queued pending waiting requested; do
		while IFS= read -r entry; do
			[[ -z "$entry" ]] && continue
			id="${entry%%$'\t'*}"
			[[ -z "$id" || -n "${seen[$id]+x}" ]] && continue
			seen["$id"]=1
			printf '%s\n' "$entry"
		done < <(gh_run_list_status "$repo" "$branch" "$st" "$limit")
	done
}

# -----------------------------------------------------------------------------
# gh_run_list_recent
# -----------------------------------------------------------------------------
# @brief Latest runs on a branch (status view).
# @param[in] 1  owner/repo
# @param[in] 2  Branch
# @param[in] 3  Limit (default: 15)
# @stdout       id<TAB>status<TAB>conclusion<TAB>workflow<TAB>title
gh_run_list_recent() {
	local repo="$1" branch="$2" limit="${3:-15}"
	[[ -n "$repo" && -n "$branch" ]] || return 0
	gh run list -R "$repo" --branch "$branch" --limit "$limit" \
		--json databaseId,status,conclusion,displayTitle,workflowName \
		--jq '.[] | "\(.databaseId)\t\(.status)\t\(.conclusion // "-")\t\(.workflowName // "-")\t\(.displayTitle // "")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_run_list_commit_status
# -----------------------------------------------------------------------------
# @brief Compact status/conclusion/name for CI wait.
# @param[in] 1  owner/repo
# @param[in] 2  Full SHA
# @param[in] 3  Limit (default: 50)
# @stdout       status<TAB>conclusion<TAB>name
gh_run_list_commit_status() {
	local repo="$1" sha="$2" limit="${3:-50}"
	[[ -n "$repo" && -n "$sha" ]] || return 0
	gh run list -R "$repo" --commit "$sha" --limit "$limit" \
		--json status,conclusion,name \
		--jq '.[] | "\(.status)\t\(.conclusion // "-")\t\(.name // "?")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_run_cancel
# -----------------------------------------------------------------------------
# @brief Cancel one run.
# @param[in] 1  owner/repo
# @param[in] 2  Run id
gh_run_cancel() {
	local repo="$1" id="$2"
	[[ -n "$repo" && -n "$id" ]] || return 1
	gh run cancel "$id" -R "$repo" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_run_rerun
# -----------------------------------------------------------------------------
# @brief Re-run one run.
# @param[in] 1  owner/repo
# @param[in] 2  Run id
gh_run_rerun() {
	local repo="$1" id="$2"
	[[ -n "$repo" && -n "$id" ]] || return 1
	gh run rerun "$id" -R "$repo" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_run_is_failed
# -----------------------------------------------------------------------------
# @brief Whether a conclusion is a failure-class result (--failed filter).
# @param[in] 1  Conclusion
# @return 0 if failed/cancelled/timed_out/startup_failure.
gh_run_is_failed() {
	case "${1,,}" in
		failure|cancelled|timed_out|startup_failure) return 0 ;;
		*) return 1 ;;
	esac
}

# -----------------------------------------------------------------------------
# gh_wait_ci_success
# -----------------------------------------------------------------------------
# @brief Wait until every workflow run for a commit has completed successfully.
#        Polls. Ctrl-C is safe (returns non-zero; no side effects).
# @param[in] 1  owner/repo
# @param[in] 2  Full SHA
# @param[in] 3  Timeout seconds (default: 3600)
# @return 0 if all runs succeeded; 1 on timeout, failure, or interrupt.
gh_wait_ci_success() {
	local repo="$1" sha="$2" timeout="${3:-3600}"
	local start now elapsed pending failed
	local -a runs
	local line st conc name
	local live=0 status_open=0

	[[ -t 2 ]] && live=1

	_ci_status_close() {
		if [[ "$status_open" -eq 1 ]]; then
			printf '\n' >&2
			status_open=0
		fi
	}

	_ci_waiting_line() {
		local e="$1"
		if [[ "$live" -eq 1 ]]; then
			printf '\r  waiting for CI on %s… %ss   ' "${sha:0:12}" "$e" >&2
			status_open=1
		fi
	}

	trap '_ci_status_close; return 130' INT
	start="$(date +%s)"

	while true; do
		now="$(date +%s)"
		elapsed=$((now - start))
		if ((elapsed > timeout)); then
			_ci_status_close
			printf '  CI wait timed out after %ss\n' "$timeout" >&2
			return 1
		fi

		mapfile -t runs < <(gh_run_list_commit_status "$repo" "$sha" 50)

		if [[ ${#runs[@]} -eq 0 ]]; then
			_ci_waiting_line "$elapsed"
			sleep 15
			continue
		fi

		pending=0
		failed=0
		for line in "${runs[@]}"; do
			[[ -z "$line" ]] && continue
			st="${line%%$'\t'*}"
			conc="${line#*$'\t'}"
			name="${conc#*$'\t'}"
			conc="${conc%%$'\t'*}"
			case "${st,,}" in
				completed)
					case "${conc,,}" in
						success|skipped|neutral) ;;
						*) failed=1 ;;
					esac
					;;
				*) pending=1 ;;
			esac
		done

		if [[ "$failed" -eq 1 ]]; then
			_ci_status_close
			printf '  CI failed for %s\n' "${sha:0:12}" >&2
			return 1
		fi
		if [[ "$pending" -eq 0 ]]; then
			_ci_status_close
			return 0
		fi
		_ci_waiting_line "$elapsed"
		sleep 15
	done
}

# =============================================================================
# Releases
# =============================================================================

# -----------------------------------------------------------------------------
# gh_release_list
# -----------------------------------------------------------------------------
# @brief GitHub Releases (not plain tags).
# @param[in] 1  owner/repo
# @param[in] 2  Limit (default: 200)
# @stdout       tag<TAB>name<TAB>isPrerelease<TAB>publishedAt<TAB>url
gh_release_list() {
	local repo="$1" limit="${2:-200}"
	[[ -n "$repo" ]] || return 0
	gh release list -R "$repo" --limit "$limit" \
		--json tagName,name,isPrerelease,publishedAt,url \
		--jq '.[] | "\(.tagName)\t\(.name // "")\t\(.isPrerelease)\t\(.publishedAt // "-")\t\(.url // "")"' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_release_exists
# -----------------------------------------------------------------------------
# @brief Whether a GitHub Release exists for a tag.
# @param[in] 1  owner/repo
# @param[in] 2  Tag
# @return 0 if present.
gh_release_exists() {
	local repo="$1" tag="$2"
	[[ -n "$repo" && -n "$tag" ]] || return 1
	gh release view "$tag" -R "$repo" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_release_delete
# -----------------------------------------------------------------------------
# @brief Delete a GitHub Release (git tags are not touched).
# @param[in] 1  owner/repo
# @param[in] 2  Tag
gh_release_delete() {
	local repo="$1" tag="$2"
	[[ -n "$repo" && -n "$tag" ]] || return 1
	gh release delete "$tag" -R "$repo" --yes >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_release_create
# -----------------------------------------------------------------------------
# @brief Create a GitHub Release from a notes file.
# @param[in] 1  owner/repo
# @param[in] 2  Tag
# @param[in] 3  Title
# @param[in] 4  Path to notes file
# @param[in] 5  "1" to mark prerelease (optional)
gh_release_create() {
	local repo="$1" tag="$2" title="$3" notes="$4" pre="${5:-0}"
	local -a extra=()
	[[ -n "$repo" && -n "$tag" && -n "$notes" ]] || return 1
	[[ "$pre" == "1" ]] && extra+=(--prerelease)
	gh release create "$tag" -R "$repo" \
		--title "$title" \
		--notes-file "$notes" \
		"${extra[@]}"
}

# =============================================================================
# Repositories / forks
# =============================================================================

# -----------------------------------------------------------------------------
# gh_repo_view_json
# -----------------------------------------------------------------------------
# @brief Thin wrapper around gh repo view --json.
# @param[in] 1  owner/repo
# @param[in] 2  JSON fields
# @param[in] 3  jq expression
gh_repo_view_json() {
	local repo="$1" fields="$2" jq="${3:-.}"
	[[ -n "$repo" && -n "$fields" ]] || return 1
	gh repo view "$repo" --json "$fields" --jq "$jq" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_repo_default_branch
# -----------------------------------------------------------------------------
# @brief Default branch of a GitHub repo (fallback: master).
# @param[in] 1  owner/repo
gh_repo_default_branch() {
	local b
	b="$(gh_repo_view_json "$1" defaultBranchRef '.defaultBranchRef.name')"
	printf '%s\n' "${b:-master}"
}

# -----------------------------------------------------------------------------
# gh_is_fork
# -----------------------------------------------------------------------------
# @brief Whether the GitHub repo is a fork.
# @param[in] 1  owner/repo
# @return 0 if fork.
gh_is_fork() {
	local is_fork
	is_fork="$(gh_repo_view_json "$1" isFork '.isFork')"
	[[ "$is_fork" == "true" ]]
}

# -----------------------------------------------------------------------------
# gh_fork_parent
# -----------------------------------------------------------------------------
# @brief Parent of a fork (owner/name). Empty if not a fork.
# @param[in] 1  owner/repo
gh_fork_parent() {
	local parent
	parent="$(gh_repo_view_json "$1" parent '.parent.owner.login + "/" + .parent.name')"
	[[ -n "$parent" && "$parent" != "null/null" ]] || return 1
	printf '%s\n' "$parent"
}

# -----------------------------------------------------------------------------
# gh_fork_compare
# -----------------------------------------------------------------------------
# @brief Behind/ahead versus the parent default branch.
# @param[in] 1  owner/repo (the fork)
# @stdout       "behind ahead"
gh_fork_compare() {
	local repo="$1" parent parent_owner default_branch fork_default cmp behind ahead

	parent="$(gh_fork_parent "$repo")" || return 1
	parent_owner="${parent%%/*}"
	default_branch="$(gh_repo_default_branch "$parent")"
	fork_default="$(gh_repo_default_branch "$repo")"

	cmp="$(gh api "repos/${repo}/compare/${parent_owner}:${default_branch}...${fork_default}" \
		--jq '{behind: .behind_by, ahead: .ahead_by}' 2>/dev/null || true)"
	[[ -n "$cmp" && "$cmp" != "null" ]] || return 1

	behind="$(printf '%s' "$cmp" | jq -r '.behind // 0')"
	ahead="$(printf '%s' "$cmp" | jq -r '.ahead // 0')"
	printf '%s %s\n' "$behind" "$ahead"
}

# -----------------------------------------------------------------------------
# gh_repo_sync
# -----------------------------------------------------------------------------
# @brief Remote-side "Sync fork" for one branch.
# @param[in] 1  owner/repo
# @param[in] 2  Branch (default: master)
gh_repo_sync() {
	local repo="$1" branch="${2:-master}"
	[[ -n "$repo" ]] || return 1
	gh repo sync "$repo" -b "$branch" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# gh_fork_sync_master
# -----------------------------------------------------------------------------
# @brief Sync only master on the remote, then pull --rebase locally.
#        Uses git_stash_if_dirty / git_checkout_branch / git_stash_pop_safe.
# @param[in] 1  Local clone
# @param[in] 2  owner/repo
# @return 0 on success.
gh_fork_sync_master() {
	local dir="$1" repo="$2"
	local current_branch stashed=0

	current_branch="$(git_current_branch "$dir")"
	[[ -z "$current_branch" ]] && return 1

	if git_stash_if_dirty "$dir" "StormByte fork-sync auto-stash"; then
		stashed=1
	fi

	if [[ "$current_branch" != "master" ]]; then
		git_checkout_branch "$dir" "master" || {
			[[ $stashed -eq 1 ]] && git_stash_pop_safe "$dir"
			return 1
		}
	fi

	gh_repo_sync "$repo" master || true
	git -C "$dir" pull --rebase origin master >/dev/null 2>&1 || true

	if [[ "$current_branch" != "master" ]]; then
		git -C "$dir" checkout "$current_branch" >/dev/null 2>&1 || true
	fi

	if [[ $stashed -eq 1 ]]; then
		git_stash_pop_safe "$dir" || true
	fi
	return 0
}

# -----------------------------------------------------------------------------
# gh_repo_list_public
# -----------------------------------------------------------------------------
# @brief Public repo names for an owner.
# @param[in] 1  Owner
# @param[in] 2  Limit (default: 1000)
# @stdout       One name per line.
gh_repo_list_public() {
	local owner="$1" limit="${2:-1000}"
	[[ -n "$owner" ]] || return 0
	gh repo list "$owner" --limit "$limit" --json name,isPrivate \
		--jq '.[] | select(.isPrivate == false) | .name' \
		2>/dev/null || true
}

# -----------------------------------------------------------------------------
# gh_repo_clone
# -----------------------------------------------------------------------------
# @brief Clone owner/name into dest.
# @param[in] 1  owner/name
# @param[in] 2  Destination directory
gh_repo_clone() {
	local id="$1" dest="$2"
	[[ -n "$id" && -n "$dest" ]] || return 1
	gh repo clone "$id" "$dest" >/dev/null 2>&1
}
