#!/bin/bash
# mic-enhance: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/mic-enhance/mic.sh"

lg_check_platform
lg_req "PipeWire filter-chain service" test -e "$LG_ROOT/usr/lib/systemd/user/filter-chain.service"
lg_req "CAPS LADSPA plugins (compressor)" test -e "$LG_ROOT/usr/lib/ladspa/caps.so"
lg_req "pactl, pw-dump and jq available" lg_have pactl pw-dump jq
n=$(mic_node | grep -c .)
if [ "$n" = 1 ]; then lg_ok "internal microphone: $(mic_node)"
else lg_error "expected exactly one internal analog microphone node, found $n"; LG_FAIL=1; fi
external=0
if [ -e "$HOME/.config/pipewire/filter-chain.conf.d/60-legion-mic-enhance.conf" ]; then
    external=1; lg_info "found manual installation: 60-legion-mic-enhance.conf"
fi
lg_check_result "$external" "" "manual 60-legion-mic-enhance.conf filter-chain"
