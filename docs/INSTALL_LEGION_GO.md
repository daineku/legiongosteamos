# Install on Lenovo Legion Go (1st gen)

**Reference Verified · SteamOS 3.9.5 reference system · stable package v0.2.3**

Open **Konsole** in SteamOS Desktop Mode. Select the improvement below, click its link, press GitHub's **Copy** icon on the `bash` command block and paste into Konsole. **No placeholders, editing, name replacement or manual version changes.** Each command installs just one tweak (required dependencies are explained before installation).

## Choose a tweak

| Open install command | What it improves |
|---|---|
| [**Native Steam keyboard**](#steam-keyboard) | Improve Valve's own keyboard: top/bottom docking, Hide, Tab navigation, English/Russian input, modifiers and two-joystick typing. |
| [**Precision touchpad**](#precision-touchpad) | Increase the first-generation Legion Go touchpad's measured reporting rate from about 42 to 106 updates/second. |
| [**Desktop touchpad handover**](#desktop-touchpad) | Keep the touchpad usable in KDE Desktop Mode when the Steam client closes. |
| [**Desktop power policy / CPU boost**](#desktop-power-policy) | Keep desktop CPU boost available and apply capability-aware EPP/power behavior without changing Gaming Mode's ownership of power controls. |
| [**Enhanced microphone**](#mic-enhance) | Add the reference Legion Go's PipeWire mic processing for clearer, less clipped voice input. |
| [**Decky Loader**](#decky-loader) | Install the checksum-pinned Decky plugin loader used for Gaming Mode extensions. |
| [**Gaming Mode power plugins**](#decky-power-plugins) | Add SimpleDeckyTDP and patched LegionGoRemapper with conservative initial settings. |

## Ready-to-copy installation commands

### steam-keyboard

**Native Steam keyboard.** Improve Valve's own keyboard: top/bottom docking, Hide, Tab navigation, English/Russian input, modifiers and two-joystick typing.

Portable keyboard enhancements; on Legion Go the left and right sticks control two key cursors. Steam may need to restart once to enable its local debugger; the installer explains the security trade-off.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install steam-keyboard
```

<details>
<summary>Uninstall steam-keyboard — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall steam-keyboard
```

</details>

### precision-touchpad

**Precision touchpad.** Increase the first-generation Legion Go touchpad's measured reporting rate from about 42 to 106 updates/second.

**System-wide / sudo.** This temporarily restarts InputPlumber and affects Desktop and Gaming Mode. The default `glide` variant prioritizes smooth movement; the alternative `tapfilter` reduces measured tap-induced cursor shifts but has a small low-speed latency trade-off.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install precision-touchpad
```

<details>
<summary>Uninstall precision-touchpad — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall precision-touchpad
```

</details>

**Optional: favor tap precision instead of the default glide feel** (`tapfilter` variant; measured 36% → 7% of taps moving ≥5 px on the reference device):

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && LG_IP_VARIANT=tapfilter "$d/legiongo.sh" install precision-touchpad
```

Choose one variant, not both. The reference device uses `glide` by default. Read [trade-offs](../tweaks/precision-touchpad/README.md) before switching.

### desktop-touchpad

**Desktop touchpad handover.** Keep the touchpad usable in KDE Desktop Mode when the Steam client closes.

Depends on a compatible InputPlumber touchpad target. If that feature is missing, the installer asks permission before installing the required dependency.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install desktop-touchpad
```

<details>
<summary>Uninstall desktop-touchpad — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall desktop-touchpad
```

</details>

### desktop-power-policy

**Desktop power policy / CPU boost.** Keep desktop CPU boost available and apply capability-aware EPP/power behavior without changing Gaming Mode's ownership of power controls.

**sudo.** Alters power policy in Desktop Mode; outcomes depend on the available firmware/CPU interfaces. Battery results reported in this project were measured only on the reference Legion Go.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install desktop-power-policy
```

<details>
<summary>Uninstall desktop-power-policy — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall desktop-power-policy
```

</details>

### mic-enhance

**Enhanced microphone.** Add the reference Legion Go's PipeWire mic processing for clearer, less clipped voice input.

Tuned for the Legion Go internal microphone. Uses the existing PipeWire filter-chain service; confirm your audio input afterward.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install mic-enhance
```

<details>
<summary>Uninstall mic-enhance — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall mic-enhance
```

</details>

### decky-loader

**Decky Loader.** Install the checksum-pinned Decky plugin loader used for Gaming Mode extensions.

**sudo.** If Decky is already installed manually, the project refuses to overwrite it; read the existing-setup guidance below.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install decky-loader
```

<details>
<summary>Uninstall decky-loader — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall decky-loader
```

</details>

### decky-power-plugins

**Gaming Mode power plugins.** Add SimpleDeckyTDP and patched LegionGoRemapper with conservative initial settings.

**sudo / requires Decky Loader.** Some remapping, fan, RGB and charge-limit controls have not been hardware-verified. The installer asks before adding a missing dependency.

**Install — copy this entire command:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install decky-power-plugins
```

<details>
<summary>Uninstall decky-power-plugins — ready-to-copy command</summary>

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall decky-power-plugins
```

</details>

## Before installing

- This project enhances **official Valve SteamOS**; it does not replace the operating system, Steam Input, or the Steam keyboard.
- Commands clone the audited v0.2.3 release into `~/.local/share/legiongo-steamos/v0.2.3` and run the selected local installer. GitHub displays a **Copy** control on each code block.
- Installer results are `INSTALLED & VERIFIED`, `INSTALLED — VERIFICATION PENDING`, or `FAILED` with rollback. A software check is not proof of compatibility on other physical devices.
- Tweaks that modify system files request `sudo`. Set a SteamOS user password with `passwd` first if needed; do not include your password in a command.
- Existing third-party/manual installations are detected and not silently overwritten. See [adoption and updates](INSTALLATION.md).

## Device diagnostics — ready to copy

**List available tweaks and their compatibility on this device:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" list
```

**Health report:**

```bash
d=~/.local/share/legiongo-steamos/v0.2.3; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" doctor
```

**Documentation:** [Installation & management](INSTALLATION.md) · [Compatibility](COMPATIBILITY.md) · [Performance](PERFORMANCE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [GitHub repository](https://github.com/daineku/legiongosteamos)
