#!/bin/bash
# steam-keyboard: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"

lg_check_platform
lg_req "KDE Plasma 6 tools (kwriteconfig6, kreadconfig6, qdbus6)" lg_have kwriteconfig6 kreadconfig6 qdbus6
lg_req "python3 with GObject introspection (Gio, Atspi)" lg_python_gi Gio 2.0 Atspi 2.0
lg_req "Steam client installed (~/.local/share/Steam)" test -d "$HOME/.local/share/Steam"
lg_req_soft "/dev/uinput writable (needed for controller keys and physical shortcuts)" test -w "$LG_ROOT/dev/uinput"
if [ -e "$HOME/.local/share/Steam/.cef-enable-remote-debugging" ]; then
    lg_ok "Steam local debugger flag present"
else
    lg_info "Steam local debugger flag absent: install will ask to create it (Steam restart needed)"
fi
profiles=$(lg_input_profiles)
lg_info "keyboard input profiles on this device: ${profiles:-none detected}"
case " $profiles " in
    *" dual-joystick "*) lg_ok "dual-joystick typing available (sticks = left/right key cursors, LT / R3 = press, RT = desktop click)" ;;
    *" dual-trackpad "*) lg_ok "dual-trackpad typing is Steam's own; the joystick bridge stays off" ;;
esac
if lg_in_plasma_session; then lg_ok "running inside a Plasma session"; else lg_info "not inside a Plasma session (the service starts at the next Desktop Mode login)"; fi

# Equivalent manual setup (the reference implementation this tweak was extracted from)
external=0
REF_UNIT="$HOME/.config/systemd/user/lgk-helper.service"
REF_DIR="$HOME/.local/lib/legion-desktop-build/lgk"
if [ -e "$REF_UNIT" ] || [ -e "$REF_DIR/lgk-helper.py" ]; then
    external=1
    v=$(sed -n 's/.*const VERSION = \([0-9]*\);.*/\1/p' "$REF_DIR/lgk-inject.js" 2>/dev/null)
    lg_info "found manual installation: $REF_UNIT (script v${v:-?}, $(systemctl --user is-active lgk-helper.service 2>/dev/null))"
fi
lg_check_result "$external" "" "manual lgk-helper.service setup (script v${v:-?})"
