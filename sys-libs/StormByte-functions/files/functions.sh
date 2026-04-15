#! /bin/bash

# Version 3.0.2

function displayError() {
	echo $1
	exit
}

function handleCommand() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	echo -n "${2} ... "
	eval $1 > /dev/null 2>&1

	if [ $? -eq 0 ]; then
		echo "OK"
	else
		cd "${current_folder}"
		displayError "ERROR in command $1"
	fi
}

function handleCommandWithOutput() {
	# This helper will execute $1 outputting $2 as first text along with OK or ERROR if it failed
	# Example
	# handleCommand 'mount -t proc /proc "${tmp_folder}/proc"' "Mounting system..."
	echo "${2} ... "
	eval $1

	if [ $? -ne 0 ]; then
		cd "${current_folder}"
		displayError "ERROR in command $1"
	fi
}

function loadConfig() {
	if [ -f "${workdir}/${self}.conf" ]; then
		source "${workdir}/${self}.conf"
	elif [ -f "/etc/conf.d/${self}.conf" ]; then
		source "/etc/conf.d/${self}.conf"
	else
		list_contains "${DISABLE_CCACHE}" "${CATEGORY}/${PN}" && force_disable_ccache
		echo "Configuration file ${self}.conf not found neither in current directory neither in /etc/conf.d!"
		exit 1
	fi
}

function list_contains() { [[ "$1" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]]; }

function force_binutils_vars() {
    ADDR2LINE="addr2line"
    AS="as"
    AR="ar"
    NM="nm"
    OBJCOPY="objcopy"
    OBJDUMP="objdump"
    RANLIB="ranlib"
    READELF="readelf"
    STRINGS="strings"
    STRIP="strip"
    LDFLAGS="${LINKER_BASE} ${LINKER_BFD}"
}

function force_gcc_vars() {
    OCC="gcc"
    OCXX="g++"
    CC="gcc"
    CXX="g++"
    CPP="cpp"
    CFLAGS="${FLAGS_BASE} ${FLAGS_CPU} ${FLAGS_GCC} ${FLAGS_SECURITY} ${FLAGS_GRAPHITE}"
    CXXFLAGS="${CFLAGS}"
    force_binutils_vars
}

function force_pic_vars() {
    CFLAGS="${CFLAGS} -fPIC"
    CXXFLAGS="${CXXFLAGS} -fPIC"
}

function force_lto_vars() {
    CFLAGS="${CFLAGS} ${FLAGS_LTO}"
    CXXFLAGS="${CXXFLAGS} ${FLAGS_LTO}"
    LDFLAGS="${LDFLAGS} ${FLAGS_LTO}"
    RUSTFLAGS="${RUSTFLAGS} -Clinker-plugin-lto"
}

function force_ld_undefined_version {
	LDFLAGS="${LINKER_BASE} -Wl,--undefined-version" 
}

function force_openmp_vars() {
	CFLAGS="${CFLAGS} -fopenmp"
	CXXFLAGS="${CXXFLAGS} -fopenmp"
}

function force_reduce_parallel() {
	MAKEFLAGS="-j8"
}

# Useful variables
workdir="${0%/*}"
self=`basename $0`
parameters=("${@:1}")
current_dir=`pwd`
cores=$(nproc)

###############################################################################
# Datacenter disk utility functions
###############################################################################

