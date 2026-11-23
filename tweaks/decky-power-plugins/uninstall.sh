#!/bin/bash
# decky-power-plugins: remove the plugins installed by this tweak (settings you changed are kept).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
# Python byte-code caches that Decky created inside our plugin folders (not user data)
if [ "$(lg_state_get mode)" = installed ]; then
    for p in SimpleDeckyTDP LegionGoRemapper; do
        [ -d "$HOME/homebrew/plugins/$p" ] && lg_root find "$HOME/homebrew/plugins/$p" -name __pycache__ -type d -prune -exec rm -rf {} +
    done
fi
lg_rollback; kept=$?
lg_root systemctl restart plugin_loader.service >/dev/null 2>&1 || true
lg_state_archive
lg_info "Firmware fan control and TDP limits return to their defaults the next time you change power settings or reboot."
[ "$kept" = 0 ]
