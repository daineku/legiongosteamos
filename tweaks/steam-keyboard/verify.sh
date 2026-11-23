#!/bin/bash
# steam-keyboard: the helper runs, stays up, and has applied the keyboard script to the running Steam client.
. "$LG_REPO/lib/common.sh"
unit=$(lg_unit_of user | head -1)
[ -n "$unit" ] || { lg_error "no service recorded"; exit 1; }
if ! lg_in_plasma_session; then lg_info "not inside a Desktop Mode session: $unit starts at the next login"; exit 2; fi
lg_unit_stable user "$unit" || { lg_error "$unit is not running steadily (journalctl --user -u $unit)"; exit 1; }
lg_ok "$unit is running"
if ! pgrep -x steam >/dev/null 2>&1; then lg_info "Steam is not running: the keyboard script is applied when Steam starts"; exit 2; fi
if lg_wait_for "$(lg_verify_timeout 20)" lg_unit_logged user "$unit" 'installed v[0-9]+|already v[0-9]+'; then
    lg_ok "keyboard script applied to the running Steam client"
    if lg_unit_logged user "$unit" 'unsupported:'; then lg_warn "some Steam hooks are unsupported on this Steam build (doctor shows which); the stock keyboard behaviour is kept for them"; fi
    exit 0
fi
if [ ! -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging" ] || [ "$(lg_state_get restart_steam)" = 1 ]; then
    lg_info "restart Steam once so its local debugger is enabled; the script is applied then"; exit 2
fi
lg_error "the helper could not reach the Steam client (journalctl --user -u $unit)"; exit 1
