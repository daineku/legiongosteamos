#!/bin/bash
# steam-keyboard: install (user level, no sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/steam-keyboard/kde.sh"

F="$LG_REPO/tweaks/steam-keyboard/files"
LIB="$HOME/.local/lib/legiongo-steamos/steam-keyboard"
CFG="$HOME/.config/legiongo-steamos/steam-keyboard"
UNIT=legiongo-steam-keyboard.service
CEF="$HOME/.local/share/Steam/.cef-enable-remote-debugging"

lg_begin installed

lg_step "Installing keyboard files"
lg_put_file "$F/lgk-helper.py" "$LIB/lgk-helper.py" 644 user
lg_put_file "$F/lgk-inject.js" "$LIB/lgk-inject.js" 644 user
lg_put_file "$F/lgk-kwin.js"   "$LIB/lgk-kwin.js"   644 user
lg_put_file "$F/$UNIT" "$HOME/.config/systemd/user/$UNIT" 644 user

# Auto-open on field focus is off by default (the verified reference configuration).
if [ "${LG_KEYBOARD_AUTOOPEN:-0}" != 1 ]; then
    lg_put_content "$CFG/lgk-autoopen-off" 644 user < /dev/null
    lg_info "auto-open on text-field focus: off (enable: rm $CFG/lgk-autoopen-off && systemctl --user restart $UNIT)"
fi

if [ ! -e "$CEF" ]; then
    lg_warn "The keyboard script is applied through Steam's local debugger (127.0.0.1:8080)."
    lg_info "It is enabled by the empty file $CEF (Decky Loader uses the same file)."
    lg_info "While enabled, local programs on this device can control the Steam client UI."
    lg_confirm "Create it now? (Steam must be restarted once afterwards)" || lg_die "the Steam local debugger is required"
    lg_put_content "$CEF" 644 user < /dev/null
    lg_state_set restart_steam 1
fi

lg_step "KWin rule: keyboard above the app launcher and Plasma popups"
kde_add_kwin_rule legiongo-osk-layer
lg_state_set kwin_rule legiongo-osk-layer

if [ "${LG_KEYBOARD_ADD_RU:-0}" = 1 ]; then
    lg_step "KDE keyboard layouts: adding Russian"
    kde_add_layout ru
fi

lg_step "Enabling $UNIT"
lg_unit_enable user "$UNIT"
if lg_in_plasma_session; then
    systemctl --user restart "$UNIT"
    sleep 2
    systemctl --user is-active --quiet "$UNIT" && lg_ok "$UNIT is running" || lg_warn "$UNIT did not start; see: journalctl --user -u $UNIT"
fi
[ "$(lg_state_get restart_steam)" = 1 ] && lg_warn "Restart Steam once so the debugger flag takes effect."
exit 0
