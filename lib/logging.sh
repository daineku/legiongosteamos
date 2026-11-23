# shellcheck shell=bash
# Logging helpers. Sourced by lib/common.sh.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _LG_C_RED=$'\033[31m'; _LG_C_GRN=$'\033[32m'; _LG_C_YEL=$'\033[33m'
    _LG_C_BLU=$'\033[34m'; _LG_C_BLD=$'\033[1m'; _LG_C_RST=$'\033[0m'
else
    _LG_C_RED=""; _LG_C_GRN=""; _LG_C_YEL=""; _LG_C_BLU=""; _LG_C_BLD=""; _LG_C_RST=""
fi

lg_info()  { printf '%s\n' "  $*"; }
lg_step()  { printf '%s\n' "${_LG_C_BLU}==>${_LG_C_RST} ${_LG_C_BLD}$*${_LG_C_RST}"; }
lg_ok()    { printf '%s\n' "  ${_LG_C_GRN}ok${_LG_C_RST}   $*"; }
lg_warn()  { printf '%s\n' "  ${_LG_C_YEL}warn${_LG_C_RST} $*" >&2; }
lg_error() { printf '%s\n' "  ${_LG_C_RED}fail${_LG_C_RST} $*" >&2; }
lg_die()   { lg_error "$*"; exit 1; }

# Append a line to the tweak's log in the state directory (if a tweak is active).
lg_log() {
    [ -n "${LG_TWEAK:-}" ] || return 0
    mkdir -p "$LG_STATE/$LG_TWEAK"
    printf '%s %s\n' "$(date -Is)" "$*" >> "$LG_STATE/$LG_TWEAK/log"
}
