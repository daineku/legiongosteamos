# shellcheck shell=bash
# ./legiongo.sh doctor: system and compatibility report for users and maintainers.
# Privacy: prints no user name, home path, network name, MAC/IP address, serial number or Steam account data.

_dr() { printf '  %-28s %s\n' "$1" "$2"; }
_rd() { cat "$1" 2>/dev/null || echo "?"; }

lg_doctor() {
    local t st rec=() v
    echo "Legion Go SteamOS — doctor report ($(date -u +%Y-%m-%dT%H:%MZ), legiongo-steamos $(git -C "$LG_REPO" describe --tags --always 2>/dev/null || echo unknown))"
    echo
    echo "System"
    _dr "device" "$(lg_device_desc)$(lg_is_legion_go && echo ' — supported' || echo ' — NOT a supported Legion Go')"
    _dr "BIOS" "$(lg_dmi bios_version)"
    _dr "SteamOS" "$(lg_os_version) (build $(lg_os_field BUILD_ID))"
    _dr "kernel" "$(uname -r)"
    _dr "session" "${XDG_SESSION_TYPE:-?} / ${XDG_CURRENT_DESKTOP:-?}"
    _dr "KDE Plasma" "$(lg_pkg_version plasma-workspace)"
    _dr "steamos-manager" "$(lg_pkg_version steamos-manager)"
    _dr "InputPlumber (stock pkg)" "$(lg_pkg_version inputplumber)"
    _dr "InputPlumber (service)" "$(systemctl is-active inputplumber.service 2>/dev/null)$(systemctl cat inputplumber.service 2>/dev/null | grep -q '^ExecStart=/home' && echo ', override drop-in active')"
    v=$(sed -n 's/.*"version"[[:space:]]*"\([0-9]*\)".*/\1/p' "$HOME"/.local/share/Steam/package/steam_client_*.manifest 2>/dev/null | head -1)
    _dr "Steam client build" "${v:-not found}"
    _dr "Steam debugger flag" "$([ -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging" ] && echo present || echo absent)"
    _dr "Decky Loader" "$(_rd "$HOME/homebrew/services/.loader.version" | head -1)$(systemctl is-active plugin_loader.service >/dev/null 2>&1 && echo ' (running)')"
    echo
    echo "Tweaks"
    for t in $(for d in "$LG_REPO"/tweaks/*/manifest.json; do basename "$(dirname "$d")"; done); do
        check_state "$t"
        st="$CHECK_STATE"
        local line="$st"
        if lg_is_tracked_tweak "$t"; then
            line="$st, $(lg_state_get mode "$t") v$(lg_state_get version "$t")"
            if [ "$(lg_state_get mode "$t")" = installed ] && [ "$(lg_state_get version "$t")" != "$(lg_mf .version "$t")" ]; then
                line="$line — OUTDATED (v$(lg_mf .version "$t") available)"
                rec+=("update $t:  ./legiongo.sh update $t")
            fi
        fi
        if [ "$st" = installed ]; then
            case "$(functional_state "$t" 1)" in
                verified) line="$line — working" ;;
                pending)  line="$line — verification pending" ;;
                broken)   line="$line — BROKEN"; rec+=("$t fails its functional check: ./legiongo.sh update $t (repair) or ./legiongo.sh check $t") ;;
            esac
        fi
        _dr "$t" "$line"
        case "$st" in
            partial) rec+=("$t is incomplete: ./legiongo.sh install $t (repair) or ./legiongo.sh uninstall $t") ;;
            untested) rec+=("$t: SteamOS $(lg_os_version) is not in its tested list; check docs/COMPATIBILITY.md before using --force") ;;
            conflict) rec+=("$t: $CHECK_DETAIL") ;;
        esac
    done
    echo
    echo "Compatibility probes"
    _dr "keyboard input profiles" "$(lg_input_profiles)"
    _dr "CPU frequency driver" "$(cat "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver" 2>/dev/null) (EPP $([ -e "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference" ] && echo yes || echo no), boost $(cat "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/boost" 2>/dev/null || echo n/a))"
    # precision-touchpad: does the stock profile already read the touchpad interface natively?
    if grep -q 'interface_num: 1' "$LG_ROOT/usr/share/inputplumber/devices/50-legion_go.yaml" 2>/dev/null; then
        _dr "stock touchpad driver" "native (stock InputPlumber reads the touchpad interface)"
    else
        _dr "stock touchpad driver" "gamepad-report path (~40 Hz); precision-touchpad improves this"
    fi
    if [ -r "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lgk-languages.json" ] && command -v jq >/dev/null; then
        _dr "keyboard languages" "$(jq -r '[.languages[] | "\(.steam)=\(.status)"] | join(", ")' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lgk-languages.json")"
    fi
    v=$(journalctl --user -u legiongo-steam-keyboard.service -u lgk-helper.service -b --no-pager -o cat 2>/dev/null | grep -o 'unsupported: [^)]*' | tail -1)
    _dr "keyboard hooks" "${v:-no unsupported Steam hooks reported this boot}"
    [ -n "$v" ] && rec+=("Steam client changed keyboard internals ($v): see docs/MAINTAINING.md")
    if [ -x "$LG_REPO/experimental/wifi-reliability/wifi-report.sh" ]; then
        _dr "Wi-Fi resume (this boot)" "$("$LG_REPO/experimental/wifi-reliability/wifi-report.sh" --summary 2>/dev/null || echo n/a)"
    fi
    echo
    echo "Recommended actions"
    if [ ${#rec[@]} = 0 ]; then echo "  none"; else printf '  - %s\n' "${rec[@]}"; fi
}
