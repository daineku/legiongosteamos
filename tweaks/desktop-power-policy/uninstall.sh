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
lg_info "Evidence logs in /var/log/legion-power were kept (delete them with: sudo rm -r /var/log/legion-power)."
lg_state_archive
[ "$kept" = 0 ]
