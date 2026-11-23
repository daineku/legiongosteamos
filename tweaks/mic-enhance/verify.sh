#!/bin/bash
# mic-enhance: the Enhanced Microphone source exists and is the default input.
. "$LG_REPO/lib/common.sh"
src=legiongo_mic_enhanced; [ "$(lg_state_get mode)" = adopted ] && src=legion_mic_enhanced
lg_wait_for "$(lg_verify_timeout 5)" sh -c "pactl list short sources | awk '{print \$2}' | grep -qx $src" || { lg_error "the Enhanced Microphone source is missing"; exit 1; }
[ "$(pactl get-default-source 2>/dev/null)" = "$src" ] && lg_ok "Enhanced Microphone is the default input" || lg_warn "Enhanced Microphone exists but another input is the default"
exit 0
