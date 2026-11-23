#!/bin/bash
# precision-touchpad: extra status lines.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"
for d in "$IP_DEST" "$IP_REF_DEST"; do
    [ -x "$d/bin/inputplumber" ] && echo "binary: $d/bin/inputplumber ($(ip_variant_of "$(lg_sha "$d/bin/inputplumber")"))"
done
echo "inputplumber.service: $(systemctl is-active inputplumber.service 2>/dev/null)"
echo "stock package: $(lg_pkg_version inputplumber)"
