# Architecture

## Layout

```
legiongo.sh              command dispatcher (list, info, check, install, update, status, uninstall, adopt, doctor)
lib/common.sh            environment, manifest.json access, confirmations, check helpers
lib/logging.sh           output and per-tweak log
lib/detection.sh         device (DMI), SteamOS version, session, package versions
lib/backup.sh            state tracking, atomic writes, backups, rollback, shared-resource reference counting
lib/doctor.sh            privacy-safe system/compatibility report
tweaks/<id>/
    manifest.json        id, name, version, status, scope, requires_root, depends, tested_steamos, summary, restart
    README.md            user guide (fixed set of sections)
    check.sh             requirements + detection; prints RESULT=<state> <detail>; changes nothing
    install.sh           applies the tweak through lib/backup.sh helpers
    uninstall.sh         lg_rollback + tweak-specific restore; also used for automatic rollback
    adopt.sh             (optional) records an equivalent manual setup without changing it
    status.sh            (optional) extra status lines
    files/               files installed (verbatim or templated *.in)
tests/run-tests.sh       static checks + sandboxed install tests (+ tests/test_lgk_helper.py)
compat/upstream.json     reviewed upstream versions (read by the upstream-watch workflow)
.github/workflows/       ci.yml (static + sandbox tests, no hardware), upstream-watch.yml (weekly review issues)
experimental/            research that is not an installable tweak (wifi-reliability)
```

The installer is plain Bash plus tools that ship with SteamOS (`jq`, `sha256sum`, `kwriteconfig6`, `systemctl`). It runs only when invoked. The tweaks' runtime components are the original, verified implementations. Three of them are Python (stdlib + PyGObject, both part of SteamOS), because rewriting working, measured code would mean publishing something different from what was tested.

## Install flow

1. `check.sh` determines the state:
   - `not-installed`
   - `installed` (state recorded and every recorded file intact)
   - `partial`
   - `external` (a manual equivalent exists)
   - `conflict`
   - `unsupported`
   - `untested` (SteamOS version not listed in `tested_steamos`)
   - `upstream-equivalent` (stock SteamOS already provides the function; a feature probe, not a version comparison)
   - `incompatible`
2. `legiongo.sh install` refuses `external`, `conflict` and `incompatible`. It refuses `untested` and `upstream-equivalent` without `--force`.
3. Dependencies (`depends`) are explained and installed only after an explicit yes (or `--yes`). A dependency counts as satisfied if it is installed, adopted, present externally, or provided by stock SteamOS (`check.sh` runs with `LG_AS_DEPENDENCY=1`). Dependencies installed in a command that later fails are rolled back with it (transaction).
4. Root tweaks validate `sudo` first. Root writes go through `sudo install` / `sudo mv` only.
5. `install.sh` runs with `set -e`. If it fails, `uninstall.sh --rollback` undoes everything recorded so far.
6. `check.sh` runs again to verify. The restart hint from the manifest is printed.

## State and backups

`~/.local/state/legiongo-steamos/<id>/`:
- `state`: `mode` (installed/adopted), `version`, `installed_at`, `repo_commit`, and tweak values (e.g. the previous default audio source)
- `manifest.tsv`: every change in order: `created`, `replaced` (with the backup path and original mode), `adopted`, `dir`, `unit`, with the owner (user/root) and SHA-256
- `backups/`: original copies of replaced files; also user-modified versions found during an upgrade
- `log`: timestamped actions

Rules:
- **Atomic writes**: temp file in the target directory, then rename.
- **Idempotent**: a file already recorded with identical content is skipped; units and KWin rules are not duplicated.
- **Never silently overwrite**: a recorded file changed by the user is saved to `backups/` before an upgrade rewrites it.
- **Uninstall** (newest first):
  - Disable recorded units.
  - Delete a created or adopted file only if its SHA-256 still matches.
  - Restore a replaced file only if it is unchanged since install.
  - Remove created directories only if they are empty.

  Files changed by the user are kept, with a warning.
- **Shared configuration** (`kwinrulesrc`, `kxkbrc`, `kcminputrc`) is edited key by key with `kwriteconfig6`. Only the keys the tweak added are removed. Previous values are restored only if the current value is still the tweak's.
- After uninstall, the state directory moves to `.uninstalled/<id>.<timestamp>`, keeping backups and logs.

## Adoption

On a device that already has a manual setup (like the reference device), `adopt` records the existing files (SHA-256) and units as `adopted` without touching them. `status` and `uninstall` then work as for a normal install. To migrate to the packaged layout: uninstall the adopted setup, then install.

## Persistence

| Location | Survives SteamOS update | Used by |
|---|---|---|
| `~/.config`, `~/.local` | yes | user tweaks |
| `/home/legiongo-steamos` | yes | precision-touchpad binary and data |
| `/etc` | yes (SteamOS keeps `/etc` changes across updates) | system units, drop-ins, power policy |
| `/usr` | no, read-only | never written |

## Gaming Mode isolation

- User services are `PartOf=plasma-workspace.target`. They start and stop with the Plasma session only.
- `desktop-power-policy` runs as a system service, but writes nothing while the active seat0 session is not the Plasma desktop.
- `precision-touchpad` changes InputPlumber for both modes (documented).

## Extending

A new tweak is a directory with the files above. The test suite checks that every tweak has the required files, executable scripts, README sections and a valid manifest, and that no tweak references another tweak's files.

## Update

`update <tweak>` compares the installed version (state) with `manifest.json`:
- equal and intact → "up to date";
- different, or `partial` → `install` again (idempotent; only changed files are rewritten, and user edits are backed up first).

Other tweaks are never touched. Adopted setups must be uninstalled and installed instead.

## Shared resources

A file needed by several tweaks (Steam's debugger flag: `steam-keyboard`, `decky-loader`) is acquired with `lg_shared_acquire` and released with `lg_shared_release`. Holders are listed in `~/.local/state/legiongo-steamos/.shared/<name>`. The file is deleted only when no tweak holds it, it did not exist before, and no unmanaged user of it (Decky Loader) is present.

## Dependency safety

`uninstall` refuses to remove a tweak that another installed tweak depends on (unless `--force`).

## One-command bootstrap

The README's line clones a **pinned release tag** into `~/.local/share/legiongo-steamos/<tag>` (once) and runs `legiongo.sh <command> <tweak>` from it. Installed files are copies, so the checkout can be deleted. State lives in `~/.local/state`, so any later release's checkout can update or uninstall.
