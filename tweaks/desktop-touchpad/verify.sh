#!/bin/bash
# desktop-touchpad: the hand-over service runs steadily and watches the Steam controller node.
. "$LG_REPO/lib/common.sh"
unit=$(lg_unit_of user | head -1)
[ -n "$unit" ] || { lg_error "no service recorded"; exit 1; }
if ! lg_in_plasma_session; then lg_info "not inside a Desktop Mode session: $unit starts at the next login"; exit 2; fi
lg_unit_stable user "$unit" || { lg_error "$unit is not running steadily"; exit 1; }
if lg_wait_for "$(lg_verify_timeout 10)" lg_unit_logged user "$unit" 'watching Steam controller node|ENABLE native touchpad|DISABLE native touchpad'; then
    lg_unit_logged user "$unit" 'FAILED' && { lg_error "InputPlumber refused the target change (journalctl --user -u $unit)"; exit 1; }
    lg_ok "touchpad hand-over is active"; exit 0
fi
lg_info "no Steam controller node yet (InputPlumber starting?)"; exit 2
