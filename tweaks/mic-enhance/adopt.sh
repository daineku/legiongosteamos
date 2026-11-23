#!/bin/bash
# mic-enhance: record the existing manual filter-chain without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
lg_begin adopted
lg_adopt_file "$HOME/.config/pipewire/filter-chain.conf.d/60-legion-mic-enhance.conf" user
lg_info "Recorded. Nothing on the system was changed (default input and audio profile are left as they are)."
