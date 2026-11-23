#!/bin/bash
# decky-power-plugins: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-power-plugins/plugins.sh"
lg_check_platform yes
lg_req "curl, unzip, tar, git (for the patch) available" lg_have curl unzip tar git
lg_req_soft "Decky Loader installed" test -e "$HB/services/PluginLoader"
external=0; detail=""
if ! lg_is_tracked_tweak; then
    for p in SimpleDeckyTDP LegionGoRemapper; do
        if [ -d "$HB/plugins/$p" ]; then
            external=1
            detail="$detail $p $(jq -r .version "$HB/plugins/$p/package.json" 2>/dev/null)"
        fi
    done
    [ "$external" = 1 ] && lg_info "found installed plugins:$detail"
fi
lg_check_result "$external" "" "plugins already installed:$detail"
