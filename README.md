# Legion Go SteamOS — Compatibility & Tweaks

**Make Valve's original SteamOS feel at home on Lenovo Legion Go.**

This is a collection of small, independent and reversible tweaks for the **original Lenovo Legion Go running Valve's own SteamOS**. It does not replace SteamOS, the Steam client, Steam Input, KDE Plasma or Gaming Mode. Each tweak fixes one practical problem and can be installed, checked and removed on its own.

Every tweak here was extracted from a working, daily-used Legion Go. It is not a theoretical fix: each guide states exactly what was measured or verified, and what was not.

> Community project. Not affiliated with, endorsed by or supported by Valve or Lenovo.

## Goals

- Preserve native SteamOS: no OS fork, no replacement launcher or keyboard, nothing patched under the read-only `/usr`.
- Fix real Legion Go compatibility issues: touchpad rate, touchpad without Steam, Desktop Mode keyboard.
- Keep overhead low: event-driven services only, no polling, no background updater.
- Install one tweak at a time, and back up and restore everything a tweak touches.
- Be honest about what was tested.

## Supported hardware and software

| | Supported |
|---|---|
| Device | Lenovo Legion Go, 1st generation (machine type 83E1, "Legion Go 8APU1") |
| OS | Valve SteamOS 3.9.5 (tested). Other versions are reported as *untested*, and install needs `--force`. |
| Desktop | KDE Plasma 6 Desktop Mode (Wayland), as shipped with SteamOS |

Legion Go S / Legion Go 2 and other handhelds are **not** supported. The installer refuses hardware-specific tweaks on them.

## Available tweaks

| Tweak | What it improves | Scope | sudo | Status |
|---|---|---|---|---|
| [`steam-keyboard`](tweaks/steam-keyboard/) | Desktop typing with Valve's own on-screen keyboard: placement, Hide, Ctrl/Alt, Tab/Shift+Tab, English/Russian, controller keys | Desktop | no | Partially Verified |
| [`precision-touchpad`](tweaks/precision-touchpad/) | Touchpad smoothness: about 106 Hz instead of about 42 Hz (upstream InputPlumber 0.84). Optional tap-to-click filter build. | System | yes | Partially Verified (patched builds: Experimental) |
| [`desktop-touchpad`](tweaks/desktop-touchpad/) | Touchpad keeps working in Desktop Mode when Steam is closed or crashed | Desktop | no | Partially Verified |
| [`desktop-power-policy`](tweaks/desktop-power-policy/) | Desktop Mode uses the firmware's balanced profile on battery (−0.75 W idle measured) and performance on AC; hands off in Gaming Mode | Desktop (system service) | yes | Experimental |
| [`mic-enhance`](tweaks/mic-enhance/) | Fuller, non-clipping internal microphone via a PipeWire filter-chain | User audio | no | Experimental |

**Status meanings**

| Status | Meaning |
|---|---|
| Stable | Verified on hardware, including a fresh install through this installer. No tweak has this status yet. |
| Partially Verified | Works on the reference device and was verified by its owner. The installer was tested only in a sandbox, and some scenarios are open (listed in each guide). |
| Experimental | Works on the reference device, but parts are unmeasured or a matter of taste. |
| Unsupported | Kept for reference only. |

Changes that were found on the reference device but are **not** published (for example a Wi-Fi regulatory-domain setting that turned out not to work) are listed with reasons in [docs/DEVELOPMENT_AUDIT.md](docs/DEVELOPMENT_AUDIT.md).

## Quick start

Open **Konsole** in Desktop Mode:

```bash
git clone https://github.com/daineku/legiongosteamos.git
cd legiongosteamos
./legiongo.sh list                      # all tweaks and their state on this device
./legiongo.sh info steam-keyboard       # what it does, requirements
./legiongo.sh check steam-keyboard      # requirements check, changes nothing
./legiongo.sh install steam-keyboard    # install just this one
./legiongo.sh status steam-keyboard     # verify
```

Tweaks marked *sudo* need administrator rights. On SteamOS, set a password for the `deck` user once with `passwd`. The installer then asks for it through `sudo` only when it writes system files. User-level tweaks never use sudo.

Installation does not pipe a remote script into a shell: you clone the repository, can read every script, and run it locally.

## Commands

| Command | What it does |
|---|---|
| `./legiongo.sh list` | All tweaks, their status and their state on this device |
| `./legiongo.sh info <tweak>` | Description, requirements, dependencies |
| `./legiongo.sh check <tweak>` | Requirements and detection only. Changes nothing. |
| `./legiongo.sh install <tweak>` | Installs one tweak. Asks before installing a dependency. Re-running it is safe. |
| `./legiongo.sh status [tweak]` | Installed version, file integrity, service state |
| `./legiongo.sh uninstall <tweak>` | Removes the tweak and restores what it changed |
| `./legiongo.sh adopt <tweak>` | Records an equivalent manual setup that is already present, without changing it |
| `--yes` / `--force` | Confirm prompts non-interactively / allow an untested SteamOS version |

Device states reported by `check`, `list` and `status`:
- `not-installed`
- `installed` (by this tool, or adopted)
- `partial` (recorded files missing or changed)
- `external` (an equivalent manual setup exists)
- `conflict`
- `unsupported`
- `untested` (SteamOS version)
- `not-needed` (SteamOS already contains the fix)

## Uninstall and rollback

`./legiongo.sh uninstall <tweak>` walks back exactly what the install recorded:
- It disables services and deletes the files the tweak created.
- It restores the original copy of any file it replaced, with its permissions.
- It removes only the configuration keys it added to shared KDE files.

Files you edited after installation are **kept**, with a warning, never silently deleted. Backups and logs stay under `~/.local/state/legiongo-steamos/`. Details: [docs/INSTALLATION.md](docs/INSTALLATION.md).

## SteamOS updates

- Everything is installed under `/home` and `/etc`. On SteamOS both survive system updates; nothing is written to the read-only `/usr`.
- After a SteamOS or Steam client update, run `./legiongo.sh status` and see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).
- `precision-touchpad` should be removed once SteamOS ships InputPlumber 0.79.2 or newer; `check` tells you.

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Compatibility and update notes](docs/COMPATIBILITY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Development audit](docs/DEVELOPMENT_AUDIT.md): what was found on the reference device, and what was and wasn't packaged
- [Test report](docs/TEST_REPORT.md)
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## License and disclaimer

GPL-3.0-or-later (see [LICENSE](LICENSE)). The InputPlumber patches are derived from [InputPlumber](https://github.com/ShadowBlip/InputPlumber) (GPL-3.0). No Valve or Lenovo binaries or assets are distributed: the keyboard tweak modifies your own installed Steam client at runtime, and `precision-touchpad` downloads the official InputPlumber release from GitHub and verifies its checksum.

These tweaks change input, audio and power settings. They are provided as is, without warranty. Read a tweak's guide before installing it. Lenovo, Legion, Valve, Steam and SteamOS are trademarks of their respective owners.
