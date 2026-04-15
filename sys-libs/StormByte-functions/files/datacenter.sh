#! /bin/bash

# Version 3.1.0

init_disk_maps() {
    declare -gA SD_TO_WWN
    declare -gA WWN_TO_SD
    declare -gA WWN_ALIASES
    declare -gA ALIAS_TO_WWN
    declare -ga ALL_WWNS=()

    local _line _sd _wwn _wwn_clean _link _name _target

    # Phase 1: discover sd↔WWN mapping from lsblk
    while IFS= read -r _line; do
        [[ -z "$_line" ]] && continue
        _sd=$(awk '{print $1}' <<< "$_line")
        _wwn=$(awk '{print $2}' <<< "$_line")
        [[ "$_sd" =~ ^sd[a-z]+$ ]] || continue
        [[ -n "$_wwn" ]] || continue
        _wwn_clean="${_wwn#0x}"
        SD_TO_WWN[$_sd]="$_wwn_clean"
        if [[ ! -v "WWN_TO_SD[$_wwn_clean]" ]]; then
            WWN_TO_SD[$_wwn_clean]="$_sd"
            ALL_WWNS+=("$_wwn_clean")
        fi
    done < <(lsblk -dno NAME,WWN 2>/dev/null)

    # Phase 2: collect by-id aliases (scsi-*, wwn-*, ata-*) per WWN
    for _link in /dev/disk/by-id/*; do
        [[ -L "$_link" ]] || continue
        _name=$(basename "$_link")
        [[ "$_name" == scsi-* || "$_name" == wwn-* || "$_name" == ata-* ]] || continue
        [[ "$_name" =~ -part[0-9]+$ ]] && continue
        _target=$(readlink -f "$_link" 2>/dev/null) || continue
        [[ -b "$_target" ]] || continue
        _sd=$(basename "$_target")
        [[ -v "SD_TO_WWN[$_sd]" ]] || continue
        _wwn_clean="${SD_TO_WWN[$_sd]}"
        ALIAS_TO_WWN[$_name]="$_wwn_clean"
        if [[ -v "WWN_ALIASES[$_wwn_clean]" ]]; then
            [[ " ${WWN_ALIASES[$_wwn_clean]} " =~ " $_name " ]] || WWN_ALIASES[$_wwn_clean]+=" $_name"
        else
            WWN_ALIASES[$_wwn_clean]="$_name"
        fi
    done

    # Register sdX names as resolvable aliases
    for _sd in "${!SD_TO_WWN[@]}"; do
        ALIAS_TO_WWN[$_sd]="${SD_TO_WWN[$_sd]}"
    done
}

resolve_to_wwn() {
    local input="$1"
    [[ "$input" == /dev/* ]] && input=$(basename "$input")
    if [[ "$input" =~ ^sd[a-z]+$ ]]; then
        [[ -v "SD_TO_WWN[$input]" ]] && { echo "${SD_TO_WWN[$input]}"; return; }
        return 1
    fi
    [[ "$input" == wwn-0x* ]] && { echo "${input#wwn-0x}"; return; }
    [[ "$input" == wwn-* ]]   && { echo "${input#wwn-}"; return; }
    [[ -v "ALIAS_TO_WWN[$input]" ]] && { echo "${ALIAS_TO_WWN[$input]}"; return; }
    return 1
}

resolve_to_sd() {
    local input="$1"
    [[ "$input" == /dev/* ]] && input=$(basename "$input")
    if [[ "$input" =~ ^sd[a-z]+$ ]]; then
        echo "$input"; return
    fi
    local wwn
    wwn=$(resolve_to_wwn "$input") || return 1
    [[ -v "WWN_TO_SD[$wwn]" ]] && { echo "${WWN_TO_SD[$wwn]}"; return; }
    return 1
}

resolve_sas_to_wwn() {
    local sas_addr="$1"
    local sas_clean="${sas_addr#0x}"
    local sas_prefix="${sas_clean%?}"
    local sas_last=$((16#${sas_clean: -1}))

    local wwn wwn_last
    # SAS port addresses are device_name+1 (phy 0) and device_name+2 (phy 1)
    for wwn in "${ALL_WWNS[@]}"; do
        [[ "${wwn%?}" == "$sas_prefix" ]] || continue
        wwn_last=$((16#${wwn: -1}))
        if (( sas_last == (wwn_last + 1) % 16 || sas_last == (wwn_last + 2) % 16 )); then
            echo "$wwn"
            return 0
        fi
    done
    # Fallback: first WWN matching by prefix
    for wwn in "${ALL_WWNS[@]}"; do
        [[ "${wwn%?}" == "$sas_prefix" ]] || continue
        echo "$wwn"
        return 0
    done
    return 1
}

resolve_sas_to_ids() {
    local sas_addr="$1"
    local sas_clean="${sas_addr#0x}"
    local sas_prefix="${sas_clean%?}"

    local wwn
    wwn=$(resolve_sas_to_wwn "$sas_addr") || true
    if [[ -n "$wwn" ]]; then
        local sd="${WWN_TO_SD[$wwn]}"
        local aliases="${WWN_ALIASES[$wwn]:-}"
        local scsi_id wwn_id
        scsi_id=$(grep -oE 'scsi-[^ ]+' <<< "$aliases" | head -1)
        wwn_id=$(grep -oE 'wwn-[^ ]+' <<< "$aliases" | head -1)
        [[ -z "$scsi_id" ]] && scsi_id="N/A"
        [[ -z "$wwn_id" ]] && wwn_id="wwn-0x${wwn}"
        echo "$sd $scsi_id $wwn_id"
        return
    fi

    # Legacy fallback: prefix-only matching
    for wwn in "${ALL_WWNS[@]}"; do
        if [[ "${wwn%?}" == "$sas_prefix" ]]; then
            local sd="${WWN_TO_SD[$wwn]}"
            local aliases="${WWN_ALIASES[$wwn]:-}"
            local scsi_id wwn_id
            scsi_id=$(grep -oE 'scsi-[^ ]+' <<< "$aliases" | head -1)
            wwn_id=$(grep -oE 'wwn-[^ ]+' <<< "$aliases" | head -1)
            [[ -z "$scsi_id" ]] && scsi_id="N/A"
            [[ -z "$wwn_id" ]] && wwn_id="wwn-0x${wwn}"
            echo "$sd $scsi_id $wwn_id"
            return
        fi
    done

    echo "??? sas-$sas_addr"
}

extract_wwn() {
    local disk="$1"
    local wwn
    wwn=$(resolve_to_wwn "$disk" 2>/dev/null) && { echo "$wwn"; return; }
    # Fallback for raw device names not yet in the map
    local dev="${disk#/dev/}"
    if [[ ! -b "/dev/$dev" ]]; then
        echo "Error: device does not exist: /dev/$dev" >&2
        return 1
    fi
    wwn=$(lsblk -dno WWN "/dev/$dev" 2>/dev/null | sed 's/^0x//')
    if [[ -z "$wwn" ]]; then
        echo "Error: could not determine WWN for /dev/$dev" >&2
        return 1
    fi
    echo "$wwn"
}

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
            slot_sas=$(< "$slot_dir/device/sas_address")
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
    local sd="$1"
    local wwn
    wwn=$(lsblk -dno WWN "/dev/$sd" 2>/dev/null | sed 's/^0x//')
    [[ -z "$wwn" ]] && { echo "N/A"; return; }
    local wwn_prefix="${wwn%?}"
    [[ -z "$wwn_prefix" ]] && { echo "N/A"; return; }

    if find_slot_by_wwn_prefix "$wwn_prefix"; then
        echo "${SLOT_ENC}/Slot${SLOT_NAME}"
    else
        echo "N/A"
    fi
}
