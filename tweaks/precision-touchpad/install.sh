#!/bin/bash
# precision-touchpad: install upstream InputPlumber next to the stock package (needs sudo).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/precision-touchpad/common-ip.sh"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/lg-ip.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

lg_begin installed

if [ -n "${LG_IP_TARBALL:-}" ]; then cp "$LG_IP_TARBALL" "$WORK/ip.tar.gz"     # offline / test use
else
    lg_step "Downloading InputPlumber v$IP_VERSION release"
    curl -fsSL -o "$WORK/ip.tar.gz" "$IP_URL"
fi
echo "$IP_TARBALL_SHA  $WORK/ip.tar.gz" | sha256sum -c --quiet - || lg_die "release archive checksum mismatch"
lg_ok "release archive checksum verified"
tar -xzf "$WORK/ip.tar.gz" -C "$WORK"
SRC="$WORK/inputplumber"
[ -d "$SRC/usr/share/inputplumber/devices" ] || lg_die "unexpected archive layout"

BIN="$SRC/usr/bin/inputplumber"
if [ -n "${LG_IP_BINARY:-}" ]; then
    [ -x "$LG_IP_BINARY" ] || lg_die "LG_IP_BINARY=$LG_IP_BINARY is not an executable file"
    "$LG_IP_BINARY" --version 2>/dev/null | grep -q "$IP_VERSION" || lg_die "$LG_IP_BINARY is not InputPlumber $IP_VERSION"
    lg_warn "using your own build $LG_IP_BINARY (sha256 $(lg_sha "$LG_IP_BINARY"))"
    lg_confirm "Install this binary as InputPlumber?" || lg_die "cancelled"
    BIN="$LG_IP_BINARY"
else
    [ "$(lg_sha "$BIN")" = "$IP_RELEASE_BIN_SHA" ] || lg_die "release binary checksum mismatch"
fi
lg_state_set binary_sha "$(lg_sha "$BIN")"

lg_step "Installing to ${IP_DEST#"$LG_ROOT"} (root-owned; /home survives SteamOS updates)"
lg_put_file "$BIN" "$IP_DEST/bin/inputplumber" 755 root
( cd "$SRC/usr/share" && find inputplumber -type f | sort ) > "$WORK/files"
while IFS= read -r f; do
    lg_put_file "$SRC/usr/share/$f" "$IP_DEST/share/$f" 644 root
done < "$WORK/files"
lg_info "$(grep -c . "$WORK/files") device profiles and capability maps installed"

REAL_DEST="${IP_DEST#"$LG_ROOT"}"
lg_put_content "$IP_DEST/bin/inputplumber-launch" 755 root <<LAUNCH
#!/bin/sh
# Installed by legiongo-steamos (precision-touchpad). Fail-safe: runs the stock SteamOS
# InputPlumber whenever the upstream copy is missing or broken.
UP=$REAL_DEST
if [ -x "\$UP/bin/inputplumber" ] && "\$UP/bin/inputplumber" --version >/dev/null 2>&1 \\
   && [ -d "\$UP/share/inputplumber/devices" ]; then
    export XDG_DATA_DIRS="\$UP/share"
    exec "\$UP/bin/inputplumber"
fi
echo "inputplumber-launch: upstream copy unavailable, falling back to stock /usr/bin/inputplumber" >&2
exec /usr/bin/inputplumber
LAUNCH

lg_step "systemd drop-in for inputplumber.service"
lg_put_content "$IP_DROPIN" 644 root <<DROPIN
# legiongo-steamos precision-touchpad: run upstream InputPlumber v$IP_VERSION (Legion Go touchpad poll-rate fix).
# Remove with: ./legiongo.sh uninstall precision-touchpad
[Service]
ExecStart=
ExecStart=$REAL_DEST/bin/inputplumber-launch
DROPIN

lg_step "Restarting InputPlumber (controller input pauses for about 3 seconds)"
lg_root systemctl daemon-reload
lg_root systemctl restart inputplumber.service
[ "$LG_TEST" = 1 ] || sleep 3
lg_root systemctl is-active --quiet inputplumber.service || lg_die "inputplumber.service is not running after the restart"
lg_ok "inputplumber.service is running"
