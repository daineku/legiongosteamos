#!/bin/bash
# decky-loader: record an existing Decky Loader installation without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-loader/decky.sh"
lg_begin adopted
lg_adopt_file "$HB/services/PluginLoader" user
lg_adopt_file "$HB/services/.loader.version" user
lg_adopt_file "$DECKY_UNIT" root
lg_adopt_unit root plugin_loader.service
lg_state_set adopted_version "$(cat "$HB/services/.loader.version" 2>/dev/null)"
lg_info "Recorded Decky Loader $(lg_state_get adopted_version). Nothing on the system was changed; plugins are not part of this record."
