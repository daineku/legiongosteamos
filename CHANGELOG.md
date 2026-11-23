# Changelog

## 0.1.0 — 2026-11-23

First public release, extracted from the reference Legion Go.

- Installer `legiongo.sh`: `list`, `info`, `check`, `install`, `status`, `uninstall`, `adopt`. State tracking, atomic writes, backups, automatic rollback of failed installs, adoption of existing manual setups.
- `steam-keyboard` 40.0.0 (Partially Verified): native Steam keyboard enhancements for Desktop Mode, including genuine Tab/Shift+Tab.
- `precision-touchpad` 0.84.0-1 (Partially Verified): upstream InputPlumber 0.84.0 override. Optional, reproducible `glide` and `tapfilter` patched builds (Experimental).
- `desktop-touchpad` 1.0.0 (Partially Verified): touchpad keeps working when Steam is not running.
- `desktop-power-policy` 1.0.0 (Experimental): Desktop Mode firmware profile/EPP policy.
- `mic-enhance` 1.0.0 (Experimental): PipeWire filter-chain for the internal microphone.
- Test suite: static checks, ShellCheck, secret scan, 70+ sandboxed install/uninstall tests.
