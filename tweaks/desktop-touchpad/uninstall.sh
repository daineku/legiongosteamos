#!/bin/bash
# desktop-touchpad: uninstall. Stopping the unit removes InputPlumber's "touchpad" target (stock SteamOS state).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
GROUPS_ARGS=(--file kcminputrc --group Libinput --group 0 --group 65535 --group "InputPlumber Touchpad")

lg_rollback; kept=$?
if [ "$(lg_state_get tap_before_set)" = 1 ] && [ "$(kreadconfig6 "${GROUPS_ARGS[@]}" --key TapToClick)" = false ]; then
    before=$(lg_state_get tap_before)
    if [ -n "$before" ]; then kwriteconfig6 "${GROUPS_ARGS[@]}" --key TapToClick "$before"
    else kwriteconfig6 "${GROUPS_ARGS[@]}" --key TapToClick --delete; fi
    lg_ok "KDE touchpad tap setting restored"
fi
lg_state_archive
lg_info "The touchpad again works only while Steam is running (stock SteamOS behaviour)."
[ "$kept" = 0 ]
