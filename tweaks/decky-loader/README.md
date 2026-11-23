# Decky Loader (pinned, verified)

## Overview

**Reference Verified** (Decky Loader v3.3.1 runs on the reference Legion Go; its binary is identical to the pinned release) · needs sudo · id `decky-loader`

> The community plugin loader for the Steam client, installed from its official release and verified, so Legion Go plugins can run in Gaming Mode.

## Problem

Legion Go-specific controls (per-game TDP, fan curves, button remapping, RGB, charge limit) are not part of SteamOS. They come as Decky plugins (see `decky-power-plugins`). Decky's own installer runs an unpinned `curl | sh` script; this tweak installs a known, verified version and can remove it cleanly.

## Enhancement

It installs [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) v3.3.1 exactly like Decky's own installer does:
- the `PluginLoader` binary in `~/homebrew/services`;
- a root system service `plugin_loader.service`;
- Steam's local debugger flag.

The download is checked against the release's SHA-256 before anything is installed.

## User benefit

It is the base for the Legion Go plugins. On its own it adds only the plugin menu.

### Before vs After

| | Before | After |
|---|---|---|
| Quick Access menu | No plugins | "Decky" entry with plugins |
| Installed version | — | Pinned v3.3.1, checksum-verified |

## Compatibility

Decky Loader v3.3.1 on SteamOS 3.9.5 (reference device). Decky is generic, but this project tests it only on the Legion Go. After a Steam client update, Decky (or a plugin) can stop working until upstream updates. See [docs/THIRD_PARTY.md](../../docs/THIRD_PARTY.md#decky-loader) for recovery.

### Dependencies

- sudo. The service runs as root, as Decky requires.
- Steam's local debugger flag. It is shared with `steam-keyboard` and reference counted: it is removed only when no tweak needs it any more.
- Network access to github.com.

## Installation

```bash
d=~/.local/share/legiongo-steamos/v0.2.3
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install decky-loader
```

Then restart Steam, or switch to Gaming Mode.

## Verification

`systemctl status plugin_loader` is active. In Gaming Mode, press the Quick Access button (…): a plug icon appears.

## Uninstallation

```bash
d=~/.local/share/legiongo-steamos/v0.2.3
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" uninstall decky-loader
```

It refuses while `decky-power-plugins` is installed; uninstall that first. Plugin folders you filled yourself are kept.

## Performance

| | Measured (reference device) |
|---|---|
| Decky Loader (5 processes) | 0.00 % CPU in Desktop Mode at idle, 111 MB RSS in total (Decky's own design) |

## Limitations

- Decky's built-in updater can replace the pinned version. That is your choice, but this tool then reports the files as changed (`partial`).
- Decky loads plugins into the desktop Steam client too. `desktop-power-policy` unloads the power plugins' frontends there.

## Technical details

See [docs/THIRD_PARTY.md](../../docs/THIRD_PARTY.md#decky-loader).
