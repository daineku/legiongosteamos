# Install on Steam Deck (LCD / OLED)

**Official SteamOS / KDE Desktop Mode · portable software enhancements only · package v0.2.5**

**These are portable by capability, not Cross-device Verified.** This project has not physically tested them on a Steam Deck. Installation checks available interfaces but cannot establish real-world quality automatically.

The project's Legion Go-specific touchpad, touchpad handover and power-plugin modules **are not for Steam Deck** and are deliberately omitted. Steam's original dual-trackpad keyboard input is preserved.

Open **Konsole** in Desktop Mode. For the feature you want, jump to its section below, press GitHub's **Copy** icon on the `bash` command block, then paste the complete command into Konsole. **No placeholders, editing or name replacement.** Each command installs only that tweak.

## Choose a tweak

| Open install command | What it improves |
|---|---|
| [**Native Steam keyboard**](#steam-keyboard) | Desktop typing, language synchronization, Tab/Shift+Tab, shortcuts and better placement while preserving Valve's keyboard. |
| [**Decky Loader**](#decky-loader) | Install a fixed, checksum-verified Decky Loader version if it is not already installed. |
| [**Desktop power policy / CPU boost**](#desktop-power-policy) | Use available EPP/CPU boost interfaces for desktop performance policy without Lenovo-specific firmware assumptions. |
| [**Enhanced microphone**](#mic-enhance) | Use the reference-device PipeWire microphone processing preset where the required interfaces exist. |
| [**Smart auto brightness**](#smart-auto-brightness) | Experimental: adaptive brightness limited to ±10 % of your setting, ignoring hand shadows over the sensor. |

## Ready-to-copy installation commands

### steam-keyboard

**Native Steam keyboard.** Desktop typing, language synchronization, Tab/Shift+Tab, shortcuts and better placement while preserving Valve's keyboard.

**Compatible by capability, not physically tested on Steam Deck by this project.** The Deck's native two-trackpad typing remains untouched. Requires compatible Steam/KDE Desktop Mode features; installation checks prerequisites.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install steam-keyboard
```

<details>
<summary>Uninstall steam-keyboard — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall steam-keyboard
```

</details>

### decky-loader

**Decky Loader.** Install a fixed, checksum-verified Decky Loader version if it is not already installed.

**Compatible by capability, untested here.** Many Steam Deck owners already have Decky; the installer will refuse to overwrite an unmanaged installation. Skip this if your current Decky already works.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install decky-loader
```

<details>
<summary>Uninstall decky-loader — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall decky-loader
```

</details>

### desktop-power-policy

**Desktop power policy / CPU boost.** Use available EPP/CPU boost interfaces for desktop performance policy without Lenovo-specific firmware assumptions.

**Optional, advanced; compatible by capability, untested on Steam Deck.** This changes CPU power behavior and is not a proven Steam Deck battery-life upgrade. Read the [power policy guide](../tweaks/desktop-power-policy/README.md) before installing.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install desktop-power-policy
```

<details>
<summary>Uninstall desktop-power-policy — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall desktop-power-policy
```

</details>

### mic-enhance

**Enhanced microphone.** Use the reference-device PipeWire microphone processing preset where the required interfaces exist.

**Optional, untested on Steam Deck.** This preset was tuned for the Legion Go microphone; it may not improve Steam Deck audio. Use only if you understand and want to evaluate the effect.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install mic-enhance
```

<details>
<summary>Uninstall mic-enhance — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall mic-enhance
```

</details>

### smart-auto-brightness

**Smart auto brightness (Experimental).** Adaptive brightness that stays within ±10 % of the level you set and ignores hand shadows over the light sensor.

Compatible by capability, untested on Steam Deck: needs a light sensor and Plasma 6's automatic-brightness support; `check` tells you.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install smart-auto-brightness
```

<details>
<summary>Uninstall smart-auto-brightness — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall smart-auto-brightness
```

</details>

## Before installing

- This project enhances **official Valve SteamOS**; it does not replace the operating system, Steam Input, or the Steam keyboard.
- Commands clone the audited v0.2.5 release into `~/.local/share/legiongo-steamos/v0.2.5` and run the selected local installer. GitHub displays a **Copy** control on each code block.
- Installer results are `INSTALLED & VERIFIED`, `INSTALLED — VERIFICATION PENDING`, or `FAILED` with rollback. A software check is not proof of compatibility on other physical devices.
- Tweaks that modify system files request `sudo`. Set a SteamOS user password with `passwd` first if needed; do not include your password in a command.
- Existing third-party/manual installations are detected and not silently overwritten. See [adoption and updates](INSTALLATION.md).

## Device diagnostics — ready to copy

**List available tweaks and their compatibility on this device:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" list
```

**Health report:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.5; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" doctor
```

**Documentation:** [Installation & management](INSTALLATION.md) · [Compatibility](COMPATIBILITY.md) · [Performance](PERFORMANCE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [GitHub repository](https://github.com/daineku/legiongosteamos)
