#!/bin/bash
# desktop-power-policy: the policy service runs steadily and applies (or deliberately skips) the policy.
. "$LG_REPO/lib/common.sh"
unit=$(lg_unit_of root | head -1); unit=${unit:-legion-power-policy.service}
lg_unit_stable root "$unit" || { lg_error "$unit is not running steadily (journalctl -u $unit)"; exit 1; }
lg_ok "$unit is running"
lg_in_plasma_session || { lg_info "Desktop Mode is not active: the policy stays idle until it is"; exit 2; }
if lg_wait_for "$(lg_verify_timeout 10)" lg_unit_logged root "$unit" 'applied desktop policy'; then
    lg_unit_logged root "$unit" 'WITH ERRORS' && { lg_error "the policy could not set every value (journalctl -u $unit)"; exit 1; }
    lg_ok "policy applied"; exit 0
fi
[ -e "$LG_ROOT/etc/legion-power/disabled" ] && { lg_info "policy paused by /etc/legion-power/disabled"; exit 0; }
lg_info "no policy action logged yet"; exit 2
