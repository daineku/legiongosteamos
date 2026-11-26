#!/bin/bash
# smart-auto-brightness: install (user level, no sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
F="$LG_REPO/tweaks/smart-auto-brightness/files"
LIB="$HOME/.local/lib/legiongo-steamos/smart-auto-brightness"
CFG="$HOME/.config/legiongo-steamos/smart-auto-brightness"
UNIT=legiongo-auto-brightness.service
lg_begin installed
# remember KWin's own automatic-brightness setting once, so it is restored exactly
if [ ! -e "$CFG/kwin-auto-before" ]; then
    sh "$F/kwin-auto-brightness.sh" state | lg_put_content "$CFG/kwin-auto-before" 644 user
fi
lg_info "KWin automatic brightness before installation: $(cat "$CFG/kwin-auto-before")"
lg_put_file "$F/legiongo-auto-brightness.py" "$LIB/legiongo-auto-brightness.py" 644 user
lg_put_file "$F/kwin-auto-brightness.sh" "$LIB/kwin-auto-brightness.sh" 755 user
lg_put_file "$F/$UNIT" "$HOME/.config/systemd/user/$UNIT" 644 user
lg_unit_enable user "$UNIT"
if lg_in_plasma_session; then systemctl --user restart "$UNIT"; fi
