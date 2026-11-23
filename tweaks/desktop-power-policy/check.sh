#!/bin/bash
# desktop-power-policy: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"

lg_check_platform yes
gz=""
for d in "$LG_ROOT"/sys/class/platform-profile/*; do
    [ "$(cat "$d/name" 2>/dev/null)" = lenovo-wmi-gamezone ] && gz="$d"
done
lg_req "Lenovo firmware profile interface (lenovo-wmi-gamezone)" test -n "$gz"
lg_req "amd-pstate EPP interface" test -e "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
lg_req "python3 with GObject introspection (Gio)" lg_python_gi Gio 2.0
lg_req_soft "UPower service (battery/AC detection)" test -e "$LG_ROOT/usr/lib/systemd/system/upower.service"

external=0; detail=""
if ! lg_is_tracked_tweak && [ -e "$LG_ROOT/etc/legion-power/legion-power-policy.py" ]; then
    external=1
    tmp=$(mktemp); sed "s|@USER_HOME@|$HOME|" "$LG_REPO/tweaks/desktop-power-policy/files/legion-power-policy.py.in" > "$tmp"
    n=$(diff "$tmp" "$LG_ROOT/etc/legion-power/legion-power-policy.py" | grep -c '^[<>]')
    rm -f "$tmp"
    detail="existing /etc/legion-power setup ($([ "$n" = 0 ] && echo identical to this version || echo "$n changed lines vs this version"))"
    lg_info "found $detail"
fi
lg_check_result "$external" "" "$detail"
