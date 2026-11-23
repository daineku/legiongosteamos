#!/bin/bash
# decky-loader: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-loader/decky.sh"
lg_check_platform no
lg_req "Steam client installed" test -d "$HOME/.local/share/Steam"
lg_req "curl and sha256sum available" lg_have curl sha256sum
external=0; detail=""
if ! lg_is_tracked_tweak && { [ -e "$DECKY_UNIT" ] || [ -e "$HB/services/PluginLoader" ]; }; then
    external=1
    v=$(cat "$HB/services/.loader.version" 2>/dev/null)
    s=$(lg_sha "$HB/services/PluginLoader")
    detail="Decky Loader ${v:-?} already installed$([ "$s" = "$DECKY_SHA" ] && echo " (binary identical to the pinned $DECKY_VERSION release)")"
    lg_info "found $detail"
fi
lg_check_result "$external" "" "$detail"
