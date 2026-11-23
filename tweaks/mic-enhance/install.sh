#!/bin/bash
# mic-enhance: install (user level, no sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/mic-enhance/mic.sh"

node=$(mic_node); [ "$(printf '%s\n' "$node" | grep -c .)" = 1 ] || lg_die "internal microphone not found"
card=$(mic_card_of "$node")
lg_begin installed

prof=$(mic_card_profile "$card")
case "$prof" in
    *input:*) lg_ok "audio profile already includes the microphone ($prof)" ;;
    *)  lg_info "switching $card to the duplex profile (speakers + microphone)"
        [ -n "$(lg_state_get profile_before)" ] || lg_state_set profile_before "$prof"
        pactl set-card-profile "$card" output:analog-stereo+input:analog-stereo
        lg_state_set profile_card "$card"
        lg_state_set profile_after output:analog-stereo+input:analog-stereo ;;
esac

sed "s|@MIC_NODE@|$node|" "$LG_REPO/tweaks/mic-enhance/files/60-legiongo-mic-enhance.conf.in" | lg_put_content "$MIC_CONF" 644 user
systemctl --user restart filter-chain.service
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pactl list short sources | awk '{print $2}' | grep -qx "$MIC_OUT" && break
    sleep 0.5
done
pactl list short sources | awk '{print $2}' | grep -qx "$MIC_OUT" || lg_die "the Enhanced Microphone source did not appear"
lg_ok "Enhanced Microphone source is available"

cur=$(pactl get-default-source)
if [ "$cur" != "$MIC_OUT" ]; then
    [ -n "$(lg_state_get default_before)" ] || lg_state_set default_before "$cur"
    pactl set-default-source "$MIC_OUT"
fi
lg_ok "default input: Enhanced Microphone"
lg_info "Tip: if your voice is still too loud or distorted, lower the input level in System Settings > Sound."
