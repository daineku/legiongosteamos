#!/bin/bash
# steam-keyboard: record the existing manual (reference) setup without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"

REF="$HOME/.local/lib/legion-desktop-build/lgk"
lg_begin adopted
for f in "$REF/lgk-helper.py" "$REF/lgk-inject.js" "$REF/lgk-kwin.js" \
         "$HOME/.config/legion-desktop-build/lgk-autoopen-off" "$HOME/.config/legion-desktop-build/lgk-disabled" \
         "$HOME/.config/systemd/user/lgk-helper.service"; do
    lg_adopt_file "$f" user
done
lg_adopt_unit user lgk-helper.service
if kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null | tr ',' '\n' | grep -qx lgk-osk-layer; then
    lg_state_set kwin_rule lgk-osk-layer
fi
lg_info "Recorded $(grep -c . "$(lg_manifest)") items. Nothing on the system was changed."
lg_info "KDE keyboard layouts, the Steam debugger flag and other personal settings are not recorded and stay as they are."
