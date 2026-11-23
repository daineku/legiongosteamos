#!/bin/bash
# precision-touchpad: InputPlumber runs steadily on OUR binary (no fallback) and the Legion Go controller is managed.
. "$LG_REPO/lib/common.sh"
lg_unit_stable root inputplumber.service || { lg_error "inputplumber.service is not running steadily"; exit 1; }
if lg_unit_logged root inputplumber.service 'inputplumber-launch: .*falling back|inputplumber-launch: using stock'; then
    lg_error "the launcher fell back to the stock InputPlumber (journalctl -u inputplumber)"; exit 1
fi
if lg_wait_for "$(lg_verify_timeout 15)" sh -c 'busctl --system tree --list org.shadowblip.InputPlumber 2>/dev/null | grep -q "/CompositeDevice[0-9]"'; then
    lg_ok "InputPlumber manages the controller"; exit 0
fi
lg_error "InputPlumber runs but exposes no controller device"; exit 1
