# Installation

## One command per tweak

Open **Konsole** in Desktop Mode and paste (replace `steam-keyboard` with the tweak you want):

```bash
d=~/.local/share/legiongo-steamos/v0.2.3
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install steam-keyboard
```

What happens:
1. The project is cloned once, at the fixed release tag `v0.2.3`, into `~/.local/share/legiongo-steamos/v0.2.3`. Git verifies the content by its commit hashes, and you can read every script there. Nothing is piped from the internet into a shell.
2. `legiongo.sh install <tweak>` checks the device, SteamOS version, InputPlumber, KDE, Steam and existing setups. It explains anything that needs `sudo` or another tweak, and asks first.
3. The tweak is installed, verified, and its rollback state is saved in `~/.local/state/legiongo-steamos/<tweak>/`.

To verify the checkout: `git -C ~/.local/share/legiongo-steamos/v0.2.3 log -1 --format=%H` must match the commit shown on the GitHub release page.

**Administrator rights:** `precision-touchpad`, `desktop-power-policy`, `decky-loader` and `decky-power-plugins` write system files and use `sudo`. SteamOS's `deck` user has no password until you set one with `passwd`.

## Results

Every install ends with exactly one of these:

| Result | Meaning |
|---|---|
| **INSTALLED & VERIFIED** | Installed, and the functional check passed (for example: the keyboard script is active in Steam, InputPlumber exposes the controller) |
| **INSTALLED — VERIFICATION PENDING** | Installed, but it cannot be tested right now (outside Desktop Mode, Steam not running). `status <tweak>` re-checks it later; it is never reported as verified until a check passes. |
| **FAILED** | An install step or the functional check failed. Everything this installation changed was rolled back, files you edited are kept, and the command exits with an error. |

`status` shows the live state (`working: yes`, `verification pending` or `NO`). `doctor` marks each tweak as working, verification pending or BROKEN. `update` repairs a tweak whose files are intact but whose functional check fails.

## Uninstall

The same line with `uninstall`. It restores what the tweak changed and keeps files you edited afterwards. Backups and logs remain in `~/.local/state/legiongo-steamos/.uninstalled/`.

## Update one tweak

Use the one-command line from the **new** release's README with `update <tweak>`:
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
