#!/bin/bash
# smart-auto-brightness: uninstall. Stopping the service hands automatic brightness back to KWin (as before).
set -uo pipefail
. "$LG_REPO/lib/common.sh"
lg_rollback; kept=$?
lg_state_archive
lg_info "KWin's automatic brightness is back to its setting from before installation."
[ "$kept" = 0 ]
