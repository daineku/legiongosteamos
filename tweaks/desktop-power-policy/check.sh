#!/bin/bash
# desktop-power-policy: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"

lg_check_platform
# Capability probes (no device-name requirement): the policy uses whatever of these exists and skips the rest.
gz=""
for d in "$LG_ROOT"/sys/class/platform-profile/*; do
    [ "$(cat "$d/name" 2>/dev/null)" = lenovo-wmi-gamezone ] && gz="$d"
done
caps=0
if [ -n "$gz" ]; then lg_ok "Lenovo firmware profiles (lenovo-wmi-gamezone): battery balanced / AC performance"; caps=$((caps + 1))
else lg_info "no Lenovo firmware profile interface: firmware profile switching is skipped on this device"; fi
if [ -e "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference" ]; then
    lg_ok "CPU energy preference (EPP, $(cat "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver" 2>/dev/null || echo cpufreq))"; caps=$((caps + 1))
else lg_info "no EPP interface: energy preference is skipped"; fi
if [ -e "$LG_ROOT/sys/devices/system/cpu/cpu0/cpufreq/boost" ]; then
    lg_ok "CPU boost control (per-policy cpufreq boost): kept on in Desktop Mode"; caps=$((caps + 1))
else lg_info "no per-policy CPU boost control: boost is left as it is"; fi
[ "$caps" -gt 0 ] || { lg_error "none of the power interfaces this policy uses exists on this device"; LG_FAIL=1; }
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
