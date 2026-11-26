#!/bin/bash
# smart-auto-brightness: the controller runs steadily, has started, and KWin's own automatic mode is off.
. "$LG_REPO/lib/common.sh"
unit=$(lg_unit_of user | head -1)
lg_in_plasma_session || { lg_info "not inside a Desktop Mode session: $unit starts at the next login"; exit 2; }
lg_unit_stable user "$unit" || { lg_error "$unit is not running steadily (journalctl --user -u $unit)"; exit 1; }
lg_wait_for "$(lg_verify_timeout 10)" lg_unit_logged user "$unit" 'baseline' || { lg_error "controller did not start"; exit 1; }
state=$(sh "$HOME/.local/lib/legiongo-steamos/smart-auto-brightness/kwin-auto-brightness.sh" state 2>/dev/null)
[ "$state" = enabled ] && { lg_error "KWin's automatic brightness is still on (two controllers)"; exit 1; }
lg_ok "one brightness controller active (KWin automatic mode: ${state:-n/a})"; exit 0
