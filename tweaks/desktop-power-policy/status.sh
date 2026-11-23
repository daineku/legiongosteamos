#!/bin/bash
. "$LG_REPO/lib/common.sh"
for d in "$LG_ROOT"/sys/class/platform-profile/*; do
    [ "$(cat "$d/name" 2>/dev/null)" = lenovo-wmi-gamezone ] && echo "gamezone profile: $(cat "$d/profile")"
done
echo "EPP: $(sort -u "$LG_ROOT"/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference 2>/dev/null | tr '\n' ' ')"
echo "legion-power-policy.service: $(systemctl is-active legion-power-policy.service 2>/dev/null)"
[ -e "$LG_ROOT/etc/legion-power/disabled" ] && echo "policy paused (flag /etc/legion-power/disabled)"
journalctl -u legion-power-policy.service -n 2 --no-pager -o cat 2>/dev/null | sed 's/^/last: /'
