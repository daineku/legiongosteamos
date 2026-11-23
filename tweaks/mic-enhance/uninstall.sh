#!/bin/bash
# mic-enhance: uninstall.
set -uo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/mic-enhance/mic.sh"

before=$(lg_state_get default_before)
lg_rollback; kept=$?
systemctl --user restart filter-chain.service || true
sleep 1
if [ -n "$before" ] && pactl list short sources | awk '{print $2}' | grep -qx "$before"; then
    pactl set-default-source "$before" && lg_ok "default input restored to $before"
fi
c=$(lg_state_get profile_card)
if [ -n "$c" ] && [ "$(mic_card_profile "$c")" = "$(lg_state_get profile_after)" ] && [ -n "$(lg_state_get profile_before)" ]; then
    pactl set-card-profile "$c" "$(lg_state_get profile_before)" && lg_ok "audio profile restored"
fi
lg_state_archive
[ "$kept" = 0 ]
