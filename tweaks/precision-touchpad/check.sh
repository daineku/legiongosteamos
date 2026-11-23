#!/bin/bash
# precision-touchpad: requirements and detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"

lg_check_platform yes
lg_req "InputPlumber service present" test -e "$LG_ROOT/usr/lib/systemd/system/inputplumber.service"
lg_req "download and verification tools (curl, tar, sha256sum)" lg_have curl tar sha256sum
stock=$(lg_pkg_version inputplumber)
not_needed=""
if [ -n "$stock" ]; then
    if lg_version_ge "$stock" "$IP_FIXED_IN"; then
        lg_ok "SteamOS ships InputPlumber $stock, which already contains the touchpad fix"
        not_needed="SteamOS InputPlumber $stock already includes the fix (>= $IP_FIXED_IN)"
    else
        lg_ok "SteamOS ships InputPlumber $stock (touchpad fix arrived upstream in $IP_FIXED_IN)"
    fi
fi

external=0; detail=""
for f in "$IP_DROPIN_DIR"/*.conf; do
    [ -e "$f" ] || continue
    [ "$f" = "$IP_DROPIN" ] && continue
    if grep -q '^ExecStart=.' "$f"; then
        external=1
        bin=""; [ -x "$IP_REF_DEST/bin/inputplumber" ] && bin="$IP_REF_DEST/bin/inputplumber"
        detail="InputPlumber override $(basename "$f") ($(ip_variant_of "$(lg_sha "$bin")"))"
        lg_info "found existing override: $f"
    fi
done
if ! lg_is_tracked_tweak && [ "$external" = 0 ] && [ -n "$not_needed" ]; then
    echo "RESULT=not-needed $not_needed"; exit 0
fi
lg_check_result "$external" "" "$detail"
