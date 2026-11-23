#!/bin/bash
# desktop-power-policy: record the existing /etc/legion-power setup without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
lg_begin adopted
lg_adopt_file "$LG_ROOT/etc/legion-power/legion-power-policy.py" root
lg_adopt_file "$LG_ROOT/etc/systemd/system/legion-power-policy.service" root
lg_adopt_unit root legion-power-policy.service
lg_info "Recorded. Nothing on the system was changed."
lg_info "Other parts of a manual power setup (acpi_call, Decky plugins) are not managed by this tweak."
