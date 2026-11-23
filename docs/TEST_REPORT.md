# Test report — v0.2.2-beta

Generated 2026-11-24 on the reference Legion Go (SteamOS 3.9.5). The evidence categories are kept separate: passing installer tests or CI is **not** hardware verification.

## A. Static validation (`tests/run-tests.sh static`, also in GitHub Actions)

- Bash syntax of all scripts; Python syntax of all Python files.
- ShellCheck (warning level) over every script, including `lib/doctor.sh` and `experimental/`: **0 findings**.
- Manifest schema (layer, category, hardware, version policy), ids, allowed statuses (Reference Verified / Cross-device Verified / Experimental / Unsupported), dependencies; Legion Go tweaks must be in the hardware layer.
- Tweak structure, executable bits, and the ten required README sections.
- Module isolation: no tweak references another tweak's files.
- Secret / personal-data scan: keys, tokens, password assignments and home paths, plus a local git-ignored list of personal strings. **No findings.**

## B. Simulated installation (sandboxed: mock root, stub system commands, real pinned upstream artifacts)

Final run: **128 passed, 0 failed, 0 skipped** (locally, with all pinned upstream artifacts; GitHub Actions runs the same suite). Covered:

- First install, verification, idempotent re-install, uninstall: all seven tweaks.
- User-edited files kept on uninstall and reported as `partial`; replaced files restored with their original mode.
- Interrupted install recovery:
  - a refused confirmation and a failing service start are both rolled back;
  - a corrupt plugin archive rolls back the plugin tweak **and** the dependency installed in the same command.
- Dependencies: never installed without permission; satisfied by stock software that already has the feature; uninstall refused while a dependent tweak is installed.
- Shared Steam debugger flag: reference counted between `steam-keyboard` and `decky-loader`; kept for an unmanaged Decky Loader; removed only after the last holder.
- Feature-level detection for `precision-touchpad`:
  - stock 0.78 path → installable;
  - native stock driver + `release` → `upstream-equivalent`; native driver + `glide` → still installable;
  - stock newer than 0.84 → `conflict` (no downgrade);
  - unknown variant → `incompatible`.
- Patched InputPlumber variant install with checksum pinning; a wrong binary is rejected and nothing is left behind.
- Decky Loader (real v3.3.1 binary) and the plugins (real v1.0.7 / v0.3.0 archives): the safety patch applies and safe settings are seeded.
- `update`: a current tweak is a no-op, an older version is updated, other tweaks are untouched, and tweaks that are not installed are refused.
- `doctor` runs and prints no home path.
- Multilingual Input Support: KDE layout/variant matching and the language report (`tests/test_lgk_helper.py`); `LG_KEYBOARD_LAYOUTS` adds layouts with variants and restores them on uninstall.
- Unsupported device / untested SteamOS / `--force`; external setup detection, adoption without changes, uninstall of adopted setups.

- New in v0.2.2-beta:
  - **verification is authoritative**: a failing functional check exits non-zero and rolls back files and KDE settings;
  - `status` reports working / not working;
  - **InputPlumber launcher**: normal start, no downgrade when stock is newer, fallback after a crash loop (and it is logged), broken build → stock, emergency restore script installed;
  - **cross-device**: portable and capability tweaks are installable on a non-Legion device, Legion Go tweaks are incompatible there with an explanation, and `--force` cannot bypass hardware;
  - the power policy is incompatible without any power interface;
  - **input profiles**: dual-joystick, dual-trackpad, touchscreen;
  - **version policy**: tested vs feature.

Individual results:

