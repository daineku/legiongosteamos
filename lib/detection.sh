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

# On-screen keyboard input profiles the hardware can drive (capability detection, not device names):
#   dual-joystick  InputPlumber's virtual Steam Deck controller (28DE:12FE): steam-keyboard's bridge maps the
#                  left/right sticks to the keyboard's left/right cursors and the triggers to key presses
#   dual-trackpad  a real Steam Deck controller (28DE:1205): Steam's own dual-trackpad typing; the bridge stays off
#   touchscreen    a touchscreen input device
lg_input_profiles() {
    local out="" f
    for f in "$LG_ROOT"/sys/class/hidraw/hidraw*/device/uevent; do
        [ -r "$f" ] || continue
        case "$(cat "$f")" in
            *HID_ID=0003:000028DE:000012FE*) case "$out" in *dual-joystick*) ;; *) out="$out dual-joystick" ;; esac ;;
            *HID_ID=0003:000028DE:00001205*) case "$out" in *dual-trackpad*) ;; *) out="$out dual-trackpad" ;; esac ;;
        esac
    done
    grep -lq "ID_INPUT_TOUCHSCREEN=1" "$LG_ROOT"/run/udev/data/c13:* 2>/dev/null && out="$out touchscreen"
    echo "${out# }"
}
