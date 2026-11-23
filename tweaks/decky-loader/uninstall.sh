#!/bin/bash
# decky-loader: uninstall. Plugins and their settings in ~/homebrew are kept unless they were installed by
# the decky-power-plugins tweak (uninstall that tweak first).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
lg_rollback; kept=$?
lg_shared_release steam-debugger "$HOME/.config/systemd/user/legiongo-steam-keyboard.service"
lg_root systemctl daemon-reload
lg_state_archive
lg_info "Restart Steam to unload Decky's UI. Plugin folders in ~/homebrew were kept if they contain anything."
[ "$kept" = 0 ]