- bash syntax of all scripts
- python syntax
- manifest.json schema, ids, statuses, dependencies
- tweak structure, permissions and README sections
- module isolation (no cross-tweak file references)
- shellcheck via docker.io/koalaman/shellcheck:stable (warnings and errors)
- secret / personal-data scan
- list runs
- info runs
- unknown tweak rejected
- steam-keyboard: not-installed before install
- steam-keyboard: install (--yes creates the debugger flag)
- steam-keyboard: state installed
- steam-keyboard: files installed
- steam-keyboard: unit enabled
- steam-keyboard: KWin rule added
- steam-keyboard: re-install
- steam-keyboard: re-install is idempotent (no duplicate records)
- steam-keyboard: KWin rule not duplicated
- steam-keyboard: partial detected after user edit
- steam-keyboard: uninstall keeps the user-edited unit
- steam-keyboard: uninstall removed unchanged files
- steam-keyboard: KWin rule removed
- steam-keyboard: debugger flag removed (created by us, no Decky)
- steam-keyboard: state archived
- steam-keyboard: install refused without confirmation (no tty, flag missing)
- steam-keyboard: failed install rolled back
- steam-keyboard: debugger flag kept when an unmanaged Decky Loader is present
- steam-keyboard: LG_KEYBOARD_LAYOUTS adds layouts and variants
- steam-keyboard: invalid layout code rejected
- steam-keyboard: layout list restored
- steam-keyboard: pre-existing debugger flag untouched
- steam-keyboard: external setup detected
- steam-keyboard: install refuses over external setup
- steam-keyboard: uninstall refuses unmanaged setup
- steam-keyboard: adopt
- steam-keyboard: adopt changed no files
- steam-keyboard: adopted state reported as installed
- steam-keyboard: uninstall of adopted setup
- steam-keyboard: adopted files removed
- steam-keyboard: adopted unit disabled
- unsupported device -> precision-touchpad incompatible
- unsupported device -> install refused
- other device -> steam-keyboard (portable) installable
- other device -> mic-enhance (capability) installable
- other device -> desktop-power-policy installable when EPP/boost exist
- other device -> legion-go tweaks incompatible
- other device -> check explains why
- other device without any power interface -> desktop-power-policy incompatible
- --force does not bypass missing hardware
- input profiles: InputPlumber virtual Deck controller + touchscreen
- input profiles: Steam Deck controller -> dual-trackpad (bridge stays off)
- untested SteamOS -> 'tested'-policy tweak reports untested
- untested SteamOS -> 'tested'-policy install needs --force
- untested SteamOS -> 'feature'-policy tweak decided by feature checks
- untested SteamOS -> feature-policy install works
- precision-touchpad: stock 0.78 path -> installable
- native stock driver + release variant -> upstream-equivalent
- native stock driver + glide variant -> still installable (tap filter)
- newer stock InputPlumber -> conflict (no downgrade)
- unknown variant rejected
- desktop-touchpad: dependency not installed without permission
- desktop-touchpad: nothing installed after refusal
- desktop-touchpad: installs when stock InputPlumber already has the native driver
- desktop-touchpad: KDE tap-to-click off for the native pad
- desktop-touchpad: tap setting removed again
- mic-enhance: install
- mic-enhance: node templated
- mic-enhance: default source set
- mic-enhance: default source restored
- mic-enhance: conf removed
- power: install
- power: user home templated
- power: no sudo used in test mode
- power: files removed
- power: empty /etc/legion-power removed
- power: firmware profile restored
- precision-touchpad: release variant install from verified archive
- precision-touchpad: binary checksum
- precision-touchpad: drop-in points to launcher
- precision-touchpad: re-install idempotent
- precision-touchpad: uninstall
- precision-touchpad: tree and drop-in removed
- precision-touchpad: failing service start is rolled back
- precision-touchpad: nothing left after rollback
- precision-touchpad: tapfilter variant install (checksum-pinned binary)
- precision-touchpad: tapfilter binary installed
- precision-touchpad: update is a no-op when current
- precision-touchpad: wrong patched binary rejected by checksum
- precision-touchpad: nothing left after rejected binary
- update: current tweak reports up to date
- update: older installed version is updated
- update: version recorded after update
- update: does not touch other tweaks
- update: refuses tweaks that are not installed
- doctor runs and prints no home path
- decky-power-plugins: dependency refused without permission
- decky-power-plugins: nothing installed after refusal
- decky-power-plugins: installs with its dependency (--yes)
- decky-loader: pinned binary installed
- decky-loader: unit templated with the user's home
- decky-power-plugins: safety patch applied
- decky-power-plugins: safe settings seeded
- decky-loader: refuses uninstall while plugins depend on it
- shared flag: held by decky-loader and steam-keyboard
- shared flag: kept while decky-loader still needs it
- shared flag: removed after the last holder (created by us)
- decky: plugins, binary and unit removed
- transaction: failing plugin install fails
- transaction: dependency installed in the same command rolled back
- verify: failing functional check -> install exits nonzero
- verify: failed install is rolled back (no files, no state)
- verify: KDE setting restored after the failed install
- verify: healthy install passes verification
- status: reports the tweak as working
- status: reports a stopped service as not working
- verify: mic-enhance verified
- launcher: runs the maintained build normally
- launcher: stock newer than the build -> stock (no downgrade)
- launcher: 4 starts within 180 s -> stock until reboot
- launcher: crash-loop fallback is logged
- launcher: broken build -> stock
- precision-touchpad: no controller exposed -> verification fails, rolled back
- precision-touchpad: nothing left after failed verification
- precision-touchpad: emergency restore script installed
- multilingual: helper layout matching and language report
- lib: replaced file restored with original content
- lib: replaced file restored with original mode

