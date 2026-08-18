#!/usr/bin/env bash
# =============================================================================
# StormByte datacenter helpers — disk identity, multipath access, SES LEDs
# =============================================================================
# Library only. Sourced by StormByte-DataCenter (and legacy tools).
# All public names are intentional; keep this file free of CLI parsing.
#
# Identity keys may be:
#   - real WWN hex (no 0x) for SAS/SATA with WWN
#   - ata:<ata-by-id-name> for SATA without WWN
#   - node:sdX as last resort
# SES/LED matching applies only to real hex WWNs.
#
# Under multipath:
#   - by-id may point at dm-* (not sd*)
#   - zpool often uses mpath* leaf names
#   - access path prefers /dev/mapper/mpath*
# =============================================================================

[[ -n "${_STORMBYTE_FUNCTIONS_DATACENTER_LOADED:-}" ]] && return
readonly _STORMBYTE_FUNCTIONS_DATACENTER_LOADED=1

readonly STORMBYTE_FUNCTIONS_DATACENTER_VERSION="1.0.0"

: "${SMARTCTL_TIMEOUT:=10}"

# -----------------------------------------------------------------------------
# Globals filled by init_disk_maps
# -----------------------------------------------------------------------------
# SD_TO_WWN[sdX]           = identity key (WWN hex | ata:… | node:sdX)
# WWN_TO_SD[id]            = primary sd name (display fallback)
# WWN_ALIASES[id]          = space-separated aliases (scsi-*, wwn-*, ata-*, mpath*)
# ALIAS_TO_WWN[alias]      = identity key
# WWN_TO_ACCESS[id]        = best block path (mapper / by-id / /dev/sdX)
# WWN_TO_PATH_KIND[id]     = mapper | by-id | sd
# ALL_WWNS[]               = list of known identity keys
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

