#!/bin/bash
# Read-only Wi-Fi resume report. Measures, from the system journal, how long Wi-Fi takes to reconnect after
# each resume from sleep, and shows the regulatory-domain and power-save state.
# Prints no network names, MAC or IP addresses.
#   wifi-report.sh            report for the current boot
#   wifi-report.sh --all      all boots in the journal
#   wifi-report.sh --summary  one line (used by ./legiongo.sh doctor)
set -uo pipefail
boots=(0)
[ "${1:-}" = --all ] && mapfile -t boots < <(journalctl --list-boots --no-pager 2>/dev/null | awk 'NR>1{print $1}')

times=$(for b in "${boots[@]}"; do
    journalctl -b "$b" --no-pager -o short-unix 2>/dev/null | awk '
        /System returned from sleep/ {t = $1; next}
        t && /device \(wlan[0-9]\): Activation: successful/ {printf "%.1f\n", $1 - t; t = 0}'
done | sort -n)
n=$(printf '%s\n' "$times" | grep -c .)
stats() { printf '%s\n' "$times" | awk -v n="$n" '{a[NR]=$1} END{ if (n) printf "%d resumes, median %.1f s, p90 %.1f s, max %.1f s", n, a[int((n+1)/2)], a[int(n*0.9) ? int(n*0.9) : 1], a[n]; else printf "no resume with Wi-Fi reconnect in the journal" }'; }

if [ "${1:-}" = --summary ]; then stats; echo; exit 0; fi

echo "Wi-Fi resume report"
echo "  reconnect after resume:  $(stats)"
dev=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')
echo "  interface:               ${dev:-none}"
[ -n "$dev" ] && echo "  driver power save:       $(iw dev "$dev" get power_save 2>/dev/null | sed 's/Power save: //')"
echo "  NetworkManager powersave: $(grep -h '^wifi.powersave' /etc/NetworkManager/conf.d/*.conf /usr/lib/NetworkManager/conf.d/*.conf 2>/dev/null | tail -1) (2 = off, 3 = on; set by SteamOS)"
echo "  backend:                 $(grep -h '^wifi.backend' /etc/NetworkManager/conf.d/*.conf /usr/lib/NetworkManager/conf.d/*.conf 2>/dev/null | tail -1)"
echo "  regulatory domain:       $(iw reg get 2>/dev/null | awk '/^country/{print $2; exit}' | tr -d :)"
p=$(cat /sys/module/cfg80211/parameters/ieee80211_regdom 2>/dev/null); echo "  cfg80211 static country: $([ -n "$p" ] && [ "$p" != 00 ] && echo "set by modprobe option" || echo "not set")"
echo "  regdom changes (boot):   $(journalctl -b --no-pager -o cat 2>/dev/null | grep -o 'REGDOM-CHANGE init=[A-Z_]*' | sort | uniq -c | awk '{sub("init=","",$3); printf "%s %s, ", $1, $3}')"
