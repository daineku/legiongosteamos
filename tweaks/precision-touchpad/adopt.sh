#!/bin/bash
# precision-touchpad: record the existing manual override (reference setup) without changing it.
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"

[ -e "$IP_REF_DROPIN" ] || lg_die "no known override to adopt (expected $IP_REF_DROPIN)"
lg_begin adopted
lg_state_set binary_sha "$(lg_sha "$IP_REF_DEST/bin/inputplumber")"
lg_state_set variant "$(ip_variant_of "$(lg_sha "$IP_REF_DEST/bin/inputplumber")")"
while IFS= read -r f; do lg_adopt_file "$f" root; done < <(find "$IP_REF_DEST" -type f | sort)
while IFS= read -r d; do lg_manifest_add dir "$d" root 755 "" ""; done < <(find "$IP_REF_DEST" -type d | sort)
lg_adopt_file "$IP_REF_DROPIN" root
lg_info "Recorded the override ($(lg_state_get variant)). Nothing on the system was changed."
