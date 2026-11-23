#!/bin/bash
# steam-keyboard: uninstall (also used to roll back a failed install with --rollback).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/steam-keyboard/kde.sh"

lg_rollback; kept=$?
lg_shared_release steam-debugger "$HOME/homebrew/services/PluginLoader"   # Decky Loader needs it too

rule=$(lg_state_get kwin_rule)
[ -n "$rule" ] && kde_remove_kwin_rule "$rule"
kde_restore_layout

lg_state_archive
lg_info "Restart Steam (or reboot) to get the completely stock keyboard back."
[ "$kept" = 0 ]
