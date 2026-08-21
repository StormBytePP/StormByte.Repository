#!/usr/bin/env bash
# =============================================================================
# StormByte Git helpers library
# =============================================================================
# Source after functions.sh (>= 1.3.0).
# Git and local repo only. GitHub API lives in gh.sh.
# Pin policy (git_sm_plan):
#   A  branch=<name> in .gitmodules  → float to origin/<name>
#      --latest does not override a declared branch
#   B1 no branch= + recognised tag   → latest STABLE in family
#      (leave an _rc even if the number is lower)
#   B2 no branch= + not a tag        → latest stable of inferred family
# --latest (CLI): same prefix as the seed; do not promote rc if seed is
# stable; if seed is rc, move to a newer rc/stable of that prefix, never
# to another prefix (version- ≠ v).
# Parse: find [0-9]+([._][0-9]+){1,2} in the bare name (2 or 3 parts).
# One-component only for explicit table rows (postgres REL_18).
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_GIT_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_GIT_LOADED=1

readonly STORMBYTE_FUNCTIONS_GIT_VERSION="1.3.1"
readonly _STORMBYTE_FUNCTIONS_GIT_NEED_FUNCTIONS="1.3.0"

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

readonly GIT_SHADOW_TAGS="refs/sb-gh/tags"
readonly GIT_SHADOW_HEADS="refs/sb-gh/heads"

# -----------------------------------------------------------------------------
# git
# -----------------------------------------------------------------------------
# @brief Force C locale on every git invocation from this shell.
# @param[in] …  Arguments forwarded to git(1).
git() {
	LC_ALL=C LANG=C command git "$@"
}

# -----------------------------------------------------------------------------
# git_shell_quote
# -----------------------------------------------------------------------------
# @brief Quote a string for safe embedding in a shell command line.
# @param[in] 1  Raw string.
# @stdout       printf %q form.
git_shell_quote() {
	printf '%q' "$1"
}

# =============================================================================
# Repository facts
# =============================================================================

