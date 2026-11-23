#!/bin/bash
# desktop-touchpad: record the existing manual (reference) setup without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
lg_begin adopted
lg_adopt_file "$HOME/.local/lib/legion-desktop-build/legion-tp-handover.py" user
lg_adopt_file "$HOME/.config/systemd/user/legion-tp-handover.service" user
lg_adopt_unit user legion-tp-handover.service
lg_info "Recorded. Nothing on the system was changed. KDE touchpad settings are left as they are."