## C. Reference-device evidence (physical, the reference Legion Go)

| Tweak | Evidence | Status |
|---|---|---|
| steam-keyboard | v40 (all features) confirmed by the owner over weeks; Tab/Shift+Tab via trusted Chrome events. **v41 live check 2026-11-23:** Russian and English typed as real keys in Chrome, Tab, Shift+Tab via the on-screen Shift, language switch → KDE layout follows (confirmed back), Hide → own layout restored, reopen → synced, no unsupported hooks. The controller bridge is byte-identical to v40. | Reference Verified |
| precision-touchpad | 42 → 106 Hz; taps ≥ 5 px: 36 % → 7 % (tapfilter); glide in daily use since 2026-11-16; published binaries bit-identical to the device builds | Reference Verified |
| desktop-touchpad | Steam exit/restart checked by the owner; 6 automatic hand-over cycles and 4 re-enumerations logged, 0 failures | Reference Verified |
| desktop-power-policy | battery −0.75 W idle; 7 AC switches + 46 battery applications logged, 0 errors; 22+ resumes | Reference Verified |
| mic-enhance | default input in daily use | Reference Verified |
| decky-loader | v3.3.1 running since 2026-11-14 | Reference Verified |
| decky-power-plugins | safe first start read back; SimpleDeckyTDP per-game profile in use. LegionGoRemapper controller features never enabled. | Reference Verified / Experimental (those features) |

## D. Done for this release on the reference device

- **Read-only `list`, `status` (with functional verification) and `doctor`:** all seven tweaks report `working: yes`.
- **Resource audit (idle, 60 s):** keyboard helper, hand-over, power policy and mic filter at 0.00 % CPU. InputPlumber stock vs 0.84 release vs glide compared using temporary runtime drop-ins; the original setup was restored and checked.
- **CPU boost on/off:** power and benchmark on battery. Boost was restored to on.
- **Keyboard v41:** run from a scratch copy, then the installed v40 restored (service active, v40 re-injected, KDE layout `us`, test KWin script unloaded).
- **Device configuration backup:** `~/.local/state/legiongo-steamos/device-backups/`.

## Not verified (genuinely open)

- Any feature on a second physical device: no Cross-device Verified entries yet.
- Other Steam keyboard languages by native speakers.
- LegionGoRemapper remapping, RGB, fan curves and charge limit.
- Power draw on AC, browser workloads, and the battery cost of InputPlumber 0.84's extra CPU.
- The new launcher fallbacks (crash loop, newer stock) on hardware: they are tested in the sandbox with fake binaries and never triggered on the device.
