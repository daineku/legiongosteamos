#!/bin/bash
# decky-power-plugins: record installed SimpleDeckyTDP / LegionGoRemapper without changing them.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-power-plugins/plugins.sh"
lg_begin adopted
for p in SimpleDeckyTDP LegionGoRemapper; do
    [ -d "$HB/plugins/$p" ] || continue
    while IFS= read -r f; do lg_adopt_file "$f" root; done < <(find "$HB/plugins/$p" -type f -not -path '*/__pycache__/*' | sort)
    lg_state_set "adopted_$p" "$(jq -r .version "$HB/plugins/$p/package.json" 2>/dev/null)"
done
lg_info "Recorded the installed plugin files. Nothing was changed; plugin settings are not recorded (they are yours)."