_dc_normalize_input() {
	local input="$1"

	input="${input#"${input%%[![:space:]]*}"}"
	input="${input%"${input##*[![:space:]]}"}"

	if [[ "$input" == /dev/disk/by-id/* ]]; then
		input="${input#/dev/disk/by-id/}"
	elif [[ "$input" == /dev/mapper/* ]]; then
		input="${input#/dev/mapper/}"
	elif [[ "$input" == /dev/* ]]; then
		input="${input#/dev/}"
	fi

	if [[ "$input" =~ ^(scsi|wwn|ata)-.+-part[0-9]+$ ]]; then
		input="${input%-part*}"
	fi

	printf '%s\n' "$input"
}

_dc_is_usable_block() {
	local path="$1"
	[[ -n "$path" && -b "$path" ]]
}

_dc_is_real_wwn() {
	local id="$1"
	[[ "$id" =~ ^[0-9a-fA-F]{16,}$ ]]
}

_dc_mpath_for_sd() {
	local sd="$1"
	local m h

	if [[ -d "/sys/block/$sd/holders" ]]; then
		for h in "/sys/block/$sd/holders"/dm-*; do
			[[ -e "$h" ]] || continue
			h="$(basename "$h")"
			for m in /dev/mapper/mpath*; do
				[[ -b "$m" ]] || continue
				if [[ "$(readlink -f "$m" 2>/dev/null)" == "/dev/$h" ]]; then
					printf '%s\n' "$m"
					return 0
				fi
			done
			for m in /dev/mapper/*; do
				[[ -b "$m" ]] || continue
				if [[ "$(readlink -f "$m" 2>/dev/null)" == "/dev/$h" ]]; then
					printf '%s\n' "$m"
					return 0
				fi
			done
			if [[ -b "/dev/$h" ]]; then
				printf '%s\n' "/dev/$h"
				return 0
			fi
		done
	fi
	return 1
}

_dc_pick_access() {
	local id="$1"
	local sd="$2"
	local aliases="${3:-}"
	local name path mpath

	if mpath="$(_dc_mpath_for_sd "$sd" 2>/dev/null)"; then
		if _dc_is_usable_block "$mpath"; then
			printf '%s\nmapper\n' "$mpath"
			return 0
		fi
	fi

	for name in $aliases; do
		[[ "$name" == mpath* ]] || continue
		path="/dev/mapper/$name"
		if _dc_is_usable_block "$path"; then
			printf '%s\nmapper\n' "$path"
			return 0
		fi
	done

	for name in $aliases; do
		[[ "$name" == wwn-* ]] || continue
		path="/dev/disk/by-id/$name"
		if _dc_is_usable_block "$path"; then
			printf '%s\nby-id\n' "$path"
			return 0
		fi
	done
	for name in $aliases; do
		[[ "$name" == scsi-* ]] || continue
		path="/dev/disk/by-id/$name"
		if _dc_is_usable_block "$path"; then
			printf '%s\nby-id\n' "$path"
			return 0
		fi
	done
	for name in $aliases; do
		[[ "$name" == ata-* ]] || continue
		path="/dev/disk/by-id/$name"
		if _dc_is_usable_block "$path"; then
			printf '%s\nby-id\n' "$path"
			return 0
		fi
	done

	if _dc_is_usable_block "/dev/$sd"; then
		printf '%s\nsd\n' "/dev/$sd"
		return 0
	fi

	return 1
}

_dc_synthetic_id_for_sd() {
	local sd="$1"
	local link name target

	shopt -s nullglob
	for link in /dev/disk/by-id/ata-*; do
		[[ -L "$link" ]] || continue
		name=$(basename "$link")
		[[ "$name" =~ -part[0-9]+$ ]] && continue
		target=$(readlink -f "$link" 2>/dev/null) || continue
		if [[ "$(basename "$target")" == "$sd" ]]; then
			shopt -u nullglob
			printf 'ata:%s\n' "$name"
			return 0
		fi
	done
	shopt -u nullglob
	printf 'node:%s\n' "$sd"
	return 0
}

_dc_add_alias() {
	local id="$1"
	local name="$2"

	[[ -n "$id" && -n "$name" ]] || return 0
	ALIAS_TO_WWN[$name]="$id"
	if [[ -v "WWN_ALIASES[$id]" ]]; then
		[[ " ${WWN_ALIASES[$id]} " == *" $name "* ]] || WWN_ALIASES[$id]+=" $name"
	else
		WWN_ALIASES[$id]="$name"
	fi
}

# by-id links that resolve to dm-* (typical under multipath)
_dc_map_byid_via_dm() {
	local _link _name _target _dm _wwn _id _slave _sd

	shopt -s nullglob
	for _link in /dev/disk/by-id/*; do
		[[ -L "$_link" ]] || continue
		_name=$(basename "$_link")
		[[ "$_name" == scsi-* || "$_name" == wwn-* || "$_name" == ata-* ]] || continue
		[[ "$_name" =~ -part[0-9]+$ ]] && continue
		_target=$(readlink -f "$_link" 2>/dev/null) || continue
		_dm=$(basename "$_target")
		[[ "$_dm" =~ ^dm- ]] || continue

		_wwn=$(lsblk -dno WWN "$_target" 2>/dev/null | head -1)
		if [[ -n "$_wwn" && "$_wwn" != "-" ]]; then
			_id="${_wwn#0x}"
			_id="${_id,,}"
		else
			_id=""
			for _slave in /sys/block/"$_dm"/slaves/*; do
				[[ -e "$_slave" ]] || continue
				_sd=$(basename "$_slave")
				[[ -v "SD_TO_WWN[$_sd]" ]] || continue
				_id="${SD_TO_WWN[$_sd]}"
				break
			done
			[[ -n "$_id" ]] || continue
		fi

		if [[ ! -v "WWN_TO_SD[$_id]" ]] || [[ -z "${WWN_TO_SD[$_id]:-}" ]]; then
			for _slave in /sys/block/"$_dm"/slaves/*; do
				[[ -e "$_slave" ]] || continue
				_sd=$(basename "$_slave")
				[[ "$_sd" =~ ^sd[a-z]+$ ]] || continue
				WWN_TO_SD[$_id]="$_sd"
				SD_TO_WWN[$_sd]="$_id"
				break
			done
			local found=0
			local e
			for e in "${ALL_WWNS[@]:-}"; do
				[[ "$e" == "$_id" ]] && { found=1; break; }
			done
			[[ "$found" -eq 0 ]] && ALL_WWNS+=("$_id")
		fi

		_dc_add_alias "$_id" "$_name"
	done
	shopt -u nullglob
}

# /dev/mapper/mpath* → slave sd* → identity; mpath name becomes alias + access
_dc_map_multipath_aliases() {
	local mpath base dm slaves_dir slave sd id

	shopt -s nullglob
	for mpath in /dev/mapper/mpath*; do
		[[ -b "$mpath" ]] || continue
		base=$(basename "$mpath")
		dm=$(readlink -f "$mpath" 2>/dev/null) || continue
		dm=$(basename "$dm")
		slaves_dir="/sys/block/$dm/slaves"
		[[ -d "$slaves_dir" ]] || continue

		for slave in "$slaves_dir"/*; do
			[[ -e "$slave" ]] || continue
			sd=$(basename "$slave")
			[[ "$sd" =~ ^sd[a-z]+$ ]] || continue

			if [[ -v "SD_TO_WWN[$sd]" ]]; then
				id="${SD_TO_WWN[$sd]}"
			else
				# Discover WWN from mapper node
				local _wwn
				_wwn=$(lsblk -dno WWN "$mpath" 2>/dev/null | head -1)
				if [[ -n "$_wwn" && "$_wwn" != "-" ]]; then
					id="${_wwn#0x}"
					id="${id,,}"
				else
					id="$(_dc_synthetic_id_for_sd "$sd")"
				fi
				SD_TO_WWN[$sd]="$id"
				if [[ ! -v "WWN_TO_SD[$id]" ]] || [[ -z "${WWN_TO_SD[$id]:-}" ]]; then
					WWN_TO_SD[$id]="$sd"
				fi
				local found=0 e
				for e in "${ALL_WWNS[@]:-}"; do
					[[ "$e" == "$id" ]] && { found=1; break; }
				done
				[[ "$found" -eq 0 ]] && ALL_WWNS+=("$id")
			fi

			_dc_add_alias "$id" "$base"

			if _dc_is_usable_block "$mpath"; then
				WWN_TO_ACCESS[$id]="$mpath"
				WWN_TO_PATH_KIND[$id]="mapper"
			fi
		done
	done
	shopt -u nullglob
}

# -----------------------------------------------------------------------------
# init_disk_maps
# -----------------------------------------------------------------------------
init_disk_maps() {
	declare -gA SD_TO_WWN=()
	declare -gA WWN_TO_SD=()
	declare -gA WWN_ALIASES=()
	declare -gA ALIAS_TO_WWN=()
	declare -gA WWN_TO_ACCESS=()
	declare -gA WWN_TO_PATH_KIND=()
	declare -ga ALL_WWNS=()

	local _line _sd _wwn _id _link _name _target _access _kind _dev

	# Phase 1: every sd* from lsblk (WWN optional)
	while IFS= read -r _line; do
		[[ -z "$_line" ]] && continue
		_sd=$(awk '{print $1}' <<< "$_line")
		_wwn=$(awk '{print $2}' <<< "$_line")
		[[ "$_sd" =~ ^sd[a-z]+$ ]] || continue

		if [[ -n "$_wwn" && "$_wwn" != "-" ]]; then
			_id="${_wwn#0x}"
			_id="${_id,,}"
		else
			_id="$(_dc_synthetic_id_for_sd "$_sd")"
		fi

		SD_TO_WWN[$_sd]="$_id"
		if [[ ! -v "WWN_TO_SD[$_id]" ]]; then
			WWN_TO_SD[$_id]="$_sd"
			ALL_WWNS+=("$_id")
		fi
	done < <(lsblk -dno NAME,WWN 2>/dev/null)

	# Phase 1b: sd* nodes not listed by lsblk
	shopt -s nullglob
	for _dev in /dev/sd[a-z] /dev/sd[a-z][a-z] /dev/sd[a-z][a-z][a-z]; do
		[[ -b "$_dev" ]] || continue
		_sd=$(basename "$_dev")
		[[ -v "SD_TO_WWN[$_sd]" ]] && continue
		_id="$(_dc_synthetic_id_for_sd "$_sd")"
		SD_TO_WWN[$_sd]="$_id"
		if [[ ! -v "WWN_TO_SD[$_id]" ]]; then
			WWN_TO_SD[$_id]="$_sd"
			ALL_WWNS+=("$_id")
		fi
	done
	shopt -u nullglob

	# Phase 2: by-id aliases that still point at sd*
	for _link in /dev/disk/by-id/*; do
		[[ -L "$_link" ]] || continue
		_name=$(basename "$_link")
		[[ "$_name" == scsi-* || "$_name" == wwn-* || "$_name" == ata-* ]] || continue
		[[ "$_name" =~ -part[0-9]+$ ]] && continue
		_target=$(readlink -f "$_link" 2>/dev/null) || continue
		_sd=$(basename "$_target")

		if [[ "$_sd" =~ ^sd[a-z]+$ ]]; then
			if [[ -v "SD_TO_WWN[$_sd]" ]]; then
				_id="${SD_TO_WWN[$_sd]}"
			else
				_id="$(_dc_synthetic_id_for_sd "$_sd")"
				SD_TO_WWN[$_sd]="$_id"
				if [[ ! -v "WWN_TO_SD[$_id]" ]]; then
					WWN_TO_SD[$_id]="$_sd"
					ALL_WWNS+=("$_id")
				fi
			fi
			_dc_add_alias "$_id" "$_name"
		fi
		# dm-* targets handled in phase 4
	done

	# sdX as resolvable aliases
	for _sd in "${!SD_TO_WWN[@]}"; do
		ALIAS_TO_WWN[$_sd]="${SD_TO_WWN[$_sd]}"
	done

	# Phase 3: initial access path per identity
	for _id in "${ALL_WWNS[@]}"; do
		_sd="${WWN_TO_SD[$_id]:-}"
		[[ -n "$_sd" ]] || continue
		if read -r _access _kind < <(_dc_pick_access "$_id" "$_sd" "${WWN_ALIASES[$_id]:-}"); then
			WWN_TO_ACCESS[$_id]="$_access"
			WWN_TO_PATH_KIND[$_id]="$_kind"
		else
			WWN_TO_ACCESS[$_id]="/dev/$_sd"
			WWN_TO_PATH_KIND[$_id]="sd"
		fi
	done

	# Phase 4: multipath reality (by-id→dm, mpath↔sd)
	_dc_map_byid_via_dm
	_dc_map_multipath_aliases

	# Phase 5: refresh access for anything still on raw sd when mapper exists
	for _id in "${ALL_WWNS[@]}"; do
		_sd="${WWN_TO_SD[$_id]:-}"
		[[ -n "$_sd" ]] || continue
		if [[ "${WWN_TO_PATH_KIND[$_id]:-}" != "mapper" ]]; then
			if read -r _access _kind < <(_dc_pick_access "$_id" "$_sd" "${WWN_ALIASES[$_id]:-}"); then
				WWN_TO_ACCESS[$_id]="$_access"
				WWN_TO_PATH_KIND[$_id]="$_kind"
			fi
		fi
	done
}

# -----------------------------------------------------------------------------
# Resolution API
# -----------------------------------------------------------------------------

resolve_to_wwn() {
	local input
	input="$(_dc_normalize_input "$1")"

	if [[ "$input" =~ ^sd[a-z]+$ ]]; then
		[[ -v "SD_TO_WWN[$input]" ]] && { echo "${SD_TO_WWN[$input]}"; return 0; }
		return 1
	fi

	# multipath leaf name
	if [[ "$input" == mpath* ]]; then
		[[ -v "ALIAS_TO_WWN[$input]" ]] && { echo "${ALIAS_TO_WWN[$input]}"; return 0; }
		return 1
	fi

	if [[ "$input" =~ ^[0-9a-fA-F]{16,}$ ]]; then
		echo "${input,,}"
		return 0
	fi

	if [[ "$input" == wwn-0x* ]]; then
		echo "${input#wwn-0x}"
		return 0
	fi
	if [[ "$input" == wwn-* ]]; then
		local rest="${input#wwn-}"
		rest="${rest#0x}"
		echo "$rest"
		return 0
	fi

	if [[ "$input" == ata-* ]]; then
		if [[ -v "ALIAS_TO_WWN[$input]" ]]; then
			echo "${ALIAS_TO_WWN[$input]}"
			return 0
		fi
		echo "ata:$input"
		return 0
	fi

	[[ -v "ALIAS_TO_WWN[$input]" ]] && { echo "${ALIAS_TO_WWN[$input]}"; return 0; }

	if [[ "$input" == ata:* || "$input" == node:* ]]; then
		[[ -v "WWN_TO_SD[$input]" ]] && { echo "$input"; return 0; }
	fi

	return 1
}

resolve_to_sd() {
	local input id
	input="$(_dc_normalize_input "$1")"

	if [[ "$input" =~ ^sd[a-z]+$ ]]; then
		echo "$input"
		return 0
	fi

	id=$(resolve_to_wwn "$input") || return 1
	[[ -v "WWN_TO_SD[$id]" && -n "${WWN_TO_SD[$id]}" ]] && {
		echo "${WWN_TO_SD[$id]}"
		return 0
	}
	return 1
}

resolve_to_access_dev() {
	local input id path sd name
	input="$(_dc_normalize_input "$1")"

	id=$(resolve_to_wwn "$input") || return 1

	if [[ -v "WWN_TO_ACCESS[$id]" && -n "${WWN_TO_ACCESS[$id]}" ]]; then
		path="${WWN_TO_ACCESS[$id]}"
		if _dc_is_usable_block "$path"; then
			echo "$path"
			return 0
		fi
		sd="${WWN_TO_SD[$id]:-}"
		if [[ -n "$sd" ]]; then
			if read -r path _ < <(_dc_pick_access "$id" "$sd" "${WWN_ALIASES[$id]:-}"); then
				echo "$path"
				return 0
			fi
		fi
	fi

	for name in ${WWN_ALIASES[$id]:-}; do
		if [[ "$name" == mpath* ]] && _dc_is_usable_block "/dev/mapper/$name"; then
			echo "/dev/mapper/$name"
			return 0
		fi
		if _dc_is_usable_block "/dev/disk/by-id/$name"; then
			echo "/dev/disk/by-id/$name"
			return 0
		fi
	done

	sd="${WWN_TO_SD[$id]:-}"
	if [[ -n "$sd" && -b "/dev/$sd" ]]; then
		echo "/dev/$sd"
		return 0
	fi
	return 1
}

resolve_path_kind() {
	local id
	id=$(resolve_to_wwn "$1") || { echo "unknown"; return 1; }
	echo "${WWN_TO_PATH_KIND[$id]:-unknown}"
}

# -----------------------------------------------------------------------------
# SAS ↔ WWN (real hex only)
# -----------------------------------------------------------------------------

resolve_sas_to_wwn() {
	local sas_addr="$1"
	local sas_clean="${sas_addr#0x}"
	local sas_prefix="${sas_clean%?}"
	local sas_last=$((16#${sas_clean: -1}))
	local wwn wwn_last

	for wwn in "${ALL_WWNS[@]}"; do
		_dc_is_real_wwn "$wwn" || continue
		[[ "${wwn%?}" == "$sas_prefix" ]] || continue
		wwn_last=$((16#${wwn: -1}))
		if (( sas_last == (wwn_last + 1) % 16 || sas_last == (wwn_last + 2) % 16 )); then
			echo "$wwn"
			return 0
		fi
	done
	for wwn in "${ALL_WWNS[@]}"; do
		_dc_is_real_wwn "$wwn" || continue
		[[ "${wwn%?}" == "$sas_prefix" ]] || continue
		echo "$wwn"
		return 0
	done
	return 1
}

resolve_sas_to_ids() {
	local sas_addr="$1"
	local wwn sd aliases scsi_id wwn_id

	wwn=$(resolve_sas_to_wwn "$sas_addr") || {
		echo "??? sas-$sas_addr"
		return 1
	}
	sd="${WWN_TO_SD[$wwn]:-???}"
	aliases="${WWN_ALIASES[$wwn]:-}"
	scsi_id=$(grep -oE 'scsi-[^ ]+' <<< "$aliases" | head -1)
	wwn_id=$(grep -oE 'wwn-[^ ]+' <<< "$aliases" | head -1)
	[[ -z "$scsi_id" ]] && scsi_id="N/A"
	[[ -z "$wwn_id" ]] && wwn_id="wwn-0x${wwn}"
	echo "$sd $scsi_id $wwn_id"
}

extract_wwn() {
	local disk="$1"
	local id access wwn

	id=$(resolve_to_wwn "$disk" 2>/dev/null) && { echo "$id"; return 0; }

	access=$(resolve_to_access_dev "$disk" 2>/dev/null) || access=""
	if [[ -n "$access" ]]; then
		wwn=$(lsblk -dno WWN "$access" 2>/dev/null | sed 's/^0x//' | head -1)
		if [[ -n "$wwn" && "$wwn" != "-" ]]; then
			echo "${wwn,,}"
			return 0
		fi
	fi

	echo "Error: could not determine identity for: $disk" >&2
	return 1
}

# -----------------------------------------------------------------------------
# Enclosure / SES
# -----------------------------------------------------------------------------

find_slot_by_wwn_prefix() {
	local wwn_prefix="$1"
	SLOT_DIR=""
	SLOT_ENC=""
	SLOT_SAS=""
	SLOT_NAME=""

	local enc_dir slot_dir slot_sas slot_sas_clean slot_prefix
	for enc_dir in /sys/class/enclosure/*/; do
		[[ -d "$enc_dir" ]] || continue
		for slot_dir in "$enc_dir"*/; do
			[[ -d "$slot_dir" ]] || continue
			[[ -f "$slot_dir/locate" ]] || continue
			[[ -f "$slot_dir/device/sas_address" ]] || continue
			slot_sas=$(<"$slot_dir/device/sas_address")
			slot_sas_clean="${slot_sas#0x}"
			slot_prefix="${slot_sas_clean%?}"
			if [[ "$slot_prefix" == "$wwn_prefix" ]]; then
				SLOT_DIR="${slot_dir%/}"
				SLOT_ENC=$(basename "$(dirname "$slot_dir")")
				SLOT_SAS="$slot_sas"
				SLOT_NAME=$(basename "$slot_dir")
				return 0
			fi
		done
	done
	return 1
}

get_enclosure_slot() {
	local input="$1"
	local id prefix

	id=$(resolve_to_wwn "$input" 2>/dev/null) || {
		echo "N/A"
		return 0
	}

	if ! _dc_is_real_wwn "$id"; then
		echo "N/A"
		return 0
	fi

	prefix="${id%?}"
	[[ -n "$prefix" ]] || { echo "N/A"; return 0; }

	if find_slot_by_wwn_prefix "$prefix"; then
		echo "${SLOT_ENC}/Slot${SLOT_NAME}"
	else
		echo "N/A"
	fi
}

enclosure_sort_key() {
	local input="$1"
	local slot enc name id
	slot=$(get_enclosure_slot "$input")
	id=$(resolve_to_wwn "$input" 2>/dev/null || echo "")
	if [[ "$slot" == "N/A" || -z "$slot" ]]; then
		printf 'ZZZZ|9999|%s\n' "$id"
		return 0
	fi
	enc="${slot%%/*}"
	name="${slot##*Slot}"
	printf '%s|%04d|%s\n' "$enc" "$((10#$name))" "$id"
}

led_status() {
	local input="$1"
	local v id prefix

	if [[ -d "$input" && -f "$input/locate" ]]; then
		v=$(<"$input/locate")
		[[ "$v" == "1" ]] && { echo "ON"; return 0; }
		echo "OFF"
		return 0
	fi

	input="$(_dc_normalize_input "$input")"
	id=$(resolve_to_wwn "$input" 2>/dev/null) || true

	if [[ -z "$id" && ( "$input" =~ ^0x[0-9a-fA-F]+$ || "$input" =~ ^[0-9a-fA-F]+$ ) ]]; then
		id=$(resolve_sas_to_wwn "$input" 2>/dev/null) || true
	fi

	if [[ -n "$id" ]] && _dc_is_real_wwn "$id"; then
		prefix="${id%?}"
		if find_slot_by_wwn_prefix "$prefix"; then
			[[ -f "$SLOT_DIR/locate" ]] || { echo "N/A"; return 0; }
			v=$(<"$SLOT_DIR/locate")
			[[ "$v" == "1" ]] && { echo "ON"; return 0; }
			echo "OFF"
			return 0
		fi
	fi

	echo "N/A"
}

led_set() {
	local input="$1"
	local value="$2"
	local id prefix

	if [[ -d "$input" && -f "$input/locate" ]]; then
		echo "$value" >"$input/locate"
		return $?
	fi

	id=$(extract_wwn "$input") || return 1
	if ! _dc_is_real_wwn "$id"; then
		echo "Error: device has no SES enclosure slot (not a SAS/WWN disk): $input" >&2
		return 1
	fi
	prefix="${id%?}"
	find_slot_by_wwn_prefix "$prefix" || return 1
	echo "$value" >"$SLOT_DIR/locate"
}

# -----------------------------------------------------------------------------
# SMART helpers
# -----------------------------------------------------------------------------

smartctl_query() {
	local input="$1"
	local access="" sd="" id="" out="" try_dev

	if [[ -b "$input" ]]; then
		access="$input"
	else
		access=$(resolve_to_access_dev "$input") || return 1
	fi

	_dc_smartctl_run() {
		local dev="$1"
		shift
		# "$@" = extra args before device, e.g. -d scsi
		if command -v timeout >/dev/null 2>&1; then
			timeout "$SMARTCTL_TIMEOUT" smartctl "$@" -a "$dev" 2>/dev/null || true
		else
			smartctl "$@" -a "$dev" 2>/dev/null || true
		fi
	}

	_dc_smartctl_ok() {
		local text="$1"
		[[ -n "$text" ]] || return 1
		grep -qi 'Unable to detect device type' <<<"$text" && return 1
		grep -qiE 'START OF|SMART Health|SMART overall|Device Model|Product:' <<<"$text"
	}

	# Prefer underlying sd* when maps are available (most reliable under multipath)
	id=$(resolve_to_wwn "$input" 2>/dev/null) || id=""
	if [[ -n "$id" && -v "WWN_TO_SD[$id]" && -n "${WWN_TO_SD[$id]:-}" ]]; then
		sd="/dev/${WWN_TO_SD[$id]}"
		if [[ -b "$sd" ]]; then
			out="$(_dc_smartctl_run "$sd")"
			if _dc_smartctl_ok "$out"; then
				printf '%s' "$out"
				return 0
			fi
			out="$(_dc_smartctl_run "$sd" -d scsi)"
			if _dc_smartctl_ok "$out"; then
				printf '%s' "$out"
				return 0
			fi
		fi
	fi

	# Access path: mapper always needs -d scsi
	try_dev="$access"
	if [[ "$try_dev" == /dev/mapper/* || "$(basename "$try_dev")" == mpath* ]]; then
		out="$(_dc_smartctl_run "$try_dev" -d scsi)"
		if _dc_smartctl_ok "$out"; then
			printf '%s' "$out"
			return 0
		fi
	else
		out="$(_dc_smartctl_run "$try_dev")"
		if _dc_smartctl_ok "$out"; then
			printf '%s' "$out"
			return 0
		fi
		out="$(_dc_smartctl_run "$try_dev" -d scsi)"
		if _dc_smartctl_ok "$out"; then
			printf '%s' "$out"
			return 0
		fi
	fi

	printf '%s' "${out:-}"
	return 0
}

smart_status_from_output() {
	local output="$1"
	[[ -z "$output" ]] && { echo "N/A"; return; }

	if grep -qiE 'SMART overall-health[^\n]*PASSED' <<<"$output"; then
		echo "PASSED"
		return
	fi
	if grep -qiE 'SMART overall-health[^\n]*FAILED' <<<"$output"; then
		echo "FAILED"
		return
	fi
	if grep -qiE 'SMART Health Status:\s*OK' <<<"$output"; then
		echo "PASSED"
		return
	fi
	if grep -qiE 'SMART Health Status:\s*(FAILED|FAILURE|CRITICAL)' <<<"$output"; then
		echo "FAILED"
		return
	fi
	if grep -qiE 'SMART overall-health|SMART Health Status' <<<"$output"; then
		echo "WARN"
		return
	fi
	echo "N/A"
}

smart_temperature_from_output() {
	local output="$1"
	local temp
	[[ -z "$output" ]] && { echo "N/A"; return; }
	temp=$(grep -i 'Current Drive Temperature' <<<"$output" | awk '{for(i=1;i<=NF;i++) if($i+0==$i) print $i}' | head -1)
	if [[ -z "$temp" ]]; then
		temp=$(awk '/^194 / {print $10}' <<<"$output" | head -1)
	fi
	if [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]]; then
		echo "${temp}C"
	else
		echo "N/A"
	fi
}

smart_health_from_output() {
	local output="$1"
	local ssd_life realloc_val defects
	[[ -z "$output" ]] && { echo "N/A"; return; }

	ssd_life=$(awk '/^231 / {print $10}' <<<"$output" | head -1)
	if [[ -n "$ssd_life" && "$ssd_life" =~ ^[0-9]+$ ]]; then
		echo "${ssd_life}%"
		return
	fi

	realloc_val=$(awk '/^  5 / {print $4}' <<<"$output" | head -1)
	if [[ -n "$realloc_val" && "$realloc_val" =~ ^[0-9]+$ ]]; then
		[[ "$realloc_val" -gt 100 ]] && realloc_val=100
		echo "${realloc_val}%"
		return
	fi

	defects=$(grep -i 'Elements in grown defect list' <<<"$output" | awk '{print $NF}')
	if [[ -n "$defects" && "$defects" =~ ^[0-9]+$ ]]; then
		if [[ "$defects" -eq 0 ]]; then
			echo "100%"
		else
			echo "${defects}d"
		fi
		return
	fi

	echo "N/A"
}

get_transport_type() {
	local input="$1"
	local sd dev_path

	sd=$(resolve_to_sd "$input" 2>/dev/null) || sd="$(_dc_normalize_input "$input")"
	dev_path=$(readlink -f "/sys/block/$sd/device" 2>/dev/null) || { echo "N/A"; return; }
	if [[ "$dev_path" == */ata* ]]; then
		echo "SATA"
	elif [[ "$dev_path" == */expander-* || "$dev_path" == */port-* ]]; then
		echo "SAS"
	else
		echo "N/A"
	fi
}

get_link_speed() {
	local input="$1"
	local sd dev_path port_dir phy_link phy_name rate output sata_speed

	sd=$(resolve_to_sd "$input" 2>/dev/null) || sd=""
	if [[ -n "$sd" ]]; then
		dev_path=$(readlink -f "/sys/block/$sd/device" 2>/dev/null)
		if [[ -n "$dev_path" ]]; then
			port_dir=$(grep -oE '.*/port-[0-9:]+' <<<"$dev_path" || true)
			if [[ -n "$port_dir" ]]; then
				phy_link=$(ls -d "$port_dir"/phy-* 2>/dev/null | head -1)
				if [[ -n "$phy_link" ]]; then
					phy_name=$(basename "$phy_link")
					rate=$(cat "/sys/class/sas_phy/$phy_name/negotiated_linkrate" 2>/dev/null || true)
					if [[ -n "$rate" && "$rate" != "unknown" ]]; then
						echo "$rate"
						return
					fi
				fi
			fi
		fi
	fi

	output=$(smartctl_query "$input")
	if [[ -n "$output" ]]; then
		sata_speed=$(grep -i 'SATA Version' <<<"$output" | grep -oE 'current: [0-9.]+ Gb/s' | awk '{print $2 " " $3}')
		if [[ -n "$sata_speed" ]]; then
			echo "$sata_speed"
			return
		fi
	fi
	echo "N/A"
}

# Pool membership: by-id aliases AND mpath* names used by zpool
is_in_pool_status() {
	local id="$1"
	local pool_status="$2"
	local alias access base
	[[ -z "$pool_status" ]] && return 1

	if [[ -v "WWN_ALIASES[$id]" ]]; then
		for alias in ${WWN_ALIASES[$id]}; do
			grep -qwF "$alias" <<<"$pool_status" && return 0
		done
	fi

	if [[ -v "WWN_TO_ACCESS[$id]" ]]; then
		access="${WWN_TO_ACCESS[$id]}"
		base=$(basename "$access")
		grep -qwF "$base" <<<"$pool_status" && return 0
	fi

	if _dc_is_real_wwn "$id"; then
		grep -qwF "wwn-0x${id}" <<<"$pool_status" && return 0
		grep -qwF "wwn-${id}" <<<"$pool_status" && return 0
	fi
	return 1
}