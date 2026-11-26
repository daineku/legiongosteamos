#!/bin/sh
# KWin automatic brightness on the internal panel: state | off | restore
# restore re-enables it only if it was enabled when the tweak was installed (file kwin-auto-before).
D="$HOME/.config/legiongo-steamos/smart-auto-brightness"
out=$(kscreen-doctor -j 2>/dev/null | jq -r '[.outputs[] | select(.connected and .type == 7)][0].name // empty')
[ -n "$out" ] || { echo "no internal panel found" >&2; exit 1; }
state() { kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk -v o="$out" '$1=="Output:" {cur=($3==o)} cur && /Automatic brightness:/ {print $NF; exit}'; }
case "${1:-state}" in
    state)   state ;;
    off)     [ "$(state)" = enabled ] && kscreen-doctor "output.$out.autoBrightness.disable" >/dev/null 2>&1; state ;;
    restore) [ "$(cat "$D/kwin-auto-before" 2>/dev/null)" = enabled ] && kscreen-doctor "output.$out.autoBrightness.enable" >/dev/null 2>&1; state ;;
esac
