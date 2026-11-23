# Installation

## 1. Get the repository

In Desktop Mode, open **Konsole**:

```bash
git clone https://github.com/daineku/legiongosteamos.git
cd legiongosteamos
```

You can read every script before running anything. Nothing is downloaded and executed blindly. The only download happens inside `precision-touchpad`: an official GitHub release archive, verified by SHA-256.

## 2. See what is available

```bash
./legiongo.sh list
./legiongo.sh info <tweak>
./legiongo.sh check <tweak>      # read-only
```

## 3. Install one tweak

```bash
./legiongo.sh install <tweak>
```

- **Dependencies.** If a tweak depends on another (only `desktop-touchpad` → `precision-touchpad`), the installer explains why and asks. Nothing is installed without your yes.
- **Administrator rights.** `precision-touchpad` and `desktop-power-policy` write system files and use `sudo`. On SteamOS the `deck` user has no password by default; set one once with `passwd`. The other tweaks never use sudo.
- **Re-running** `install` is safe: unchanged files are skipped, and nothing is duplicated.
- **Untested SteamOS version:** the installer stops. Add `--force` only if you accept the risk, and then check the tweak's verification steps.
- **Non-interactive use:** `--yes` answers confirmations (dependency installation, creating Steam's debugger flag).

## 4. Verify

```bash
./legiongo.sh status <tweak>
```

Each tweak's README has a *Verification* section with a hands-on test.

## 5. Uninstall

```bash
./legiongo.sh uninstall <tweak>
```

This restores what the tweak changed and keeps files you edited afterwards. Backups and logs remain in `~/.local/state/legiongo-steamos/.uninstalled/`.

## Already have a manual setup?

If you set up one of these fixes by hand earlier (for example from the original development notes), `check` reports `external`, and `install` refuses to overwrite it. You have two options:

```bash
./legiongo.sh adopt <tweak>       # record it as-is; status/uninstall then manage it
```

or remove it by hand, then install the packaged version.

## Failed installation

If an install step fails, the installer rolls back everything that tweak changed so far. If something is still left over, `./legiongo.sh status <tweak>` shows `partial`; running `uninstall` (or `install` again) resolves it.

## After SteamOS updates

All files live in `/home` and `/etc`, which SteamOS keeps across updates. Run `./legiongo.sh status` after an update. See [COMPATIBILITY.md](COMPATIBILITY.md).

## Updating this repository

```bash
git pull
./legiongo.sh status
./legiongo.sh install <tweak>     # re-applies only what changed
```
