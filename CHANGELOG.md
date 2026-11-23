# Changelog

## 0.2.1 — 2026-11-23

- One-command lines are pinned to `v0.2.1`, a lightweight tag, with git's detached-HEAD advice turned off, so the bootstrap clone prints no confusing git messages. No tweak changed (same code as 0.2.0).

## 0.2.0 — 2026-11-23

- **One-command install, uninstall and update** for every tweak (pinned release checkout; no curl-to-shell).
- New commands: `update <tweak>` (one tweak only, idempotent repair) and `doctor` (privacy-safe compatibility report).
- **Evidence-based statuses:**
  - Reference Verified / Experimental per tweak;
  - `upstream-equivalent` / `incompatible` per device;
  - feature-level compatibility probes instead of version cut-offs.
- Transactional dependency rollback. Uninstall refuses to remove a dependency still in use. Shared files are reference counted.
- `steam-keyboard` 41.0.0:
  - **Multilingual Input Support** replaces the English/Russian-only sync: all Steam keyboard layouts are mapped, the enabled languages are detected, the exact KDE layout/variant is synced, the user's own layout is restored, and per-language compatibility is reported;
  - `LG_KEYBOARD_LAYOUTS` option.
- `precision-touchpad` 0.84.0-2:
  - variants `glide` (default, reference build), `tapfilter`, `release`;
  - reproducible patched binaries published as release assets and checksum-pinned;
  - no longer considered unnecessary because of a version number;
  - refuses downgrades.
- New `decky-loader` (pinned v3.3.1) and `decky-power-plugins` (SimpleDeckyTDP v1.0.7 + LegionGoRemapper v0.3.0 with our safety patch and safe settings).
- Wi-Fi re-investigated: no distributable fix. Measurement tool in `experimental/wifi-reliability/`.
- Docs: simplified README and tweak guides; THIRD_PARTY.md, MAINTAINING.md, technical docs.
- GitHub Actions: CI (static + sandbox tests) and weekly upstream-watch review issues.

## 0.1.0 — 2026-11-23

First public release, extracted from the reference Legion Go.

- Installer `legiongo.sh`: `list`, `info`, `check`, `install`, `status`, `uninstall`, `adopt`. State tracking, atomic writes, backups, automatic rollback of failed installs, adoption of existing manual setups.
- `steam-keyboard` 40.0.0 (Partially Verified): native Steam keyboard enhancements for Desktop Mode, including genuine Tab/Shift+Tab.
- `precision-touchpad` 0.84.0-1 (Partially Verified): upstream InputPlumber 0.84.0 override. Optional, reproducible `glide` and `tapfilter` patched builds (Experimental).
- `desktop-touchpad` 1.0.0 (Partially Verified): touchpad keeps working when Steam is not running.
- `desktop-power-policy` 1.0.0 (Experimental): Desktop Mode firmware profile/EPP policy.
- `mic-enhance` 1.0.0 (Experimental): PipeWire filter-chain for the internal microphone.
- Test suite: static checks, ShellCheck, secret scan, 70+ sandboxed install/uninstall tests.
