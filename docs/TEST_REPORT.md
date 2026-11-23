# Test report — v0.2.0

Generated 2026-11-23 on the reference Legion Go (SteamOS 3.9.5). The evidence categories are kept separate: passing installer tests or CI is **not** hardware verification.

## A. Static validation (`tests/run-tests.sh static`, also in GitHub Actions)

- Bash syntax of all scripts; Python syntax of all Python files.
- ShellCheck (warning level) over every script, including `lib/doctor.sh` and `experimental/`: **0 findings**.
- Manifest schema, ids, allowed statuses (Reference Verified / Experimental), dependencies.
- Tweak structure, executable bits, and the ten required README sections.
- Module isolation: no tweak references another tweak's files.
- Secret / personal-data scan: keys, tokens, password assignments and home paths, plus a local git-ignored list of personal strings. **No findings.**

## B. Simulated installation (sandboxed: mock root, stub system commands, real pinned upstream artifacts)

Final run: **103 passed, 0 failed, 0 skipped.** Covered:

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
- untested SteamOS -> state untested
- untested SteamOS -> install needs --force
- untested SteamOS -> --force installs
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
- multilingual: helper layout matching and language report
- lib: replaced file restored with original content
- lib: replaced file restored with original mode

## C. Existing reference-device evidence (development sessions)

| Tweak | Evidence |
|---|---|
| steam-keyboard | All features confirmed by the owner. Tab/Shift+Tab: trusted Chrome key events and live typing. EN/RU input in Chrome and RustDesk. |
| precision-touchpad | 42 → 106 Hz. Taps ≥ 5 px: 36 % → 7 % (tapfilter, 138 taps), 35 % (glide, 118 taps). glide in daily use since 2026-11-16. |
| desktop-touchpad | Steam exit → pad works; Steam restart → no double movement (owner). |
| decky-loader | v3.3.1 running since 2026-11-14; binary identical to the pinned release. |
| decky-power-plugins | SimpleDeckyTDP settings read back after the first apply; touchpad and LED state unchanged after LegionGoRemapper load. Controller features not tested. |
| desktop-power-policy | 7.86 → 7.11 W on battery at idle; 22 suspend/resume cycles logged. AC path untested. |
| mic-enhance | Default source in daily use; tuned by ear. |

## D. Verification done for this release on the reference device

- **Reproducible builds:** glide and tapfilter InputPlumber rebuilt from the pristine v0.84.0 source plus our patches are bit-identical to the device-tested binaries. The LegionGoRemapper v0.3.0 release plus our patch is byte-identical to the installed plugin.
- **Read-only `list`, `doctor`, `check`:** all modules were detected correctly, including Decky Loader and the plugins as `external`.
- **Adoption of `decky-loader` and `decky-power-plugins`:** 75 files compared, none changed, service still active. (The other five were adopted in v0.1.0; 163 files unchanged.)
- **Multilingual Input Support, controlled live check:**
  1. v41 was loaded into the running Steam client.
  2. It detected the enabled Steam layouts `[qwerty → us, russian → ru]` and tracked the current language, with no unsupported hooks.
  3. Nothing was typed. The installed v40 was restored immediately and the KDE layout returned to `us`.

## Still requires physical checks (not performed)

- steam-keyboard v41 end-to-end with the new helper:
  1. Switch EN ↔ RU with 🌐 and type in Chrome.
  2. Hide the keyboard: the KDE layout returns to your own.
  3. A language without a KDE layout appears in `status`.
  4. Tab in Russian; Hide after Tab; rapid Tab.
- Other Steam keyboard languages (German, French, ...) by native speakers.
- precision-touchpad: double-tap and tap-and-drag with patched builds; Gaming Mode.
- desktop-touchpad: Steam crash, resume, Gaming → Desktop.
- desktop-power-policy: AC path.
- decky-power-plugins: LegionGoRemapper remapping, fan curves, charge limit.
- A fresh install on a second Legion Go: none is available. The installers were designed and tested to depend on nothing specific to the reference device.
