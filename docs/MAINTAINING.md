# Maintaining the project

This repository is maintained over time. When SteamOS, Steam, InputPlumber or a plugin changes, the tweaks are re-evaluated **by behaviour**, not by version number.

## 1. Detecting changes

| Signal | Where |
|---|---|
| New upstream release (InputPlumber, Decky Loader, SimpleDeckyTDP, LegionGoRemapper) | The weekly GitHub Actions workflow `upstream-watch` compares `compat/upstream.json` with the latest releases and opens a **"Compatibility review"** issue. It never changes code or marks anything compatible. |
| SteamOS update on your device | `./legiongo.sh doctor`: SteamOS/kernel/InputPlumber/Steam versions, per-tweak state, `untested` warnings |
| Steam client changed keyboard internals | `doctor` → "keyboard hooks"; `journalctl --user -u legiongo-steam-keyboard` lists `unsupported:` hooks |
| SteamOS now provides a tweak's function itself | `check` reports `upstream-equivalent` (feature probe, e.g. a native touchpad interface in the stock InputPlumber profile) |
| Broken installation | `status` → `partial`, `doctor` → recommended actions |

## 2. Reviewing a new upstream version

For each review issue:

1. **What changed?** Read the upstream changelog and the diff of the parts we touch:
   - InputPlumber: `src/drivers/legion_go/`, `rootfs/usr/share/inputplumber/devices/50-legion_go.yaml`;
   - plugins: the patched files.
2. **What does upstream now provide natively?** Install it on a test setup without our patch, and measure:
   - touchpad: `tools`-style capture of the report rate and tap displacement, the same routine as in `docs/technical/precision-touchpad.md`;
   - plugins: the first-start settings, and whether the touchpad/LED defects are still present.
3. **Compare native vs our version.** Keep our change where it is still better. Remove only operations that became redundant.
4. **Regressions?** Check click, double-tap, drag, resume and Gaming Mode.
5. **Adapt:** rebase the patch (see 3), update the pins, and add the version to `tested_steamos` / `compat/upstream.json` **only after testing**.
6. Record the result in `docs/COMPATIBILITY.md`, then release (see 5).

If upstream becomes equal or better, the tweak stays in the repository. Its `check.sh` must report `upstream-equivalent` on such systems, and the README's compatibility table says so.

## 3. Rebuilding patched InputPlumber

```bash
# 1. get the new source, apply our patch, fix rejects
git clone --branch vX.Y.Z https://github.com/ShadowBlip/InputPlumber /tmp/ip && cd /tmp/ip
git apply --3way ~/legiongosteamos/tweaks/precision-touchpad/patches/legion-touchpad-tapfilter.patch
# 2. regenerate the patch against the tag
git diff vX.Y.Z -- src/drivers/legion_go > ~/legiongosteamos/tweaks/precision-touchpad/patches/legion-touchpad-tapfilter.patch
# 3. update IP_VERSION / URLs / checksums in tweaks/precision-touchpad/common-ip.sh and build/build-patched.sh
tweaks/precision-touchpad/build/build-patched.sh tapfilter
tweaks/precision-touchpad/build/build-patched.sh glide
```

Test the build on hardware (`LG_IP_BINARY=build/out/... ./legiongo.sh install precision-touchpad`). Measure, then publish the binaries as assets of a new release `inputplumber-X.Y.Z-patches-N` and pin their SHA-256 in `common-ip.sh`. Never publish a binary that was not run on hardware, and never re-upload a different binary under an existing pinned name.

## 4. Updating a tweak

1. Change the files under `tweaks/<id>/`. Bump `version` in its `manifest.json`; users then see "OUTDATED" in `doctor`, and `update <id>` re-applies it.
2. Keep `install.sh` idempotent: only use the `lg_put_file` / `lg_put_content` / `lg_unit_enable` / `lg_shared_*` helpers.
3. Add or adjust tests in `tests/run-tests.sh`, then run:
   ```bash
   LG_SHELLCHECK_IMAGE=docker.io/koalaman/shellcheck:stable tests/run-tests.sh
   ```
4. Live-verify on the reference device, then update the status and `docs/TEST_REPORT.md`.

## 5. Publishing a release

1. `tests/run-tests.sh` passes. CI is green: static checks and sandboxed installer tests only, **not hardware**.
2. Update `CHANGELOG.md` and the release tag in all one-command lines: `grep -rl 'legiongo-steamos/v' README.md tweaks docs`, then replace the version.
3. Commit, then `git tag -a vX.Y.Z -m "..."` and `git push origin main vX.Y.Z`.
4. `gh release create vX.Y.Z --notes-file <notes>`.

## 6. Rolling back a bad release

- **Users:** run the one-command line of the previous release with `update <id>`. Installation is idempotent, so it rewrites the tweak's files to the older version.
- **Maintainers:** never move or delete a published tag (users' one-command lines pin it). Publish a new patch release that reverts the change, and mark the bad release as such in its GitHub release notes.

## 7. Privacy-safe bug reports

Ask for:
- `./legiongo.sh doctor`: no user name, home path, network name, address or serial number;
- `./legiongo.sh status <tweak>`;
- the relevant journal lines, e.g. `journalctl --user -u legiongo-steam-keyboard -n 50`. Ask the reporter to check them for personal data first.

Never ask for tokens, Steam account data, Wi-Fi names, or full system logs.
