# Changelog

## Unreleased

- Real screenshots of the Steam keyboard enhancement (bottom and top position) from the reference Legion Go, in the README and the keyboard guide.

## 0.2.2-beta — 2026-11-24

**Release hardening**
- Post-install verification is authoritative. Every tweak with a runtime part has a functional `verify.sh`, and a failure exits non-zero and rolls the installation back. `status` shows `working: yes/NO`. Crash loops are detected even when systemd reports "active".
- InputPlumber launcher:
  - falls back to stock after 4 starts in 180 s (retries at the next boot);
  - never downgrades when SteamOS ships a newer InputPlumber;
  - new emergency `legiongo-ip-restore-stock` for SSH/TTY.
- `desktop-power-policy` records and restores the CPU boost state.

**Cross-device architecture**
- Three layers (native SteamOS / portable / Legion Go hardware). Manifests declare `layer`, `category`, `hardware` (portable | capability | legion-go) and `version_policy`.
- Portable tweaks (steam-keyboard, mic-enhance, desktop-power-policy, decky-loader) are no longer locked to the Legion Go DMI. Capability probes decide; `check` explains why something is unavailable. Hardware tweaks keep the DMI gate, which `--force` cannot bypass.
- Keyboard input profiles are detected: dual-joystick (InputPlumber virtual Deck controller), dual-trackpad (Steam Deck: Steam's own typing, bridge off), touchscreen.
- The power policy works by capability: EPP, CPU boost control, Lenovo firmware profiles.

**Verification model**
- Statuses: Reference Verified / Cross-device Verified / Experimental / Unsupported.
- All seven tweaks are Reference Verified on the reference Legion Go, based on device evidence: keyboard v41 verified live; AC path, hand-over cycles and SimpleDeckyTDP use found in the logs. Per-feature exceptions are documented (LegionGoRemapper controller features).

**Measurements and documentation**
- New `docs/PERFORMANCE.md`: idle CPU, memory and wake-ups of every component; InputPlumber 0.78 vs 0.84 vs glide; CPU boost on/off power and performance.
- README reorganised: "Native Compatibility & Enhancements", architecture diagram, catalog by category, dual-joystick typing.
- Compatibility matrix per device class.
- 128 sandbox tests: verification failure and rollback, launcher recovery, cross-device detection, input profiles, version policy.

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
