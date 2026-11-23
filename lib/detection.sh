# shellcheck shell=bash
# Hardware / OS / session detection. Sourced by lib/common.sh.
# Every system path is prefixed with $LG_ROOT so tests can run against a mocked tree.

# Lenovo Legion Go (1st gen): DMI product name 83E1, product version "Legion Go 8APU1".
# Other machine types are not assumed; report them as unsupported rather than guess.
lg_dmi() { cat "$LG_ROOT/sys/class/dmi/id/$1" 2>/dev/null || true; }

lg_is_legion_go() {
    local name ver
    name=$(lg_dmi product_name); ver=$(lg_dmi product_version)
    case "$ver" in *"Legion Go 8APU1"*) return 0 ;; esac
    [ "$name" = 83E1 ] && return 0
    return 1
}

lg_device_desc() { printf '%s (%s)' "$(lg_dmi product_version)" "$(lg_dmi product_name)"; }

lg_os_field() {   # lg_os_field ID|VERSION_ID|...
    local f="$LG_ROOT/etc/os-release"
    [ -r "$f" ] || return 0
    sed -n "s/^$1=//p" "$f" | head -1 | tr -d '"'
}
lg_is_steamos() { [ "$(lg_os_field ID)" = steamos ]; }
lg_os_version() { lg_os_field VERSION_ID; }

# Is $1 in the space-separated list $2 (exact match or "3.9.x" style prefix match)?
lg_version_in() {
    local v="$1" pat
    for pat in $2; do
        case "$pat" in
            *.x) [ "${v#"${pat%x}"}" != "$v" ] && return 0 ;;
            *) [ "$v" = "$pat" ] && return 0 ;;
        esac
    done
    return 1
}

# lg_vercmp A B -> prints -1, 0 or 1
lg_vercmp() {
    [ "$1" = "$2" ] && { echo 0; return; }
    if [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; then echo -1; else echo 1; fi
}
lg_version_ge() { [ "$(lg_vercmp "$1" "$2")" != -1 ]; }

lg_in_plasma_session() {
    case "${XDG_CURRENT_DESKTOP:-}" in *KDE*) return 0 ;; esac
    return 1
}

lg_pkg_version() {   # installed pacman package version without pkgrel, or empty
    command -v pacman >/dev/null 2>&1 || return 0
    pacman -Q "$1" 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//'
}

lg_user_in_group() { id -nG 2>/dev/null | tr ' ' '\n' | grep -qx "$1"; }

lg_have() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || return 1; done; }

lg_python_gi() {   # lg_python_gi Gio 2.0 [Atspi 2.0 ...]
    local code="import gi"
    while [ $# -ge 2 ]; do
        code="$code; gi.require_version('$1', '$2'); from gi.repository import $1"
        shift 2
    done
    python3 -c "$code" >/dev/null 2>&1
}
