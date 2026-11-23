# Legion Go SteamOS — Compatibility & Tweaks

**Make Valve's original SteamOS feel at home on Lenovo Legion Go.**

A maintained collection of small, independent tweaks that make the **original Valve SteamOS** work better on the Lenovo Legion Go. It does not replace SteamOS, Steam, the Steam keyboard or Gaming Mode. Every tweak:
- fixes one real problem;
- installs with **one command**;
- can be checked and removed again;
- reports honestly what was tested.

> Community project. Not affiliated with Valve or Lenovo.

## Supported devices

| Device | Status |
|---|---|
| Lenovo Legion Go (1st gen, type 83E1) on SteamOS 3.9.5 | Reference device: everything here runs on it daily |
| Other SteamOS versions | Reported as *untested*; installing needs `--force` |
| Legion Go S, Legion Go 2, other handhelds | Not supported: hardware-specific tweaks refuse to install |

## Tweaks

| Tweak | What gets better | Mode | Status |
|---|---|---|---|
| [**steam-keyboard**](tweaks/steam-keyboard/) | The original Steam keyboard for everyday desktop typing: proper placement, Hide, Ctrl/Alt, Tab between form fields, multilingual input | Desktop | Reference Verified |
| [**precision-touchpad**](tweaks/precision-touchpad/) | Smoother cursor (≈106 instead of ≈42 updates/s) and optional precise tap-to-click | All | Reference Verified |
| [**desktop-touchpad**](tweaks/desktop-touchpad/) | Touchpad keeps working when Steam is closed | Desktop | Reference Verified |
| [**decky-loader**](tweaks/decky-loader/) | Decky plugin loader, pinned and verified | Gaming | Reference Verified |
| [**decky-power-plugins**](tweaks/decky-power-plugins/) | Per-game TDP, fan curves, RGB and remapping, with safe defaults and safety fixes | Gaming | Experimental |
| [**desktop-power-policy**](tweaks/desktop-power-policy/) | Desktop uses less power on battery (−0.75 W measured), full speed on AC | Desktop | Experimental |
| [**mic-enhance**](tweaks/mic-enhance/) | Fuller internal microphone that does not clip | All | Experimental |

**Reference Verified:** working on the reference Legion Go, and the installer passed isolated install / reinstall / rollback tests.
**Experimental:** works on the reference device, but parts are unmeasured or a matter of taste.
On your device, `check` may also report **upstream equivalent** (SteamOS already does this; the tweak is skipped) or **incompatible** (not safe here; nothing is changed).

No tweak has been tested on a second physical Legion Go yet. They are written to detect your device and settings instead of assuming the reference device's.

## Install a tweak — one command

Open **Konsole** in Desktop Mode and paste the line for the tweak you want. This one installs the keyboard tweak:

```bash
d=~/.local/share/legiongo-steamos/v0.2.0; { [ -d "$d" ] || git clone -q --depth 1 -b v0.2.0 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install steam-keyboard
```

Replace `steam-keyboard` at the end with any tweak id from the table. Each tweak's page has its own ready-to-copy line.

What the command does:
1. Downloads this project at the fixed release `v0.2.0` into `~/.local/share/legiongo-steamos/` (a normal folder you can inspect).
2. Checks your device.
3. Explains anything that needs your password or another tweak, and asks first.
4. Installs and verifies the tweak.

Running it again is safe.

Tweaks that change system files ask for your `sudo` password. SteamOS has no password by default: set one once with `passwd`.

## Uninstall — one command

Same line, with `uninstall`:

```bash
d=~/.local/share/legiongo-steamos/v0.2.0; { [ -d "$d" ] || git clone -q --depth 1 -b v0.2.0 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall steam-keyboard
```

This restores what the tweak changed. Settings you changed yourself are kept.

## Update — one command

When a new release is out, its README shows the same line with the new version. Use `update` with the tweak you want:

```bash
d=~/.local/share/legiongo-steamos/v0.2.0; { [ -d "$d" ] || git clone -q --depth 1 -b v0.2.0 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" update steam-keyboard
```

Only that tweak is updated. There is no background updater.

## Is my device OK?

```bash
~/.local/share/legiongo-steamos/v0.2.0/legiongo.sh doctor
```

This shows your device, SteamOS and driver versions, which tweaks are installed, and whether anything needs attention. It contains no personal data, so it is safe to paste into a bug report.

Other commands: `list`, `info <tweak>`, `check <tweak>`, `status [tweak]`, `adopt <tweak>`. See [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Good to know

- Nothing is written to SteamOS's read-only system area. Everything lives in your home folder or `/etc`, which survive SteamOS updates.
- After a SteamOS or Steam update, run `doctor`. If SteamOS starts doing something better itself, the affected tweak reports *upstream equivalent* instead of installing.
- Third-party software we integrate (InputPlumber, Decky Loader, SimpleDeckyTDP, LegionGoRemapper) is installed from official releases, checked by SHA-256, with our fixes as visible patches. See [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md).
- Problems? See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), or open an issue with the `doctor` output.

## More

[Installation details](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Third-party components](docs/THIRD_PARTY.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Maintaining](docs/MAINTAINING.md) · [Architecture](docs/ARCHITECTURE.md) · [Audit of the reference device](docs/DEVELOPMENT_AUDIT.md) · [Test report](docs/TEST_REPORT.md) · [Wi-Fi research](experimental/wifi-reliability/) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## License

GPL-3.0-or-later. The InputPlumber patches are derived from InputPlumber (GPL-3.0), and the LegionGoRemapper patch from LegionGoRemapper (BSD-3-Clause). No Valve or Lenovo files are distributed. Lenovo, Legion, Valve, Steam and SteamOS are trademarks of their owners. Provided as is, without warranty.
