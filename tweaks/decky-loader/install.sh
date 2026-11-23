#!/bin/bash
# decky-loader: install the pinned Decky Loader release (needs sudo for its root system service).
set -euo pipefail
. "$LG_REPO/lib/common.sh"
. "$LG_REPO/tweaks/decky-loader/decky.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lg-decky.XXXXXX"); trap 'rm -rf "$WORK"' EXIT

lg_begin installed
if [ -n "${LG_DECKY_BINARY:-}" ]; then cp "$LG_DECKY_BINARY" "$WORK/PluginLoader"   # offline / test use
else lg_step "Downloading Decky Loader $DECKY_VERSION"; curl -fsSL -o "$WORK/PluginLoader" "$DECKY_URL"; fi
[ "$(lg_sha "$WORK/PluginLoader")" = "$DECKY_SHA" ] || lg_die "Decky Loader checksum mismatch"
lg_ok "Decky Loader $DECKY_VERSION checksum verified"

for d in services settings data logs; do lg_mkdir "$HB/$d" user; done
lg_mkdir "$HB/plugins" root                                # plugins run as root; Decky keeps this root-owned
lg_put_file "$WORK/PluginLoader" "$HB/services/PluginLoader" 755 user
printf '%s\n' "$DECKY_VERSION" | lg_put_content "$HB/services/.loader.version" 644 user
lg_shared_acquire steam-debugger "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
sed "s|@USER_HOME@|$HOME|g" "$LG_REPO/tweaks/decky-loader/files/plugin_loader.service.in" | lg_put_content "$DECKY_UNIT" 644 root
lg_unit_enable root plugin_loader.service --now
lg_root systemctl restart plugin_loader.service
[ "$LG_TEST" = 1 ] || sleep 2
lg_root systemctl is-active --quiet plugin_loader.service || lg_die "plugin_loader.service is not running"
lg_ok "Decky Loader is running"
