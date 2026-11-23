#!/bin/bash
# desktop-power-policy: install the root service (needs sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
F="$LG_REPO/tweaks/desktop-power-policy/files"

lg_begin installed
for d in "$LG_ROOT"/sys/class/platform-profile/*; do
    if [ "$(cat "$d/name" 2>/dev/null)" = lenovo-wmi-gamezone ] && [ -z "$(lg_state_get profile_before)" ]; then
        lg_state_set profile_before "$(cat "$d/profile")"
    fi
done
[ -n "$(lg_state_get epp_before)" ] || lg_state_set epp_before "$(cat "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference" 2>/dev/null)"

sed "s|@USER_HOME@|$HOME|" "$F/legion-power-policy.py.in" | lg_put_content "$LG_ROOT/etc/legion-power/legion-power-policy.py" 644 root
lg_put_file "$F/legion-power-policy.service" "$LG_ROOT/etc/systemd/system/legion-power-policy.service" 644 root
lg_unit_enable root legion-power-policy.service --now
lg_root systemctl restart legion-power-policy.service
[ "$LG_TEST" = 1 ] || sleep 2
lg_root systemctl is-active --quiet legion-power-policy.service || lg_die "legion-power-policy.service is not running"
lg_ok "legion-power-policy.service is running (pause it any time: sudo touch /etc/legion-power/disabled)"
