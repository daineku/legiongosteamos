# Installation & management

## Select your device — copy-ready commands

- **[Lenovo Legion Go (1st gen): all 7 tweak installers](INSTALL_LEGION_GO.md)**
- **[Steam Deck LCD / OLED: 4 portable software installers](INSTALL_STEAM_DECK.md)** — compatible by capability but not physically verified on Steam Deck.

Each device guide has **one complete, release-pinned command per tweak** plus copy-ready uninstall commands. There is no need to replace a tweak name or edit the command. Click a tweak in the guide's table, then use GitHub's built-in **Copy** control on the Bash code block. Open **Konsole** in SteamOS Desktop Mode and paste.

The commands clone the exact reviewed `v0.2.5` release into `~/.local/share/legiongo-steamos/v0.2.5`, only when needed, and run the selected tweak's local installer. No remote shell code is piped directly into Bash. Users can inspect the checkout first.

Installations are independent; no global 'install everything' action is run. Each tweak checks compatibility, requests permission before installing a dependency, records its rollback state in `~/.local/state/legiongo-steamos/<tweak>/`, and asks for `sudo` only when required. The `deck` user may need to set an administrator password first via `passwd`.

Verify the checkout with `git -C ~/.local/share/legiongo-steamos/v0.2.5 log -1 --format=%H`, which should match the published release's commit. The device-specific pages also provide one-click `list` and `doctor` commands.

## Results

Every install ends with exactly one of these:

| Result | Meaning |
|---|---|
| **INSTALLED & VERIFIED** | Installed, and the functional check passed (for example: the keyboard script is active in Steam, InputPlumber exposes the controller) |
| **INSTALLED — VERIFICATION PENDING** | Installed, but it cannot be tested right now (outside Desktop Mode, Steam not running). `status <tweak>` re-checks it later; it is never reported as verified until a check passes. |
| **FAILED** | An install step or the functional check failed. Everything this installation changed was rolled back, files you edited are kept, and the command exits with an error. |

`status` shows the live state (`working: yes`, `verification pending` or `NO`). `doctor` marks each tweak as working, verification pending or BROKEN. `update` repairs a tweak whose files are intact but whose functional check fails.

## Uninstall

Both device guides provide a **separate, ready-to-copy `uninstall` command for each tweak**, tucked under its installation section. No command editing is needed. Uninstall restores what the tweak changed and keeps files you edited afterwards. Backups and logs remain in `~/.local/state/legiongo-steamos/.uninstalled/`.

## Update one tweak

For a new release, use its versioned guide; for advanced use, run `legiongo.sh update` with the installed tweak id. This is intentionally a separate maintenance operation, not part of the one-click install flow:
- Only that tweak is updated.
- A tweak that is already current reports "up to date".
- A damaged one (`partial`) is repaired.

An **adopted** manual setup cannot be updated in place: `uninstall`, then `install`.

## Options

Put options in front of `"$d/legiongo.sh"`, for example `LG_IP_VARIANT=tapfilter "$d/legiongo.sh" install precision-touchpad`.

| Option | Tweak | Effect |
|---|---|---|
| `--yes` | all | answer confirmations (dependencies, Steam debugger flag) |
| `--force` | all | allow an untested SteamOS version, or a tweak reported as upstream equivalent |
| `LG_KEYBOARD_LAYOUTS="de fr"` | steam-keyboard | add KDE layouts for your Steam keyboard languages |
| `LG_KEYBOARD_AUTOOPEN=1` | steam-keyboard | open the keyboard on text-field focus |
| `LG_IP_VARIANT=glide\|tapfilter\|release` | precision-touchpad | choose the InputPlumber build (default glide) |
| `LG_IP_BUILD=1` | precision-touchpad | build the patched variant locally with podman instead of downloading it |
| `LG_IP_BINARY=/path` | precision-touchpad | install your own InputPlumber 0.84.0 build (asks first) |

## Commands

| Command | |
|---|---|
| `list` | all tweaks, status, state on this device |
| `info <tweak>` | what it does, requirements |
| `check <tweak>` | read-only requirements and detection |
| `install <tweak>` | install (idempotent) |
| `update <tweak>` | update or repair one installed tweak |
| `status [tweak]` | installed version, file integrity, service state |
| `uninstall <tweak>` | remove and restore |
| `adopt <tweak>` | record an equivalent manual setup without changing it |
| `doctor` | privacy-safe system and compatibility report |

## Existing manual setups

If a fix is already present (set up by hand, or by Decky's own installer), `check` reports `external`, and `install` refuses to overwrite it. Run `adopt <tweak>` to record it as it is. After that, `status` and `uninstall` manage it.

## Failures

A failed step rolls back everything that tweak changed. If a dependency was installed in the same command, it is rolled back too. Leftovers show as `partial`; run `update` (repair) or `uninstall`.

## Developers

`git clone https://github.com/daineku/legiongosteamos.git && cd legiongosteamos && ./legiongo.sh list`. See [MAINTAINING.md](MAINTAINING.md).
