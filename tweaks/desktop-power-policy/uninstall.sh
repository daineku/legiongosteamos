#!/bin/bash
# desktop-power-policy: uninstall (needs sudo). Restores the firmware profile and EPP seen at install time.
set -uo pipefail
. "$LG_REPO/lib/common.sh"

lg_rollback; kept=$?
lg_root systemctl daemon-reload
pb=$(lg_state_get profile_before); eb=$(lg_state_get epp_before)
if [ -n "$pb" ]; then
    for d in "$LG_ROOT"/sys/class/platform-profile/*; do
        [ "$(cat "$d/name" 2>/dev/null)" = lenovo-wmi-gamezone ] || continue
        if printf '%s' "$pb" | lg_root tee "$d/profile" >/dev/null 2>&1; then lg_ok "firmware profile restored to $pb"
        else lg_warn "could not restore firmware profile $pb"; fi
    done
fi
if [ -n "$eb" ]; then
    for f in "$LG_ROOT"/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        printf '%s' "$eb" | lg_root tee "$f" >/dev/null 2>&1 || true
    done
    lg_ok "EPP restored to $eb"
fi
bb=$(lg_state_get boost_before)
if [ "$bb" = 0 ]; then
    for f in "$LG_ROOT"/sys/devices/system/cpu/cpu*/cpufreq/boost; do printf 0 | lg_root tee "$f" >/dev/null 2>&1 || true; done
    lg_ok "CPU boost restored to off (as before installation)"
fi
[ "$(lg_state_get global_boost_before)" = 0 ] && printf 0 | lg_root tee "$LG_ROOT/sys/devices/system/cpu/cpufreq/boost" >/dev/null 2>&1 && lg_ok "global CPU boost restored to off"
[ "$(lg_state_get no_turbo_before)" = 1 ] && printf 1 | lg_root tee "$LG_ROOT/sys/devices/system/cpu/intel_pstate/no_turbo" >/dev/null 2>&1 && lg_ok "Intel turbo restored to off"
lg_info "Evidence logs in /var/log/legion-power were kept (delete them with: sudo rm -r /var/log/legion-power)."
lg_state_archive
[ "$kept" = 0 ]
