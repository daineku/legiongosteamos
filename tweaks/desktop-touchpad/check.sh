#!/bin/bash
# desktop-touchpad: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"

lg_check_platform yes
lg_req "python3 and busctl available" lg_have python3 busctl
lg_req "user is in the 'wheel' group (InputPlumber's polkit rule allows target changes)" lg_user_in_group wheel
lg_req "kwriteconfig6/kreadconfig6 available" lg_have kwriteconfig6 kreadconfig6
external=0
if [ -e "$HOME/.config/systemd/user/legion-tp-handover.service" ]; then
    external=1
    lg_info "found manual installation: legion-tp-handover.service ($(systemctl --user is-active legion-tp-handover.service 2>/dev/null))"
fi
lg_check_result "$external" "" "manual legion-tp-handover.service setup"
