#!/bin/bash
# steam-keyboard: extra status (service state, Multilingual Input Support report from the running helper)
. "$LG_REPO/lib/common.sh"
for u in legiongo-steam-keyboard.service lgk-helper.service; do
    s=$(systemctl --user is-enabled "$u" 2>/dev/null) && echo "$u: $s / $(systemctl --user is-active "$u" 2>/dev/null)"
done
f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lgk-languages.json"
if [ -r "$f" ] && lg_have jq; then
    echo "KDE layouts: $(jq -r '.kde_layouts | join(", ")' "$f")"
    jq -r '.languages[] | "Steam keyboard language \(.steam): \(
        if .status == "synced" then "synced to KDE layout \(.xkb)\(if .variant != "" then "(\(.variant))" else "" end)"
        elif .status == "kde-layout-missing" then "add KDE layout \(.xkb)\(if .variant != "" then "(\(.variant))" else "" end) for reliable input (LG_KEYBOARD_LAYOUTS=\(.xkb))"
        else "handled by Steam itself (input method / native text path)" end)"' "$f"
else
    echo "language report: available after the keyboard has been opened once (helper v41+)"
fi
