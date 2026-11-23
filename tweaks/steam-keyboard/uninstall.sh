#!/bin/bash
# steam-keyboard: uninstall (also used to roll back a failed install with --rollback).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/steam-keyboard/kde.sh"

CEF="$HOME/.local/share/Steam/.cef-enable-remote-debugging"
# Decky Loader needs Steam's debugger flag too: never remove it while Decky is installed.
if lg_manifest_has created "$CEF" && [ -e "$HOME/homebrew/services/PluginLoader" ]; then
    m=$(lg_manifest); awk -F'\t' -v p="$CEF" '$2 != p' "$m" > "$m.tmp" && mv -f "$m.tmp" "$m"
    lg_info "keeping $CEF (Decky Loader uses it)"
fi

lg_rollback; kept=$?

rule=$(lg_state_get kwin_rule)
[ -n "$rule" ] && kde_remove_kwin_rule "$rule"
kde_restore_layout

lg_state_archive
lg_info "Restart Steam (or reboot) to get the completely stock keyboard back."
[ "$kept" = 0 ]