# -----------------------------------------------------------------------------
# git_current_branch
# -----------------------------------------------------------------------------
# @brief Current branch name, or HEAD when detached.
# @param[in] 1  Repository path (default: .).
# @stdout       Name or empty.
git_current_branch() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# git_head_sha
# -----------------------------------------------------------------------------
# @brief Short SHA of HEAD.
# @param[in] 1  Repository path (default: .).
git_head_sha() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse --short HEAD 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# git_head_sha_full
# -----------------------------------------------------------------------------
# @brief Full SHA of HEAD.
# @param[in] 1  Repository path (default: .).
git_head_sha_full() {
	local dir="${1:-.}"
	git -C "$dir" rev-parse HEAD 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# git_is_dirty
# -----------------------------------------------------------------------------
# @brief Whether the worktree or index has uncommitted changes.
# @param[in] 1  Repository path (default: .).
# @return 0 if dirty.
git_is_dirty() {
	local dir="${1:-.}"
	[[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]
}

# -----------------------------------------------------------------------------
# git_object_exists
# -----------------------------------------------------------------------------
# @brief Whether an object or peeled ref exists.
# @param[in] 1  Repository path.
# @param[in] 2  SHA or ref.
# @return 0 if present.
git_object_exists() {
	local dir="$1" spec="$2"
	[[ -n "$dir" && -n "$spec" ]] || return 1
	git -C "$dir" cat-file -e "${spec}^{object}" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_peel_ref
# -----------------------------------------------------------------------------
# @brief Resolve a ref to the commit it points at.
# @param[in] 1  Repository path.
# @param[in] 2  Ref (tag, branch, shadow, …).
# @stdout       Full SHA.
# @return 0 if the ref exists.
git_peel_ref() {
	local repo="$1" ref="$2"
	[[ -n "$repo" && -n "$ref" ]] || return 1
	git -C "$repo" rev-parse --verify "${ref}^{}" 2>/dev/null
}

# -----------------------------------------------------------------------------
# git_ref_basename
# -----------------------------------------------------------------------------
# @brief Strip refs/{tags,heads,remotes/origin,sb-gh/*}/ and origin/.
# @param[in] 1  Ref or tag name.
# @stdout       Bare name.
git_ref_basename() {
	local ref="${1:-}"
	ref="${ref#refs/sb-gh/tags/}"
	ref="${ref#refs/sb-gh/heads/}"
	ref="${ref#refs/tags/}"
	ref="${ref#refs/heads/}"
	ref="${ref#refs/remotes/origin/}"
	ref="${ref#origin/}"
	printf '%s\n' "$ref"
}

# =============================================================================
# Stash
# =============================================================================

# -----------------------------------------------------------------------------
# git_stash_if_dirty
# -----------------------------------------------------------------------------
# @brief Stash tracked and untracked changes when dirty.
# @param[in] 1  Repository path (default: .).
# @param[in] 2  Stash message.
# @return 0 if a stash was created.
git_stash_if_dirty() {
	local dir="${1:-.}"
	local msg="${2:-StormByte auto-stash}"

	if git_is_dirty "$dir"; then
		git -C "$dir" stash push -u -m "$msg" >/dev/null 2>&1
		return $?
	fi
	return 1
}

# -----------------------------------------------------------------------------
# git_stash_pop_safe
# -----------------------------------------------------------------------------
# @brief Pop the latest stash. Conflicts are reported; caller is not aborted.
# @param[in] 1  Repository path (default: .).
# @return 0 on a clean pop.
git_stash_pop_safe() {
	local dir="${1:-.}"

	if ! git -C "$dir" stash pop >/dev/null 2>&1; then
		printf "  ${_CLR_BOLD_YELLOW}WARNING${_CLR_RESET} ${_CLR_DIM}│${_CLR_RESET} stash pop produced conflicts in %s — resolve manually\n" "$dir" >&2
		return 1
	fi
	return 0
}

# =============================================================================
# Branches / tracking
# =============================================================================

# -----------------------------------------------------------------------------
# git_checkout_branch
# -----------------------------------------------------------------------------
# @brief Check out a local branch, creating it from origin/<branch> if needed.
# @param[in] 1  Repository path (default: .).
# @param[in] 2  Branch (default: master).
git_checkout_branch() {
	local dir="${1:-.}"
	local branch="${2:-master}"

	if git -C "$dir" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$dir" checkout "$branch" >/dev/null 2>&1
	else
		git -C "$dir" checkout -B "$branch" "origin/$branch" >/dev/null 2>&1 || \
		git -C "$dir" checkout -B "$branch" >/dev/null 2>&1
	fi
}

# -----------------------------------------------------------------------------
# git_upstream_ref
# -----------------------------------------------------------------------------
# @brief Upstream tracking ref of the current branch (e.g. origin/master).
# @param[in] 1  Repository path (default: .).
# @stdout       Ref name.
# @return 0 if configured.
git_upstream_ref() {
	local dir="${1:-.}"
	local up
	up="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || return 1
	[[ -n "$up" ]] || return 1
	printf '%s\n' "$up"
}

# -----------------------------------------------------------------------------
# git_ahead_behind
# -----------------------------------------------------------------------------
# @brief Ahead/behind versus the current branch upstream.
# @param[in] 1  Repository path (default: .).
# @stdout       "ahead behind"
git_ahead_behind() {
	local dir="${1:-.}"
	local counts ahead behind
	git_upstream_ref "$dir" >/dev/null || return 1
	counts="$(git -C "$dir" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)" || return 1
	ahead="${counts%%[$'\t ]*}"
	behind="${counts##*[$'\t ]}"
	[[ "$ahead" =~ ^[0-9]+$ && "$behind" =~ ^[0-9]+$ ]] || return 1
	printf '%s %s\n' "$ahead" "$behind"
}

# -----------------------------------------------------------------------------
# git_merge_tree_clean
# -----------------------------------------------------------------------------
# @brief Whether merging head into base would be conflict-free (no checkout).
# @param[in] 1  Repository path.
# @param[in] 2  Base ref.
# @param[in] 3  Head ref.
# @return 0 if merge-tree succeeds.
git_merge_tree_clean() {
	local dir="${1:-.}" base="${2:-}" head="${3:-}"
	[[ -n "$base" && -n "$head" ]] || return 1
	git -C "$dir" rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || return 1
	git -C "$dir" rev-parse --verify "$head^{commit}" >/dev/null 2>&1 || return 1
	git -C "$dir" merge-tree --write-tree "$base" "$head" >/dev/null 2>&1
}

# =============================================================================
# Remote identity
# =============================================================================

# -----------------------------------------------------------------------------
# git_canonical_repo_id
# -----------------------------------------------------------------------------
# @brief Normalise a URL or owner/repo to lowercase owner/repo.
# @param[in] 1  URL or owner/repo.
# @stdout       owner/repo
# @return 0 if parsed.
git_canonical_repo_id() {
	local url="$1" id
	id="$(printf '%s' "$url" | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')"
	[[ -z "$id" || "$id" != */* ]] && return 1
	printf '%s\n' "${id,,}"
}

# -----------------------------------------------------------------------------
# git_remote_repo
# -----------------------------------------------------------------------------
# @brief owner/repo of origin.
# @param[in] 1  Repository path (default: .).
# @stdout       owner/repo (case from the URL).
git_remote_repo() {
	local dir="${1:-.}" url
	url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || return 1
	printf '%s' "$url" | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#'
}

# -----------------------------------------------------------------------------
# git_remote_owner
# -----------------------------------------------------------------------------
# @brief Owner component of origin.
# @param[in] 1  Repository path.
git_remote_owner() {
	local repo
	repo="$(git_remote_repo "$1")" || return 1
	printf '%s\n' "${repo%%/*}"
}

# -----------------------------------------------------------------------------
# git_remote_name
# -----------------------------------------------------------------------------
# @brief Repository-name component of origin.
# @param[in] 1  Repository path.
git_remote_name() {
	local repo
	repo="$(git_remote_repo "$1")" || return 1
	printf '%s\n' "${repo##*/}"
}

# -----------------------------------------------------------------------------
# git_owner_matches
# -----------------------------------------------------------------------------
# @brief Whether origin owner equals expected (case-insensitive).
# @param[in] 1  Repository path.
# @param[in] 2  Expected owner.
# @return 0 on match.
git_owner_matches() {
	local actual
	actual="$(git_remote_owner "$1")" || return 1
	[[ "${actual,,}" == "${2,,}" ]]
}

# -----------------------------------------------------------------------------
# git_resolve_repo
# -----------------------------------------------------------------------------
# @brief Validate a directory as a git clone belonging to expected owner.
# @param[in] 1  Directory.
# @param[in] 2  Expected owner.
# @stdout       owner/repo
# @return 0 on success; errors on stderr.
git_resolve_repo() {
	local dir="$1" expected_owner="$2" repo owner
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

# =============================================================================
# .gitmodules
# =============================================================================

# -----------------------------------------------------------------------------
# git_submodule_path_is_safe
# -----------------------------------------------------------------------------
# @brief Relative path with no ".." — safe for submodule add/rm.
# @param[in] 1  Path.
# @return 0 if safe.
git_submodule_path_is_safe() {
	local path="$1"
	[[ -n "$path" ]] || return 1
	[[ "$path" == /* ]] && return 1
	[[ "$path" == *..* ]] && return 1
	return 0
}

# -----------------------------------------------------------------------------
# git_has_submodules
# -----------------------------------------------------------------------------
# @brief Whether .gitmodules lists at least one URL.
# @param[in] 1  Superproject (default: .).
# @return 0 if present.
git_has_submodules() {
	local file="${1:-.}/.gitmodules"
	[[ -f "$file" ]] || return 1
	git config --file "$file" --get-regexp '^submodule\..*\.url$' >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_gitmodules_list
# -----------------------------------------------------------------------------
# @brief First-level submodule rows.
# @param[in] 1  Superproject (default: .).
# @stdout       name<TAB>path<TAB>url
git_gitmodules_list() {
	local dir="${1:-.}" file="$dir/.gitmodules" names name path url
	[[ -f "$file" ]] || return 0
	mapfile -t names < <(
		git config --file "$file" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null \
			| sed -E 's/^submodule\.(.*)\.path$/\1/' || true
	)
	for name in "${names[@]:-}"; do
		[[ -z "$name" ]] && continue
		path="$(git config --file "$file" --get "submodule.${name}.path" 2>/dev/null || true)"
		url="$(git config --file "$file" --get "submodule.${name}.url" 2>/dev/null || true)"
		printf '%s\t%s\t%s\n' "$name" "${path:-}" "${url:-}"
	done
}

# -----------------------------------------------------------------------------
# git_gitmodules_branch
# -----------------------------------------------------------------------------
# @brief branch= for a named submodule (bare), or empty.
# @param[in] 1  Superproject.
# @param[in] 2  Submodule name.
git_gitmodules_branch() {
	local dir="${1:-.}" name="$2" branch
	branch="$(git -C "$dir" config -f .gitmodules --get "submodule.${name}.branch" 2>/dev/null || true)"
	git_ref_basename "$branch"
}

# -----------------------------------------------------------------------------
# git_gitmodules_find_by_name
# -----------------------------------------------------------------------------
# @brief Find a submodule by exact name.
# @param[in] 1  Superproject.
# @param[in] 2  Name.
# @stdout       name<TAB>path<TAB>url
git_gitmodules_find_by_name() {
	local dir="${1:-.}" want="$2" name path url
	[[ -n "$want" ]] || return 1
	while IFS=$'\t' read -r name path url; do
		[[ "$name" == "$want" ]] && { printf '%s\t%s\t%s\n' "$name" "$path" "$url"; return 0; }
	done < <(git_gitmodules_list "$dir")
	return 1
}

# -----------------------------------------------------------------------------
# git_gitmodules_find_by_url
# -----------------------------------------------------------------------------
# @brief Find a submodule by exact URL.
# @param[in] 1  Superproject.
# @param[in] 2  URL.
# @stdout       name<TAB>path<TAB>url
git_gitmodules_find_by_url() {
	local dir="${1:-.}" want="$2" name path url
	[[ -n "$want" ]] || return 1
	while IFS=$'\t' read -r name path url; do
		[[ "$url" == "$want" ]] && { printf '%s\t%s\t%s\n' "$name" "$path" "$url"; return 0; }
	done < <(git_gitmodules_list "$dir")
	return 1
}

# -----------------------------------------------------------------------------
# git_gitmodules_find_by_path
# -----------------------------------------------------------------------------
# @brief Find a submodule by exact relative path.
# @param[in] 1  Superproject.
# @param[in] 2  Path (must be safe).
# @stdout       name<TAB>path<TAB>url
git_gitmodules_find_by_path() {
	local dir="${1:-.}" want="$2" name path url
	[[ -n "$want" ]] || return 1
	git_submodule_path_is_safe "$want" || return 1
	while IFS=$'\t' read -r name path url; do
		[[ "$path" == "$want" ]] && { printf '%s\t%s\t%s\n' "$name" "$path" "$url"; return 0; }
	done < <(git_gitmodules_list "$dir")
	return 1
}

# -----------------------------------------------------------------------------
# git_sm_gitlink_sha
# -----------------------------------------------------------------------------
# @brief SHA recorded in the superproject for a submodule path.
# @param[in] 1  Superproject.
# @param[in] 2  Relative path.
git_sm_gitlink_sha() {
	local parent="$1" path="$2"
	[[ -n "$parent" && -n "$path" ]] || return 0
	git -C "$parent" rev-parse "HEAD:${path}" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# git_submodule_resolve_branch
# -----------------------------------------------------------------------------
# @brief Preferred → HEAD → origin/HEAD → main → master.
# @param[in] 1  Submodule path.
# @param[in] 2  Preferred branch (optional).
# @stdout       Branch name.
git_submodule_resolve_branch() {
	local sm_dir="$1" preferred="${2:-}" branch=""
	[[ -d "$sm_dir" ]] || return 1
	[[ -n "$preferred" ]] && branch="$preferred"
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

# -----------------------------------------------------------------------------
# git_submodule_force_to_remote_tip
# -----------------------------------------------------------------------------
# @brief Force one submodule worktree to origin/<branch>.
# @param[in] 1  Submodule path.
# @param[in] 2  Preferred branch (optional).
git_submodule_force_to_remote_tip() {
	local sm_dir="$1" preferred="${2:-}" branch
	[[ -d "$sm_dir" ]] || return 1
	git -C "$sm_dir" remote get-url origin >/dev/null 2>&1 || return 1
	git -C "$sm_dir" fetch origin --prune --force >/dev/null 2>&1 || return 1
	branch="$(git_submodule_resolve_branch "$sm_dir" "$preferred")" || return 1
	if ! git -C "$sm_dir" rev-parse --verify "refs/remotes/origin/${branch}" >/dev/null 2>&1; then
		branch="$(git_submodule_resolve_branch "$sm_dir" "")" || return 1
	fi
	git -C "$sm_dir" rev-parse --verify "refs/remotes/origin/${branch}" >/dev/null 2>&1 || return 1
	git -C "$sm_dir" checkout -B "$branch" "refs/remotes/origin/${branch}" >/dev/null 2>&1 || return 1
	git -C "$sm_dir" reset --hard "refs/remotes/origin/${branch}" >/dev/null 2>&1 || return 1
	git -C "$sm_dir" clean -fd >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# git_submodules_force_all_to_remote
# -----------------------------------------------------------------------------
# @brief Force every submodule (recursive) to its remote branch tip.
# @param[in] 1  Superproject (default: .).
# @stdout       "→ name: ok|skip"
git_submodules_force_all_to_remote() {
	local dir="${1:-.}" toplevel name sm_abs preferred
	[[ -f "$dir/.gitmodules" ]] || return 0
	git -C "$dir" submodule update --init --recursive >/dev/null 2>&1 || true
	while IFS=$'\t' read -r toplevel name sm_abs; do
		[[ -z "$sm_abs" || ! -d "$sm_abs" ]] && continue
		preferred=""
		if [[ -n "$toplevel" && -f "$toplevel/.gitmodules" && -n "$name" ]]; then
			preferred="$(git config -f "$toplevel/.gitmodules" --get "submodule.${name}.branch" 2>/dev/null || true)"
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
}

# =============================================================================
# Tags / CHANGELOG
# =============================================================================

# -----------------------------------------------------------------------------
# git_latest_tag
# -----------------------------------------------------------------------------
# @brief Latest local tag by version sort.
# @param[in] 1  Repository path (default: .).
git_latest_tag() {
	local dir="${1:-.}"
	git -C "$dir" tag -l --sort=-v:refname 2>/dev/null | head -n1 || true
}

# -----------------------------------------------------------------------------
# git_tag_exists_local
# -----------------------------------------------------------------------------
# @brief Whether a tag exists locally.
# @param[in] 1  Repository path.
# @param[in] 2  Tag name.
git_tag_exists_local() {
	local dir="${1:-.}" tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_tag_exists_remote
# -----------------------------------------------------------------------------
# @brief Whether a tag exists on origin.
# @param[in] 1  Repository path.
# @param[in] 2  Tag name.
git_tag_exists_remote() {
	local dir="${1:-.}" tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q .
}

# -----------------------------------------------------------------------------
# git_tag_delete_local_remote
# -----------------------------------------------------------------------------
# @brief Delete a tag locally and on origin (best-effort).
# @param[in] 1  Repository path.
# @param[in] 2  Tag name.
git_tag_delete_local_remote() {
	local dir="${1:-.}" tag="${2:-}"
	[[ -n "$tag" ]] || return 1
	git -C "$dir" tag -d "$tag" >/dev/null 2>&1 || true
	git -C "$dir" push origin ":refs/tags/$tag" >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# git_fetch_origin_tags
# -----------------------------------------------------------------------------
# @brief Fetch origin tags and prune stale tag refs.
# @param[in] 1  Repository path.
git_fetch_origin_tags() {
	git -C "$1" fetch origin --tags --prune --force --prune-tags >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_changelog_extract_notes
# -----------------------------------------------------------------------------
# @brief Keep-a-Changelog body for a version (delegates to functions.sh).
# @param[in] 1  Path to CHANGELOG.md.
# @param[in] 2  Version (v optional).
git_changelog_extract_notes() {
	changelog_extract_notes "$1" "$2"
}

# =============================================================================
# Shadow refs
# =============================================================================

# -----------------------------------------------------------------------------
# git_shadow_fetch
# -----------------------------------------------------------------------------
# @brief Mirror origin heads/tags into refs/sb-gh/{heads,tags}.
# @param[in] 1  Repository path (submodule worktree).
git_shadow_fetch() {
	local repo="$1"
	[[ -n "$repo" && -d "$repo" ]] || return 1
	git -C "$repo" fetch origin --prune \
		"+refs/heads/*:${GIT_SHADOW_HEADS}/*" \
		"+refs/tags/*:${GIT_SHADOW_TAGS}/*" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_shadow_delete
# -----------------------------------------------------------------------------
# @brief Delete every ref under refs/sb-gh.
# @param[in] 1  Repository path.
git_shadow_delete() {
	local repo="$1" ref
	[[ -n "$repo" && -d "$repo" ]] || return 0
	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		git -C "$repo" update-ref -d "$ref" >/dev/null 2>&1 || true
	done < <(git -C "$repo" for-each-ref --format='%(refname)' refs/sb-gh 2>/dev/null)
}

# -----------------------------------------------------------------------------
# git_list_tag_names
# -----------------------------------------------------------------------------
# @brief Bare names under a ref prefix (default refs/tags; use refs/sb-gh/tags).
# @param[in] 1  Repository path.
# @param[in] 2  Prefix (default: refs/tags).
git_list_tag_names() {
	local repo="$1" prefix="${2:-refs/tags}" ref
	prefix="${prefix%/}"
	[[ -n "$repo" && -d "$repo" ]] || return 0
	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		printf '%s\n' "${ref#${prefix}/}"
	done < <(git -C "$repo" for-each-ref --format='%(refname)' "$prefix" 2>/dev/null)
}

# -----------------------------------------------------------------------------
# git_list_tag_names_union
# -----------------------------------------------------------------------------
# @brief Unique bare names from shadow prefix and refs/tags.
# @param[in] 1  Repository path.
# @param[in] 2  First prefix (default $GIT_SHADOW_TAGS).
git_list_tag_names_union() {
	local repo="$1" prefix="${2:-$GIT_SHADOW_TAGS}"
	local n
	local -A seen=()

	[[ -n "$repo" && -d "$repo" ]] || return 0
	prefix="${prefix%/}"

	while IFS= read -r n; do
		[[ -z "$n" ]] && continue
		seen["$n"]=1
	done < <(
		git_list_tag_names "$repo" "$prefix"
		git_list_tag_names "$repo" "refs/tags"
	)

	for n in "${!seen[@]}"; do
		printf '%s\n' "$n"
	done
}

# -----------------------------------------------------------------------------
# git_list_tags
# -----------------------------------------------------------------------------
# @brief Local tag names.
# @param[in] 1  Repository path.
git_list_tags() {
	git -C "$1" tag --list 2>/dev/null | sed '/^$/d'
}

# -----------------------------------------------------------------------------
# git_list_origin_branches
# -----------------------------------------------------------------------------
# @brief Remote branch names without origin/.
# @param[in] 1  Repository path.
git_list_origin_branches() {
	local dir="$1" line
	git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
		| while IFS= read -r line; do
			[[ "$line" == origin/* ]] || continue
			[[ "$line" == origin/HEAD ]] && continue
			git_ref_basename "$line"
		done
}

# =============================================================================
# Pin schemes
# =============================================================================
# Table: id|prefix|sep|grain|ignore
#   prefix  literal, empty (optional v + dotted), or * (capture identifier)
#   grain   major | major.minor | auto
#   ignore  unused for generic rows; postgres still strips STABLE/ALPHA/…

# -----------------------------------------------------------------------------
# git_pin_scheme_table
# -----------------------------------------------------------------------------
# @brief Scheme catalogue. First match wins.
# @stdout One row per line: id|prefix|sep|grain|ignore
git_pin_scheme_table() {
	cat <<'EOF'
postgres|REL_|_|major|STABLE|ALPHA|BETA|RC
cryptopp|CRYPTOPP_|_|major.minor|
generic_uscore|*|_|auto|
dash_semver|*|-|auto|
semver||.|major.minor|
EOF
}

# -----------------------------------------------------------------------------
# git_ref_is_unstable
# -----------------------------------------------------------------------------
# @brief Pre-release / snapshot. Case-insensitive.
# @param[in] 1  Bare name.
# @return 0 if unstable (must not be a --latest dest unless seed is also rc).
git_ref_is_unstable() {
	local name low
	name="$(git_ref_basename "${1:-}")"
	low="${name,,}"
	[[ "$low" =~ (alpha|beta|rc|pre|preview|snapshot|nightly|canary|wip|tmp|test) ]] && return 0
	[[ "$low" =~ ^(draft|snap)[-._] ]] && return 0
	[[ "$low" =~ ^date- ]] && return 0
	[[ "$low" =~ ^[a-z]{1,4}-[0-9]{6,} ]] && return 0
	# Only leading 0.0.x — do NOT treat 2.0.0 / 4.0.0 as unstable
	[[ "$low" =~ ^v?0\.0(\.|$) ]] && return 0
	return 1
}

# -----------------------------------------------------------------------------
# git_pin_extract_version
# -----------------------------------------------------------------------------
# @brief First X.Y or X.Y.Z (dots or underscores) in a string.
# @param[in] 1  Rest of the tag after a prefix (or the whole tag).
# @stdout       major<TAB>minor<TAB>patch
# @return 0 if 2 or 3 numeric components.
git_pin_extract_version() {
	local rest="$1" chunk
	[[ "$rest" =~ ^v?([0-9]+[._-][0-9]+([._-][0-9]+)?) ]] || return 1
	chunk="${BASH_REMATCH[1]}"
	chunk="${chunk//_/.}"
	chunk="${chunk//-/.}"
	local -a n=()
	IFS=. read -r -a n <<<"$chunk"
	(( ${#n[@]} == 2 || ${#n[@]} == 3 )) || return 1
	printf '%s\t%s\t%s\n' "${n[0]}" "${n[1]}" "${n[2]:-0}"
}

# -----------------------------------------------------------------------------
# git_pin_parse
# -----------------------------------------------------------------------------
# @brief Classify a tag.
# @param[in] 1  Bare tag.
# @stdout scheme<TAB>prefix<TAB>major<TAB>minor<TAB>patch<TAB>family<TAB>raw
# @return 0 if classified.
# @note Generic dash/underscore rows require 2 or 3 numeric parts after the
#       identifier (bzip2-1.0.8, meson-8.1, Speex-1.2.1, release-3.0.6,
#       version-2.11.1-rc). A trailing unstable word is allowed.
#       postgres may be one component (REL_18).
git_pin_parse() {
	local raw="$1" id prefix sep grain ignore rest ver
	local major minor patch fam_extra family

	raw="$(git_ref_basename "$raw")"
	[[ -n "$raw" ]] || return 1

	while IFS='|' read -r id prefix sep grain ignore; do
		[[ -z "$id" || "$id" == \#* ]] && continue
		rest=""
		case "$prefix" in
			"")
				[[ "$raw" =~ ^v?([0-9]+(\.[0-9]+){1,2})$ ]] || continue
				rest="${raw#v}"
				prefix=""
				;;
			"*")
				[[ -n "$sep" ]] || continue
				if [[ "$sep" == "_" ]]; then
					[[ "$raw" =~ ^([A-Za-z][A-Za-z0-9]*)_(.+)$ ]] || continue
				else
					[[ "$raw" =~ ^([A-Za-z][A-Za-z0-9]*)-(.+)$ ]] || continue
				fi
				prefix="${BASH_REMATCH[1]}${sep}"
				rest="${BASH_REMATCH[2]}"
				;;
			*)
				[[ "$raw" == "${prefix}"* ]] || continue
				rest="${raw#"$prefix"}"
				;;
		esac
		[[ -n "$rest" ]] || continue

		if [[ "$id" == "postgres" || "$id" == "cryptopp" ]]; then
			local tokens token token_ok=1
			local -a nums=()
			tokens="${rest//${sep}/ }"
			for token in $tokens; do
				if [[ -n "$ignore" && "${token^^}" =~ ${ignore} ]]; then
					continue
				fi
				if [[ "$token" =~ ^[0-9]+$ ]]; then
					nums+=("$token")
				else
					token_ok=0
					break
				fi
			done
			[[ "$token_ok" -eq 1 && ${#nums[@]} -ge 1 ]] || continue
			major="${nums[0]}"
			minor="${nums[1]:-0}"
			patch="${nums[2]:-0}"
		else
			ver="$(git_pin_extract_version "$rest")" || continue
			major="$(printf '%s' "$ver" | cut -f1)"
			minor="$(printf '%s' "$ver" | cut -f2)"
			patch="$(printf '%s' "$ver" | cut -f3)"
		fi

		if [[ "$grain" == "auto" ]]; then
			if [[ "$patch" != "0" ]]; then
				grain="major.minor"
			else
				grain="major"
			fi
		fi
		case "$grain" in
			major.minor) fam_extra="${major}.${minor}" ;;
			*)           fam_extra="$major" ;;
		esac
		family="${id}:${prefix}:${fam_extra}"
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$id" "$prefix" "$major" "$minor" "$patch" "$family" "$raw"
		return 0
	done < <(git_pin_scheme_table)
	return 1
}

# -----------------------------------------------------------------------------
# git_pin_family_key
# -----------------------------------------------------------------------------
# @brief Family key of a tag (scheme:prefix:grain).
# @param[in] 1  Bare tag.
git_pin_family_key() {
	local parsed
	parsed="$(git_pin_parse "$1")" || return 1
	printf '%s\n' "$(printf '%s' "$parsed" | cut -f6)"
}

# -----------------------------------------------------------------------------
# git_pin_sort_key
# -----------------------------------------------------------------------------
# @brief "major minor patch" after parse.
# @param[in] 1  Bare tag.
git_pin_sort_key() {
	local parsed maj min pat
	parsed="$(git_pin_parse "$1")" || return 1
	maj="$(printf '%s' "$parsed" | cut -f3)"
	min="$(printf '%s' "$parsed" | cut -f4)"
	pat="$(printf '%s' "$parsed" | cut -f5)"
	printf '%s %s %s\n' "$maj" "$min" "$pat"
}

# -----------------------------------------------------------------------------
# git_pin_same_family
# -----------------------------------------------------------------------------
# @brief Same scheme, prefix and grain.
# @param[in] 1  Tag A.
# @param[in] 2  Tag B.
git_pin_same_family() {
	local fa fb
	fa="$(git_pin_family_key "$1")" || return 1
	fb="$(git_pin_family_key "$2")" || return 1
	[[ "$fa" == "$fb" ]]
}

# -----------------------------------------------------------------------------
# git_exact_tag_at_sha
# -----------------------------------------------------------------------------
# @brief Prefer a classified tag at SHA; else first exact tag.
# @param[in] 1  Repository path.
# @param[in] 2  SHA.
# @stdout Tag name (may be empty).
git_exact_tag_at_sha() {
	local repo="$1" sha="$2" t best=""
	[[ -n "$repo" && -n "$sha" ]] || return 0
	while IFS= read -r t; do
		[[ -z "$t" ]] && continue
		if git_pin_parse "$t" >/dev/null; then
			printf '%s\n' "$t"
			return 0
		fi
		[[ -z "$best" ]] && best="$t"
	done < <(git -C "$repo" tag --points-at "$sha" 2>/dev/null)
	[[ -z "$best" ]] && best="$(git -C "$repo" describe --tags --exact-match "$sha" 2>/dev/null || true)"
	printf '%s' "$best"
}

# -----------------------------------------------------------------------------
# git_exact_tag_at_head
# -----------------------------------------------------------------------------
# @brief Classified or exact tag at HEAD.
# @param[in] 1  Repository path.
git_exact_tag_at_head() {
	local sha
	sha="$(git_head_sha_full "$1")"
	[[ -n "$sha" ]] || return 0
	git_exact_tag_at_sha "$1" "$sha"
}

# -----------------------------------------------------------------------------
# git_pin_next_in_family
# -----------------------------------------------------------------------------
# @brief Unique successor in the same family, or the pin if already latest.
# @param[in] 1  Repository path.
# @param[in] 2  Current tag.
# @param[in] 3  Ref prefix.
git_pin_next_in_family() {
	local repo="$1" pin="$2" prefix="${3:-refs/tags}"
	local pin_key cand ckey best="" best_key=""

	[[ -n "$repo" && -n "$pin" ]] || return 1
	pin="$(git_ref_basename "$pin")"
	git_pin_family_key "$pin" >/dev/null || return 1
	pin_key="$(git_pin_sort_key "$pin")" || return 1

	while IFS= read -r cand; do
		[[ -z "$cand" ]] && continue
		git_ref_is_unstable "$cand" && continue
		git_pin_same_family "$pin" "$cand" || continue
		ckey="$(git_pin_sort_key "$cand")" || continue
		if int_tuple_cmp "$pin_key" "$ckey"; then
			if [[ -z "$best" ]] || int_tuple_cmp "$ckey" "$best_key"; then
				best="$cand"
				best_key="$ckey"
			fi
		fi
	done < <(git_list_tag_names_union "$repo" "$prefix")

	if [[ -z "$best" ]]; then
		printf '%s' "$pin"
		return 0
	fi
	printf '%s' "$best"
}

# -----------------------------------------------------------------------------
# git_pin_latest_recognised
# -----------------------------------------------------------------------------
# @brief --latest destination.
# @param[in] 1  Repository path.
# @param[in] 2  Ref prefix (shadow or refs/tags). Union with refs/tags.
# @param[in] 3  Optional seed (current pin). Locks scheme+prefix.
# @stdout Tag name.
# @return 0 if printed.
# @note Seed stable → only stables of that prefix (never promote rc,
#       never jpeg-10 from 3.2.0, never v0.6.1 from meson-8.1).
#       Seed rc → same prefix, rc or stable allowed if sort key >= seed
#       (update the rc; do not drop to another prefix).
#       No seed → highest stable of any family.
git_pin_latest_recognised() {
	local repo="$1"
	local prefix="${2:-$GIT_SHADOW_TAGS}"
	local seed="${3:-}"
	local cand best="" best_key="" key parsed
	local seed_scheme="" seed_prefix="" seed_key="" seed_rc=0
	local c_scheme c_pfx

	[[ -n "$repo" && -d "$repo" ]] || return 1

	seed="$(git_ref_basename "$seed")"
	if [[ -n "$seed" ]]; then
		parsed="$(git_pin_parse "$seed" 2>/dev/null || true)"
		if [[ -n "$parsed" ]]; then
			seed_scheme="$(printf '%s' "$parsed" | cut -f1)"
			seed_prefix="$(printf '%s' "$parsed" | cut -f2)"
			seed_key="$(git_pin_sort_key "$seed" 2>/dev/null || true)"
			git_ref_is_unstable "$seed" && seed_rc=1
		fi
	fi

	while IFS= read -r cand; do
		[[ -z "$cand" ]] && continue
		parsed="$(git_pin_parse "$cand" 2>/dev/null || true)"
		[[ -n "$parsed" ]] || continue
		c_scheme="$(printf '%s' "$parsed" | cut -f1)"
		c_pfx="$(printf '%s' "$parsed" | cut -f2)"
		if [[ -n "$seed_scheme" ]]; then
			[[ "$c_scheme" == "$seed_scheme" ]] || continue
			[[ "$c_pfx" == "$seed_prefix" ]] || continue
		fi
		if [[ "$seed_rc" -eq 1 ]]; then
			key="$(git_pin_sort_key "$cand")" || continue
			if [[ -n "$seed_key" ]] && int_tuple_cmp "$key" "$seed_key"; then
				continue
			fi
		else
			git_ref_is_unstable "$cand" && continue
			key="$(git_pin_sort_key "$cand")" || continue
		fi
		if [[ -z "$best" ]] || int_tuple_cmp "$best_key" "$key"; then
			best="$cand"
			best_key="$key"
		fi
	done < <(git_list_tag_names_union "$repo" "$prefix")

	[[ -n "$best" ]] || return 1
	printf '%s\n' "$best"
}

# -----------------------------------------------------------------------------
# git_pin_latest_in_family
# -----------------------------------------------------------------------------
# @brief Highest STABLE tag in the family of <pin> (B1, including leave-rc).
# @param[in] 1  Repository path.
# @param[in] 2  Tag that identifies the family.
# @param[in] 3  Ref prefix.
git_pin_latest_in_family() {
	local repo="$1" pin="$2" prefix="${3:-$GIT_SHADOW_TAGS}"
	local cand ckey best="" best_key=""

	[[ -n "$repo" && -n "$pin" ]] || return 1
	pin="$(git_ref_basename "$pin")"
	git_pin_family_key "$pin" >/dev/null || return 1

	while IFS= read -r cand; do
		[[ -z "$cand" ]] && continue
		git_ref_is_unstable "$cand" && continue
		git_pin_same_family "$pin" "$cand" || continue
		ckey="$(git_pin_sort_key "$cand")" || continue
		if [[ -z "$best" ]] || int_tuple_cmp "$best_key" "$ckey"; then
			best="$cand"
			best_key="$ckey"
		fi
	done < <(git_list_tag_names_union "$repo" "$prefix")

	[[ -n "$best" ]] || return 1
	printf '%s' "$best"
}

# -----------------------------------------------------------------------------
# git_pin_newest_release
# -----------------------------------------------------------------------------
# @brief Most recently created classified stable tag (creator date).
# @param[in] 1  Repository path.
# @param[in] 2  Ref prefix.
git_pin_newest_release() {
	local repo="$1" prefix="${2:-refs/tags}" ref name
	prefix="${prefix%/}"
	[[ -n "$repo" ]] || return 1
	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		name="${ref#${prefix}/}"
		git_ref_is_unstable "$name" && continue
		if git_pin_parse "$name" >/dev/null; then
			printf '%s' "$name"
			return 0
		fi
	done < <(git -C "$repo" for-each-ref --sort=-creatordate --format='%(refname)' "$prefix" 2>/dev/null)
	return 1
}

# -----------------------------------------------------------------------------
# git_pin_infer_anchor
# -----------------------------------------------------------------------------
# @brief Family seed when HEAD is not on a tag.
# @param[in] 1  Repository path.
# @param[in] 2  Ref prefix.
git_pin_infer_anchor() {
	local repo="$1" prefix="${2:-refs/tags}" near
	near="$(git -C "$repo" describe --tags --abbrev=0 HEAD 2>/dev/null || true)"
	if [[ -n "$near" ]] && git_pin_parse "$near" >/dev/null; then
		printf '%s' "$near"
		return 0
	fi
	git_pin_newest_release "$repo" "$prefix"
}

# =============================================================================
# Submodule update policy
# =============================================================================

# -----------------------------------------------------------------------------
# git_sm_classify
# -----------------------------------------------------------------------------
# @brief Checkout identity only. Tag at SHA, else branch=, else sha.
# @param[in] 1  Superproject.
# @param[in] 2  Submodule name.
# @param[in] 3  Absolute submodule path.
# @stdout kind<TAB>label<TAB>sha
git_sm_classify() {
	local parent="$1" name="$2" abs="$3"
	local path branch sha tag
	path="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.path" 2>/dev/null || true)"
	branch="$(git_gitmodules_branch "$parent" "$name")"
	sha=""
	[[ -n "$path" ]] && sha="$(git_sm_gitlink_sha "$parent" "$path")"
	if [[ -z "$sha" ]] && { [[ -d "$abs/.git" ]] || [[ -f "$abs/.git" ]]; }; then
		sha="$(git -C "$abs" rev-parse HEAD 2>/dev/null || true)"
	fi
	tag="$(git_exact_tag_at_sha "$abs" "$sha")"
	if [[ -n "$tag" ]]; then
		printf 'tag\t%s\t%s\n' "$tag" "$sha"
		return 0
	fi
	if [[ -n "$branch" ]]; then
		printf 'branch\t%s\t%s\n' "$branch" "$sha"
		return 0
	fi
	printf 'sha\t%s\t%s\n' "${sha:0:7}" "$sha"
}

# -----------------------------------------------------------------------------
# git_sm_current_label
# -----------------------------------------------------------------------------
# @brief CURRENT column: tag/branch plus short SHA, or sha:…
# @param[in] 1  kind.
# @param[in] 2  label.
# @param[in] 3  full SHA.
git_sm_current_label() {
	local kind="$1" label="$2" sha="$3" short="${3:0:7}"
	case "$kind" in
		branch|tag) printf '%s (%s)' "$label" "$short" ;;
		*)          printf 'sha:%s' "$short" ;;
	esac
}

# -----------------------------------------------------------------------------
# git_sm_emit_plan
# -----------------------------------------------------------------------------
# @brief One plan row: action kind current planned target sha.
git_sm_emit_plan() {
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${1}" "${2}" "${3}" "${4}" "${5}" "${6}"
}

# -----------------------------------------------------------------------------
# git_sm_plan
# -----------------------------------------------------------------------------
# @brief Plan one first-level submodule. Caller should git_shadow_fetch first.
# @param[in] 1  Superproject.
# @param[in] 2  Submodule name.
# @param[in] 3  Absolute submodule path.
# @stdout action<TAB>kind<TAB>current<TAB>planned<TAB>target<TAB>sha
# @note A: any branch= floats to origin/<branch>. --latest must not override.
#       B1: classified tag → latest stable in family (leave rc).
#       B2: else inferred family / newest stable.
git_sm_plan() {
	local parent="$1" name="$2" abs="$3"
	local path gm_branch sha tag current tip latest latest_rc cmp_sha anchor
	local prefix="$GIT_SHADOW_TAGS"

	[[ -n "$parent" && -n "$name" && -n "$abs" ]] || return 1
	path="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.path" 2>/dev/null || true)"
	gm_branch="$(git_gitmodules_branch "$parent" "$name")"
	sha="$(git_sm_gitlink_sha "$parent" "$path")"
	[[ -z "$sha" ]] && sha="$(git -C "$abs" rev-parse HEAD 2>/dev/null || true)"
	tag="$(git_exact_tag_at_sha "$abs" "$sha")"

	if [[ -n "$gm_branch" ]]; then
		current="$(git_sm_current_label branch "$gm_branch" "$sha")"
		tip="$(git_peel_ref "$abs" "${GIT_SHADOW_HEADS}/${gm_branch}" 2>/dev/null || true)"
		[[ -z "$tip" ]] && tip="$(git_peel_ref "$abs" "refs/remotes/origin/${gm_branch}" 2>/dev/null || true)"
		if [[ -z "$tip" ]]; then
			git_sm_emit_plan "error" "branch" "$current" "missing origin/${gm_branch}" "" "$sha"
			return 0
		fi
		if [[ "$tip" == "$sha" ]]; then
			git_sm_emit_plan "keep" "branch" "$current" "No changes" "" "$sha"
		else
			git_sm_emit_plan "update" "branch" "$current" "${gm_branch} (${tip:0:7})" "$gm_branch" "$sha"
		fi
		return 0
	fi

	if [[ -n "$tag" ]]; then
		current="$(git_sm_current_label tag "$tag" "$sha")"
	else
		current="$(git_sm_current_label sha "" "$sha")"
	fi

	if [[ -n "$tag" ]] && git_pin_parse "$tag" >/dev/null; then
		latest_rc=0
		latest="$(git_pin_latest_in_family "$abs" "$tag" "$prefix")" || latest_rc=$?
		if (( latest_rc != 0 )) || [[ -z "$latest" ]]; then
			git_sm_emit_plan "skip" "tag" "$current" "UNRESOLVED" "" "$sha"
			return 0
		fi
		cmp_sha="$(git_peel_ref "$abs" "${prefix}/${latest}" 2>/dev/null || true)"
		[[ -z "$cmp_sha" ]] && cmp_sha="$(git_peel_ref "$abs" "refs/tags/${latest}" 2>/dev/null || true)"
		if [[ "$latest" == "$tag" ]]; then
			if [[ -n "$cmp_sha" && -n "$sha" && "$cmp_sha" != "$sha" ]]; then
				git_sm_emit_plan "rerelease" "tag" "$current" "re-release (${cmp_sha:0:7})" "$tag" "$sha"
			else
				git_sm_emit_plan "keep" "tag" "$current" "No changes" "" "$sha"
			fi
		else
			git_sm_emit_plan "update" "tag" "$current" "$latest" "$latest" "$sha"
		fi
		return 0
	fi

	if [[ -n "$tag" ]]; then
		git_sm_emit_plan "skip" "tag" "$current" "UNRESOLVED" "" "$sha"
		return 0
	fi

	anchor="$(git_pin_infer_anchor "$abs" "$prefix")" || anchor=""
	latest=""
	[[ -n "$anchor" ]] && latest="$(git_pin_latest_in_family "$abs" "$anchor" "$prefix" 2>/dev/null || true)"
	[[ -z "$latest" ]] && latest="$(git_pin_newest_release "$abs" "$prefix" 2>/dev/null || true)"
	if [[ -z "$latest" ]]; then
		git_sm_emit_plan "skip" "sha" "$current" "UNRESOLVED" "" "$sha"
		return 0
	fi
	cmp_sha="$(git_peel_ref "$abs" "${prefix}/${latest}" 2>/dev/null || true)"
	[[ -z "$cmp_sha" ]] && cmp_sha="$(git_peel_ref "$abs" "refs/tags/${latest}" 2>/dev/null || true)"
	if [[ -n "$cmp_sha" && "$cmp_sha" == "$sha" ]]; then
		git_sm_emit_plan "keep" "tag" "$(git_sm_current_label tag "$latest" "$sha")" "No changes" "" "$sha"
	else
		git_sm_emit_plan "update" "tag" "$current" "$latest" "$latest" "$sha"
	fi
}

# -----------------------------------------------------------------------------
# git_sm_checkout_branch
# -----------------------------------------------------------------------------
# @brief Float a submodule to origin/<branch>.
# @param[in] 1  Submodule path.
# @param[in] 2  Branch.
git_sm_checkout_branch() {
	local abs="$1" branch="$2"
	[[ -n "$abs" && -n "$branch" ]] || return 1
	git -C "$abs" fetch origin --prune >/dev/null 2>&1 || true
	git -C "$abs" checkout -B "$branch" "origin/${branch}" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_sm_checkout_tag
# -----------------------------------------------------------------------------
# @brief Detached checkout of a tag.
# @param[in] 1  Submodule path.
# @param[in] 2  Tag.
git_sm_checkout_tag() {
	local abs="$1" tag="$2"
	[[ -n "$abs" && -n "$tag" ]] || return 1
	git -C "$abs" fetch origin --tags --prune >/dev/null 2>&1 || true
	git -C "$abs" checkout --detach "$tag" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# git_sm_stage_gitlink
# -----------------------------------------------------------------------------
# @brief Stage one first-level gitlink at 160000 before nested sync.
# @param[in] 1  Superproject.
# @param[in] 2  Submodule path relative to the parent.
# @param[in] 3  Full SHA to record.
# @return 0 if the index now holds that SHA at path.
git_sm_stage_gitlink() {
	local parent="$1" path="$2" sha="$3" got
	[[ -n "$parent" && -n "$path" && -n "$sha" ]] || return 1
	git -C "$parent" update-index --cacheinfo "160000,${sha},${path}" || return 1
	got="$(git -C "$parent" rev-parse ":${path}" 2>/dev/null || true)"
	[[ "$got" == "$sha" ]]
}

# -----------------------------------------------------------------------------
# git_sm_stage_gitlinks
# -----------------------------------------------------------------------------
# @brief Stage only first-level submodule gitlinks (+ .gitmodules).
# @param[in] 1  Superproject.
git_sm_stage_gitlinks() {
	local dir="$1" name path url
	while IFS=$'\t' read -r name path url; do
		[[ -z "$path" ]] && continue
		git -C "$dir" add -- "$path" >/dev/null 2>&1 || true
	done < <(git_gitmodules_list "$dir")
	[[ -f "$dir/.gitmodules" ]] && git -C "$dir" add -- .gitmodules >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# git_sm_update_nested
# -----------------------------------------------------------------------------
# @brief Sync nested modules to recorded SHAs.
# @param[in] 1  Superproject.
git_sm_update_nested() {
	git -C "$1" submodule update --init --recursive
}

# =============================================================================
# Submodule details (read-only report)
# =============================================================================

# -----------------------------------------------------------------------------
# git_pin_semver_text
# -----------------------------------------------------------------------------
# @brief Compact X[.Y[.Z]] from a classified pin.
# @param[in] 1  Bare tag.
# @stdout       Semver text.
# @return 0 if classified.
git_pin_semver_text() {
	local parsed id maj min pat
	parsed="$(git_pin_parse "$1")" || return 1
	id="$(printf '%s' "$parsed" | cut -f1)"
	maj="$(printf '%s' "$parsed" | cut -f3)"
	min="$(printf '%s' "$parsed" | cut -f4)"
	pat="$(printf '%s' "$parsed" | cut -f5)"
	if [[ "$id" == "postgres" ]]; then
		if [[ "$min" != "0" ]]; then
			printf '%s.%s\n' "$maj" "$min"
		else
			printf '%s\n' "$maj"
		fi
		return 0
	fi
	printf '%s.%s.%s\n' "$maj" "$min" "$pat"
}

# -----------------------------------------------------------------------------
# git_pin_display_label
# -----------------------------------------------------------------------------
# @brief Tag/branch as shown in details. Parens only when ref ≠ semver.
# @param[in] 1  Bare ref.
# @stdout       Label (never empty if input is not).
git_pin_display_label() {
	local raw sem plain
	raw="$(git_ref_basename "${1:-}")"
	[[ -n "$raw" ]] || return 0
	sem="$(git_pin_semver_text "$raw" 2>/dev/null || true)"
	if [[ -z "$sem" ]]; then
		printf '%s\n' "$raw"
		return 0
	fi
	plain="$(version_plain "$raw")"
	if [[ "$raw" == "$sem" || "$plain" == "$sem" ]]; then
		printf '%s\n' "$raw"
		return 0
	fi
	printf '%s (%s)\n' "$raw" "$sem"
}

# -----------------------------------------------------------------------------
# git_sm_trunk_ref
# -----------------------------------------------------------------------------
# @brief origin/master, else origin/main, else matching shadow head.
# @param[in] 1  Repository path.
# @stdout       Ref that rev-parse accepts.
# @return 0 if found.
git_sm_trunk_ref() {
	local repo="$1" cand
	[[ -n "$repo" && -d "$repo" ]] || return 1
	for cand in origin/master origin/main \
		"${GIT_SHADOW_HEADS}/master" "${GIT_SHADOW_HEADS}/main"; do
		if git_peel_ref "$repo" "$cand" >/dev/null; then
			printf '%s\n' "$cand"
			return 0
		fi
	done
	return 1
}

# -----------------------------------------------------------------------------
# git_sm_details_trunk_tags
# -----------------------------------------------------------------------------
# @brief Classified stable tags whose commit is an ancestor of master/main.
# @param[in] 1  Repository path.
# @param[in] 2  Ref prefix (default: $GIT_SHADOW_TAGS).
# @stdout       One bare tag per line, semver order.
git_sm_details_trunk_tags() {
	local repo="$1"
	local prefix="${2:-$GIT_SHADOW_TAGS}"
	local seed="${3:-}"
	local trunk="" tip="" cand="" csha=""
	local seed_scheme="" seed_fam="" c_scheme="" c_fam=""
	local -a names=() keys=()
	local i j n tmpn tmpk have

	[[ -n "$repo" && -d "$repo" ]] || return 0

	if [[ -z "$(git -C "$repo" for-each-ref --format='%(refname)' "$prefix" 2>/dev/null | head -n 1)" ]]; then
		prefix="refs/tags"
	fi

	trunk="$(git_sm_trunk_ref "$repo" 2>/dev/null || true)"
	[[ -n "$trunk" ]] && tip="$(git_peel_ref "$repo" "$trunk" 2>/dev/null || true)"

	seed="$(git_ref_basename "$seed")"
	if [[ -n "$seed" ]] && git_pin_parse "$seed" >/dev/null; then
		seed_scheme="$(git_pin_parse "$seed" | cut -f1)"
		seed_fam="$(git_pin_family_key "$seed" 2>/dev/null || true)"
	fi

	_sm_details_collect() {
		local mode="$1"
		names=()
		keys=()
		while IFS= read -r cand; do
			[[ -z "$cand" ]] && continue
			git_ref_is_unstable "$cand" && continue
			git_pin_parse "$cand" >/dev/null || continue
			c_scheme="$(git_pin_parse "$cand" | cut -f1)"
			c_fam="$(git_pin_family_key "$cand" 2>/dev/null || true)"
			csha="$(git_peel_ref "$repo" "${prefix}/${cand}" 2>/dev/null \
				|| git_peel_ref "$repo" "refs/tags/${cand}" 2>/dev/null \
				|| true)"
			case "$mode" in
				family)
					[[ -n "$seed_fam" && "$c_fam" == "$seed_fam" ]] || continue
					;;
				scheme-trunk)
					[[ -n "$seed_scheme" && "$c_scheme" == "$seed_scheme" ]] || continue
					[[ -n "$tip" && -n "$csha" ]] || continue
					git -C "$repo" merge-base --is-ancestor "$csha" "$tip" 2>/dev/null || continue
					;;
				scheme)
					[[ -n "$seed_scheme" && "$c_scheme" == "$seed_scheme" ]] || continue
					;;
				trunk)
					[[ -n "$tip" && -n "$csha" ]] || continue
					git -C "$repo" merge-base --is-ancestor "$csha" "$tip" 2>/dev/null || continue
					;;
			esac
			names+=("$cand")
			keys+=("$(git_pin_sort_key "$cand")")
		done < <(git_list_tag_names "$repo" "$prefix")
	}

	if [[ -n "$seed_fam" ]]; then
		_sm_details_collect family
	fi
	if ((${#names[@]} == 0)) && [[ -n "$seed_scheme" && -n "$tip" ]]; then
		_sm_details_collect scheme-trunk
	fi
	if ((${#names[@]} == 0)) && [[ -n "$seed_scheme" ]]; then
		_sm_details_collect scheme
	fi
	if ((${#names[@]} == 0)); then
		_sm_details_collect trunk
	fi

	if [[ -n "$seed" ]] && git_pin_parse "$seed" >/dev/null; then
		have=0
		for cand in "${names[@]+"${names[@]}"}"; do
			[[ "$cand" == "$seed" ]] && have=1 && break
		done
		if [[ "$have" -eq 0 ]]; then
			names+=("$seed")
			keys+=("$(git_pin_sort_key "$seed" 2>/dev/null || echo "0 0 0")")
		fi
	fi

	n=${#names[@]}
	(( n == 0 )) && return 0
	for ((i = 0; i < n; i++)); do
		for ((j = i + 1; j < n; j++)); do
			if int_tuple_cmp "${keys[j]}" "${keys[i]}"; then
				tmpn="${names[i]}"; names[i]="${names[j]}"; names[j]="$tmpn"
				tmpk="${keys[i]}"; keys[i]="${keys[j]}"; keys[j]="$tmpk"
			fi
		done
	done
	for ((i = 0; i < n; i++)); do
		printf '%s\n' "${names[i]}"
	done
}

# -----------------------------------------------------------------------------
# git_sm_details_origin_branches
# -----------------------------------------------------------------------------
# @brief origin / shadow branch names (no HEAD).
# @param[in] 1  Repository path.
# @stdout       One bare name per line, sorted.
git_sm_details_origin_branches() {
	local repo="$1" ref name
	local -A seen=()
	[[ -n "$repo" && -d "$repo" ]] || return 0

	while IFS= read -r ref; do
		[[ -z "$ref" ]] && continue
		name="$(git_ref_basename "$ref")"
		[[ -z "$name" || "$name" == "HEAD" ]] && continue
		seen["$name"]=1
	done < <(git -C "$repo" for-each-ref --format='%(refname)' \
		refs/remotes/origin "${GIT_SHADOW_HEADS}" 2>/dev/null)

	for name in "${!seen[@]}"; do
		printf '%s\n' "$name"
	done | LC_ALL=C sort
}

# -----------------------------------------------------------------------------
# git_sm_details_line
# -----------------------------------------------------------------------------
# @brief One first-level details row. Caller should git_shadow_fetch first.
# @param[in] 1  Superproject.
# @param[in] 2  Submodule name.
# @param[in] 3  Absolute submodule path.
# @stdout       name<TAB>url<TAB>pin_shown<TAB>latest_shown<TAB>pin_raw<TAB>latest_raw
# @return 0 on success.
git_sm_details_line() {
	local parent="$1" name="$2" abs="$3"
	local path url kind label sha pin_raw latest_raw pin_shown latest_shown seed
	local prefix="$GIT_SHADOW_TAGS"

	[[ -n "$parent" && -n "$name" && -n "$abs" ]] || return 1

	path="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.path" 2>/dev/null || true)"
	url="$(git -C "$parent" config -f .gitmodules --get "submodule.${name}.url" 2>/dev/null || true)"

	IFS=$'\t' read -r kind label sha < <(git_sm_classify "$parent" "$name" "$abs")
	case "$kind" in
		tag)    pin_raw="$label" ;;
		branch) pin_raw="$label" ;;
		*)      pin_raw="sha:${sha:0:7}" ;;
	esac
	pin_shown="$(git_pin_display_label "$pin_raw")"
	if [[ "$kind" == "sha" ]]; then
		pin_shown="$pin_raw"
	fi

	seed=""
	if [[ "$kind" == "tag" ]]; then
		seed="$pin_raw"
	fi
	latest_raw="$(git_pin_latest_recognised "$abs" "$prefix" "$seed" 2>/dev/null || true)"
	if [[ -n "$latest_raw" ]]; then
		latest_shown="$(git_pin_display_label "$latest_raw")"
	else
		latest_shown="—"
		latest_raw=""
	fi

	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$name" "$url" "$pin_shown" "$latest_shown" "$pin_raw" "$latest_raw"
}
