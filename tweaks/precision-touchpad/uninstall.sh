#!/bin/bash
# precision-touchpad: return to the stock SteamOS InputPlumber (needs sudo).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"

lg_rollback; kept=$?
lg_step "Restarting InputPlumber on the stock SteamOS package"
lg_root systemctl daemon-reload
lg_root systemctl restart inputplumber.service || lg_warn "inputplumber.service restart failed; reboot to recover"
lg_state_archive
[ "$kept" = 0 ]
