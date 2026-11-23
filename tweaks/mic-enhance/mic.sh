# shellcheck shell=bash
# shellcheck disable=SC2034  # constants used by the scripts that source this file
# mic-enhance helpers (sourced)
MIC_CONF="$HOME/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf"
MIC_OUT=legiongo_mic_enhanced
mic_node() {   # the internal analog mic's ALSA node (SteamOS hides it behind a loopback device)
    pw-dump 2>/dev/null | jq -r '.[] | select(.type=="PipeWire:Interface:Node") | .info.props["node.name"] // empty' \
        | grep -E '^alsa_input\.pci-[0-9a-f_.]+\.analog-stereo$' | sort -u
}
mic_card_of() { printf 'alsa_card.%s' "$(printf '%s' "$1" | sed 's/^alsa_input\.//; s/\.analog-stereo$//')"; }
mic_card_profile() { pactl list cards 2>/dev/null | awk -v c="$1" '$1=="Name:"{n=$2} n==c && /Active Profile:/{sub(/.*Active Profile: /,""); print; exit}'; }