dc_init_disk_maps() {
    declare -gA DISK_ALIASES
    declare -gA ALIAS_TO_SD

    local _line _sd _wwn _link _name _target _alias

    while IFS= read -r _line; do
        [[ -z "$_line" ]] && continue
        _sd=$(awk '{print $1}' <<< "$_line")
        _wwn=$(awk '{print $2}' <<< "$_line")
        [[ "$_sd" =~ ^sd[a-z]+$ ]] || continue
        [[ -n "$_wwn" ]] || continue
        DISK_ALIASES[$_sd]="wwn-${_wwn}"
    done < <(lsblk -dno NAME,WWN 2>/dev/null)

    for _link in /dev/disk/by-id/*; do
        [[ -L "$_link" ]] || continue
        _name=$(basename "$_link")
        [[ "$_name" == scsi-* || "$_name" == wwn-* || "$_name" == ata-* ]] || continue
        [[ "$_name" =~ -part[0-9]+$ ]] && continue
        _target=$(readlink -f "$_link" 2>/dev/null) || continue
        [[ -b "$_target" ]] || continue
        _sd=$(basename "$_target")
        [[ "$_sd" =~ ^sd[a-z]+$ ]] || continue
        if [[ -v "DISK_ALIASES[$_sd]" ]]; then
            [[ " ${DISK_ALIASES[$_sd]} " =~ " $_name " ]] || DISK_ALIASES[$_sd]+=" $_name"
        else
            DISK_ALIASES[$_sd]="$_name"
        fi
    done

    for _sd in "${!DISK_ALIASES[@]}"; do
        for _alias in ${DISK_ALIASES[$_sd]}; do
            ALIAS_TO_SD[$_alias]="$_sd"
        done
    done
}

dc_resolve_to_sd() {
    local input="$1"
    if [[ "$input" == /dev/sd* ]]; then
        basename "$input"
    elif [[ "$input" =~ ^sd[a-z]+$ ]]; then
        echo "$input"
    elif [[ -v "ALIAS_TO_SD[$input]" ]]; then
        echo "${ALIAS_TO_SD[$input]}"
    else
        return 1
    fi
}

dc_resolve_sas_to_ids() {
    local sas_addr="$1"
    local sas_clean="${sas_addr#0x}"
    local sas_prefix="${sas_clean%?}"

    local _line sd_name wwn wwn_clean wwn_prefix
    while IFS= read -r _line; do
        [[ -z "$_line" ]] && continue
        sd_name=$(awk '{print $1}' <<< "$_line")
        wwn=$(awk '{print $2}' <<< "$_line")
        [[ "$sd_name" =~ ^sd[a-z]+$ ]] || continue
        [[ -n "$wwn" ]] || continue
        wwn_clean="${wwn#0x}"
        wwn_prefix="${wwn_clean%?}"
        if [[ "$wwn_prefix" == "$sas_prefix" ]]; then
            echo "$sd_name scsi-3${wwn_clean} wwn-${wwn}"
            return
        fi
    done < <(lsblk -dno NAME,WWN 2>/dev/null)

    echo "??? sas-$sas_addr"
}

dc_extract_wwn() {
    local disk="$1"
    if [[ "$disk" == scsi-3* ]]; then
        echo "${disk#scsi-3}"
    elif [[ "$disk" == wwn-0x* ]]; then
        echo "${disk#wwn-0x}"
    elif [[ "$disk" == wwn-* ]]; then
        echo "${disk#wwn-}"
    else
        local dev="${disk#/dev/}"
        if [[ ! -b "/dev/$dev" ]]; then
            echo "Error: device does not exist: /dev/$dev" >&2
            return 1
        fi
        local wwn
        wwn=$(lsblk -dno WWN "/dev/$dev" 2>/dev/null | sed 's/^0x//')
        if [[ -z "$wwn" ]]; then
            echo "Error: could not determine WWN for /dev/$dev" >&2
            return 1
        fi
        echo "$wwn"
    fi
}

dc_find_slot_by_wwn_prefix() {
    local wwn_prefix="$1"
    DC_SLOT_DIR=""
    DC_SLOT_ENC=""
    DC_SLOT_SAS=""
    DC_SLOT_NAME=""

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
                DC_SLOT_DIR="${slot_dir%/}"
                DC_SLOT_ENC=$(basename "$(dirname "$slot_dir")")
                DC_SLOT_SAS="$slot_sas"
                DC_SLOT_NAME=$(basename "$slot_dir")
                return 0
            fi
        done
    done
    return 1
}

dc_get_enclosure_slot() {
    local sd="$1"
    local wwn
    wwn=$(lsblk -dno WWN "/dev/$sd" 2>/dev/null | sed 's/^0x//')
    [[ -z "$wwn" ]] && { echo "N/A"; return; }
    local wwn_prefix="${wwn%?}"
    [[ -z "$wwn_prefix" ]] && { echo "N/A"; return; }

    if dc_find_slot_by_wwn_prefix "$wwn_prefix"; then
        echo "${DC_SLOT_ENC}/Slot${DC_SLOT_NAME}"
    else
        echo "N/A"
    fi
}
