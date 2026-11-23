# shellcheck shell=bash
# shellcheck disable=SC2034  # constants used by the scripts that source this file
# decky-loader: pinned upstream release (https://github.com/SteamDeckHomebrew/decky-loader, GPL-2.0)
DECKY_VERSION=v3.3.1
DECKY_URL="https://github.com/SteamDeckHomebrew/decky-loader/releases/download/$DECKY_VERSION/PluginLoader"
DECKY_SHA=7bb73b0502c49e7194f34f9ce4ddb6777764e9277d7a5e54665f66460d50c315   # GitHub release asset digest
HB="$HOME/homebrew"
DECKY_UNIT="$LG_ROOT/etc/systemd/system/plugin_loader.service"
