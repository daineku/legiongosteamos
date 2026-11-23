# Test report

Generated 2026-11-23 on the reference Legion Go (SteamOS 3.9.5). The categories below are kept separate on purpose: passing installer tests does **not** mean a tweak is hardware-verified.

## A. Static code validation (automated, `tests/run-tests.sh static`)

- Bash syntax (`bash -n`) of every script; Python syntax of every Python file.
- ShellCheck 0.11 (`docker.io/koalaman/shellcheck:stable`), severity warning and up: **0 findings**.
- `manifest.json` schema, ids, allowed status values, and that every dependency exists.
- Tweak structure: required files, executable bits, all ten README sections.
- Module isolation: no tweak references another tweak's files.
- Secret / personal-data scan: private keys, GitHub/AWS/Slack tokens, password or token assignments, home paths, plus a local git-ignored list of personal strings (e-mail, Wi-Fi name, device IDs). **No findings.**

## B. Simulated installation tests (automated, sandboxed)

Each run uses a throwaway HOME, a mock system root (`LG_ROOT`) with DMI, `os-release` and sysfs, stub commands (`systemctl`, `kwriteconfig6`/`kreadconfig6`, `pactl`, `pw-dump`, `pacman`, `busctl`) and `LG_TEST=1`. A `sudo` stub fails the test if it is ever called. `precision-touchpad` uses the real upstream v0.84.0 release archive (checksum-verified).

Result of the final run: **72 passed, 0 failed, 0 skipped.**

Covered:
- Install, verify, idempotent re-install (no duplicate records), uninstall for every tweak.
- Files edited by the user after install are kept on uninstall and reported as `partial`.
- Replaced pre-existing files are restored with their original content and mode.
- Shared KDE config edited key by key; the KWin rule is not duplicated; the optional `ru` layout is restored.
- Steam's debugger flag: never created without confirmation, removed only if created by the tweak, kept when Decky Loader is present.
- Automatic rollback of a failed install (refused confirmation; InputPlumber failing to start).
- External setup detection, refusal to overwrite it, adoption without changing any file, uninstall of an adopted setup.
- Unsupported device, untested SteamOS version (`--force`), `not-needed` when stock InputPlumber is new enough.
- Dependency handling: no dependency installed without permission; satisfied by a new-enough stock package.
- Root tweaks write only inside the mock root and never call sudo in test mode.

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
- steam-keyboard: debugger flag kept when Decky Loader is installed
- steam-keyboard: LG_KEYBOARD_ADD_RU adds ru
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
- unsupported device -> precision-touchpad unsupported
- unsupported device -> install refused
- untested SteamOS -> state untested
- untested SteamOS -> install needs --force
- untested SteamOS -> --force installs
- newer stock InputPlumber -> precision-touchpad not-needed
- desktop-touchpad: dependency not installed without permission
- desktop-touchpad: nothing installed after refusal
- desktop-touchpad: installs when stock InputPlumber already has the fix
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
- precision-touchpad: install from verified release archive
- precision-touchpad: binary checksum
- precision-touchpad: drop-in points to launcher
- precision-touchpad: re-install idempotent
- precision-touchpad: uninstall
- precision-touchpad: tree and drop-in removed
- precision-touchpad: failing service start is rolled back
- precision-touchpad: nothing left after rollback
- lib: replaced file restored with original content
- lib: replaced file restored with original mode

## C. Existing live-device evidence (from the development sessions, not re-run by the installer)

| Tweak | Evidence |
|---|---|
| steam-keyboard | All listed features confirmed by the owner on the device. Tab/Shift+Tab: trusted `keydown key=Tab code=Tab` events and focus moves logged on a local Chrome form, plus the owner typing across fields. |
| precision-touchpad | Touchpad rate 42 → 106 Hz (capture analysis). Tap shift ≥ 5 px: 36 % → 7 % (`tapfilter`, 138 taps); 35 % (`glide`, 118 taps). Running since 2026-11-13. |
| desktop-touchpad | Owner: Steam exit → pad works; Steam restart → no double movement. 0 wake-ups / 30 s idle. |
| desktop-power-policy | Battery idle 7.86 → 7.11 W with unchanged burst latency. 22 logged suspend/resume cycles with the policy re-applied. |
| mic-enhance | Running as the default source; tuned by ear; no formal measurement. |

## D. Fresh hardware validation done for this release

- `./legiongo.sh list` and `check` on the reference device: all five tweaks correctly detected as `external`. The running InputPlumber build was identified by checksum as the `glide` build.
- `./legiongo.sh adopt` for all five tweaks on the reference device: 163 relevant system and user files compared before and after, **no file changed**. All services still active. `status` reports `installed (adopted)`.
- `build/build-patched.sh glide` and `tapfilter`: both rebuilt from the pristine v0.84.0 source and the published patches, **bit-identical** to the binaries tested on the device (sha256 `2fed277f…`, `9f3d5c1b…`).

## Still required (hardware)

- A **fresh install through `legiongo.sh`** of each tweak on a Legion Go without the manual setup (the reference device keeps its adopted setup, to avoid breaking it).
- steam-keyboard: Tab with the Russian layout; Hide after Tab navigation; rapid repeated Tab.
- precision-touchpad: Gaming Mode use; double-tap and tap-and-drag with the patched builds.
- desktop-touchpad: Steam crash, resume, Gaming → Desktop switch.
- desktop-power-policy: the AC (performance) path with a charger.
- Reboot and SteamOS update persistence for all tweaks.
