#!/bin/bash
# precision-touchpad: requirements and feature-level detection. Changes nothing.
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"

lg_check_platform yes
lg_req "InputPlumber service present" test -e "$LG_ROOT/usr/lib/systemd/system/inputplumber.service"
lg_req "download and verification tools (curl, tar, sha256sum)" lg_have curl tar sha256sum
case "$IP_VARIANT" in release|glide|tapfilter) lg_ok "variant: $IP_VARIANT" ;;
    *) lg_error "unknown LG_IP_VARIANT '$IP_VARIANT' (release, glide, tapfilter)"; LG_FAIL=1 ;; esac

stock=$(lg_pkg_version inputplumber)
equivalent=""; conflict=""
if ip_stock_has_native_touchpad; then
    lg_info "stock InputPlumber ${stock:-?} already reads the touchpad natively (~106 Hz path)"
    # The rate fix is upstream now; the patched variants still add the lift-off tap filter.
    # As a dependency (desktop-touchpad) only the native driver matters, which stock already has.
    { [ "$IP_VARIANT" = release ] || [ "${LG_AS_DEPENDENCY:-0}" = 1 ]; } && equivalent="stock InputPlumber ${stock:-?} already includes the native touchpad driver; the 'release' variant would add nothing (the glide/tapfilter variants still add tap filtering)"
else
    lg_ok "stock InputPlumber ${stock:-?} uses the ~40 Hz gamepad-report touchpad path: this tweak improves it"
fi
if [ -n "$stock" ] && [ "$(lg_vercmp "$stock" "$IP_VERSION")" = 1 ]; then
    conflict="stock InputPlumber $stock is newer than this tweak's base $IP_VERSION; installing would downgrade it. The patches must be rebuilt for $stock first (docs/MAINTAINING.md)"
    lg_warn "$conflict"
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
[ "${LG_AS_DEPENDENCY:-0}" = 1 ] && [ -n "$equivalent" ] && conflict=""
if ! lg_is_tracked_tweak && [ "$external" = 0 ] && [ -z "$conflict" ] && [ -n "$equivalent" ] && [ "$LG_FAIL" = 0 ]; then
    echo "RESULT=upstream-equivalent $equivalent"; exit 0
fi
lg_is_tracked_tweak && conflict=""
lg_check_result "$external" "$conflict" "$detail"
