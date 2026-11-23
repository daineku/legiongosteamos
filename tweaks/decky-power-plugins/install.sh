#!/bin/bash
# decky-power-plugins: install the pinned plugin releases + safety patch + safe settings (needs sudo:
# Decky's plugin folder is root-owned because plugins with the "root" flag run as root).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-power-plugins/plugins.sh"
T="$LG_REPO/tweaks/decky-power-plugins"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lg-plugins.XXXXXX"); trap 'rm -rf "$WORK"' EXIT

fetch() {   # fetch URL SHA OUT [LOCAL_COPY]
    if [ -n "${4:-}" ]; then cp "$4" "$3"; else curl -fsSL -o "$3" "$1"; fi
    [ "$(lg_sha "$3")" = "$2" ] || lg_die "checksum mismatch for $(basename "$1")"
}
lg_begin installed
lg_step "Downloading SimpleDeckyTDP $SDTDP_VERSION and LegionGoRemapper $LGR_VERSION"
fetch "$SDTDP_URL" "$SDTDP_SHA" "$WORK/sdtdp.zip" "${LG_SDTDP_ZIP:-}"
fetch "$LGR_URL" "$LGR_SHA" "$WORK/lgr.tar.gz" "${LG_LGR_TARBALL:-}"
lg_ok "release checksums verified"
mkdir -p "$WORK/x"
unzip -q "$WORK/sdtdp.zip" -d "$WORK/x"
tar -xzf "$WORK/lgr.tar.gz" -C "$WORK/x"
(cd "$WORK/x/LegionGoRemapper" && git apply -p1 "$T/patches/LegionGoRemapper-v0.3.0-safety.patch")
lg_ok "LegionGoRemapper safety patch applied"
printf '%s\n' "Patched by legiongo-steamos (decky-power-plugins): see patches/LegionGoRemapper-v0.3.0-safety.patch" \
    > "$WORK/x/LegionGoRemapper/LEGIONGO-STEAMOS-PATCHES.txt"

lg_step "Installing plugins into ~/homebrew/plugins"
for p in SimpleDeckyTDP LegionGoRemapper; do
    while IFS= read -r f; do
        mode=644; [ -x "$WORK/x/$p/$f" ] && mode=755
        lg_put_file "$WORK/x/$p/$f" "$HB/plugins/$p/$f" "$mode" root
    done < <(cd "$WORK/x/$p" && find . -type f | sed 's|^\./||' | sort)
done
# Conservative starting settings, only where the plugin has none yet (your own settings are never replaced)
for p in SimpleDeckyTDP LegionGoRemapper; do
    if [ ! -e "$HB/settings/$p/settings.json" ]; then
        lg_put_file "$T/files/$p-settings.json" "$HB/settings/$p/settings.json" 644 user
        lg_info "$p: safe starting settings written"
    else
        lg_info "$p: existing settings kept"
    fi
done
lg_root systemctl restart plugin_loader.service 2>/dev/null || lg_warn "could not restart Decky Loader; restart Steam to load the plugins"
lg_info "Not installed on purpose: LegionGoRemapper's optional udev rule (it makes every Lenovo USB device world-writable)."
