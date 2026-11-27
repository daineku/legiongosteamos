# Changelog

## 0.2.5 — 2026-11-27

- `steam-keyboard` 46.0.0, **fix: Russian letters (notably `о`) not typing.**
  - Steam's own character-to-key table went stale and sent `о` as the "web browser" media key. This was not caused by our code: the previous v40 script failed identically, and a Steam restart cleared it.
  - On English and Russian (layouts whose Steam key grid matches XKB), keys are now sent as the physical key at their position, so Steam's table is no longer involved.
  - Shift, Caps Lock, shifted symbols, Space, Backspace, Enter and double space are all covered, and typing order is preserved.
  - Fixed during testing:
    - after a helper restart, a stale layout confirmation could have typed Latin; the helper now always re-syncs on connect;
    - after a helper restart, closing the keyboard could have left KDE on Russian; your default layout is now restored.
  - Verified live on the reference device.

## 0.2.4 — 2026-11-27

- New tweak `smart-auto-brightness` 1.0.0 (Experimental). KWin's built-in automatic brightness maps lux to an absolute brightness after a 2 s timer, so a hand over the Legion Go's sensor dimmed the screen from 100 % to about 33 %. The new controller replaces it:
  - it stays within ±10 % of the brightness you set, and any manual change is the new baseline;
  - it ignores shadows (90th-percentile light over 30 s, two agreeing evaluations);
  - it ramps softly and restores KWin's setting on uninstall.
- Docs and install lines pinned to `v0.2.4`.

- `steam-keyboard` 44.0.0:
  - **Fix: the touchpad no longer highlights G.** Steam's focus navigation treated touchpad touches as controller input and showed its focus ring on the keyboard's default key, where a controller A press could also type. Touchpad buttons are now swallowed at Steam's own catch-all input hook while the keyboard is open on dual-joystick devices. That capability is sent at injection time, so there is no race when the keyboard opens.
  - **New: double Space → `. `** with a one-shot Shift for the next letter. 250 ms window calibrated on real double taps; only after a letter or digit; off in terminals, code editors and remote-desktop apps; can be disabled with a flag file.
  - Both verified live on the reference device by the owner (sticks, LT/R3 and RT unchanged).

## 0.2.3 — 2026-11-24 (stable for the reference environment)

**Installer**
- Three install outcomes: **INSTALLED & VERIFIED**, **INSTALLED — VERIFICATION PENDING** (it can't be tested now; never reported as verified), **FAILED** (rolled back, non-zero exit).
- The verification result is recorded in the state.
- `status` shows the live functional state.
- `doctor` marks tweaks as working, verification pending or BROKEN.
- `update` no longer calls a tweak "up to date" when its files are intact but its functional check fails; it repairs it.

**Portable CPU boost**
- `desktop-power-policy` also keeps the global cpufreq `boost` switch and Intel `intel_pstate/no_turbo` enabled in Desktop Mode. A device with only one of these interfaces is no longer rejected.
- The previous values are restored on uninstall.
- The policy logic is unit-tested on fake AMD and Intel sysfs trees. On the reference device, the modified policy applied identical values with no errors.

**Presentation**
- The README is the landing page: original Plasma/Breeze-inspired wordmark and architecture diagram (SVG, dark and light), status links, the real screenshots, "Two joysticks. One native Steam keyboard.", typing features, catalog, installation, compatibility and performance with trade-offs.
- All tweak guides share one layout (Overview, Problem, Enhancement, User benefit, Compatibility, Installation, Verification, Uninstallation, Performance, Limitations, Technical details), each with a measured Performance section.
- The README and keyboard guide describe long-press symbols, emoji on 🌐 hold, multi-touch modifiers and Backspace word deletion. Real screenshots of the keyboard (bottom and top placement) are included.
- All one-command lines are pinned to `v0.2.3`.

**Tests:** 142 sandbox tests (new: state model, update repair, doctor states, CPU boost capabilities and restore, power policy unit test).

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
