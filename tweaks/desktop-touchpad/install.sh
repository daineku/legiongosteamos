#!/bin/bash
# desktop-touchpad: install (user level, no sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"

F="$LG_REPO/tweaks/desktop-touchpad/files"
UNIT=legiongo-desktop-touchpad.service
GROUPS_ARGS=(--file kcminputrc --group Libinput --group 0 --group 65535 --group "InputPlumber Touchpad")

lg_begin installed
lg_put_file "$F/legion-tp-handover.py" "$HOME/.local/lib/legiongo-steamos/desktop-touchpad/legion-tp-handover.py" 644 user
lg_put_file "$F/$UNIT" "$HOME/.config/systemd/user/$UNIT" 644 user

# InputPlumber generates tap-to-click itself; libinput's own tapping on the native pad would double it.
if [ -z "$(lg_state_get tap_before_set)" ]; then
    before=$(kreadconfig6 "${GROUPS_ARGS[@]}" --key TapToClick)
    lg_state_set tap_before_set 1
    lg_state_set tap_before "$before"
fi
kwriteconfig6 "${GROUPS_ARGS[@]}" --key TapToClick false
lg_ok "KDE: tap-to-click off for the native 'InputPlumber Touchpad' (InputPlumber already sends tap clicks)"

lg_unit_enable user "$UNIT"
if lg_in_plasma_session; then
    systemctl --user restart "$UNIT"
    sleep 1
    systemctl --user is-active --quiet "$UNIT" && lg_ok "$UNIT is running" || lg_warn "$UNIT did not start; see: journalctl --user -u $UNIT"
fi
