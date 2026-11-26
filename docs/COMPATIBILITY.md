# Compatibility

## Verification levels

| Level | Meaning |
|---|---|
| **Reference Verified** | The exact implementation (or one shown to behave identically) works on the reference Lenovo Legion Go, and its installer passed isolated install / reinstall / failure / rollback tests |
| **Cross-device Verified** | The same feature was independently verified on another supported SteamOS device. None yet. |
| **Compatible by capability, untested** | The device has every interface the tweak needs, and `check` allows it, but nobody has tested it there |
| **Experimental** | A new implementation, variant or hardware-specific behaviour that has not been verified adequately |
| **Unsupported / not applicable** | A required interface or hardware is missing, or the tweak targets different hardware. `check` explains which. |

Device-level states printed by `check`:
- `upstream-equivalent`: stock SteamOS already does it;
- `incompatible`: a requirement is missing; nothing is changed;
- `untested`: SteamOS version outside the tested list for hardware tweaks; needs `--force`.

`--force` never overrides missing hardware or security requirements.

## Reference device

| Component | Version |
|---|---|
| Device | Lenovo Legion Go 83E1 ("Legion Go 8APU1"), BIOS N3CN40WW, AMD Ryzen Z1 Extreme |
| SteamOS | 3.9.5 (build 20261023.100), kernel 7.2.7-valve2, Plasma 6.7.3 Wayland, steamos-manager 26.4.1 |
| Steam client | build 1794536281 |
| InputPlumber | stock 0.78.0; tweak 0.84.0 glide build |
| Decky Loader | v3.3.1 · SimpleDeckyTDP v1.0.7 · LegionGoRemapper v0.3.0 (patched) |

## Device matrix

| Tweak | Layer / detection | Legion Go (1st gen) | Steam Deck LCD / OLED | Other handhelds on official SteamOS |
|---|---|---|---|---|
| steam-keyboard | portable: Steam + KDE + debugger; input profile detection | Reference Verified | compatible by capability, untested (dual-trackpad typing stays Steam's own) | compatible by capability, untested (dual-joystick bridge only with an InputPlumber virtual Deck controller) |
| mic-enhance | capability: one internal analog mic node, filter-chain, CAPS | Reference Verified | compatible by capability, untested (EQ tuned for the Legion Go mic) | same |
| desktop-power-policy | capability: EPP (amd-pstate / intel_pstate), CPU boost (per-policy or global cpufreq `boost`, Intel `intel_pstate/no_turbo`) and/or Lenovo firmware profiles | Reference Verified | compatible by capability, untested (no Lenovo profiles; EPP/boost only if present) | same |
| smart-auto-brightness | capability: light sensor (iio-sensor-proxy), Plasma brightness API, KWin automatic brightness | Experimental | compatible by capability, untested | same |
| decky-loader | portable | Reference Verified | compatible, untested by us (Decky's own primary platform) | compatible, untested |
| precision-touchpad | Legion Go DMI + InputPlumber features | Reference Verified | not applicable | not applicable |
| desktop-touchpad | Legion Go DMI | Reference Verified | not applicable (the Deck's trackpads are not managed this way) | not applicable |
| decky-power-plugins | Legion Go DMI | Reference Verified (setup, SimpleDeckyTDP); LegionGoRemapper features Experimental | not applicable | not applicable |

The project does not claim which handhelds Valve supports. "Official SteamOS" means devices for which Valve publishes SteamOS.

## Version policy

- **Portable tweaks** (`version_policy: feature`) are not blocked on other SteamOS versions. Their checks probe the actual interfaces, and the keyboard script disables individual hooks that a Steam update changed.
- **Hardware tweaks** (`version_policy: tested`) need `--force` on untested SteamOS versions, because they replace or drive system components.

## Multilingual Input Support (steam-keyboard)

| Steam keyboard layout | Handling | Status |
|---|---|---|
| English (qwerty), Russian | KDE layout synced; physical long-press symbols; restore on Hide | Reference Verified (v41, 2026-11-23) |
| German, French, Spanish, Italian, Portuguese, Polish, Czech, Danish, Finnish, Norwegian, Swedish, Hungarian, Romanian, Greek, Ukrainian, Bulgarian (+ phonetic), Turkish Q/F, US-International, Dvorak, Colemak | KDE layout synced when configured in KDE; Steam's long-press popup | same code path as EN/RU; not tested by native speakers |
| Chinese (all), Japanese (all), Korean, Vietnamese | Steam's IBus input method / native path, untouched | Steam native behaviour |
| Right-to-left scripts | not offered by Steam's keyboard | — |

## What can break after updates

| Tweak | Depends on | Failure mode |
|---|---|---|
| steam-keyboard | Steam client UI internals: keyboard component methods, `g_PopupManager`, `VirtualKeyboardManager.HandleVirtualKeyDown`, the webpack module with `GetKeyboardLayoutSettings`, keyboard DOM attributes | Each hook is guarded and reported as `unsupported` (`doctor`); the stock keyboard keeps working |
| precision-touchpad | `inputplumber.service`; the Legion Go driver files the patches touch | The launcher falls back to stock if our binary fails. A newer stock version blocks installation until the patches are rebuilt. |
| desktop-touchpad | InputPlumber D-Bus `SetTargetDevices`, the `touchpad` target, process name `steam` | Logs `FAILED` and leaves the targets as SteamOS set them |
| decky-loader / plugins | Steam client injection points | Decky or plugins stop loading until upstream fixes them; Steam itself is unaffected |
| desktop-power-policy | `lenovo-wmi-gamezone`, EPP sysfs, logind/UPower | Logs the missing interface and changes nothing |
| mic-enhance | PipeWire filter-chain, CAPS, ALSA node naming | Re-run install to detect the new node; the raw microphone keeps working |

## Interaction with other software

- Decky Loader and `steam-keyboard` share Steam's debugger flag (reference counted).
- `desktop-power-policy` stays out of Gaming Mode. In Desktop Mode it unloads SimpleDeckyTDP/LegionGoRemapper frontends from the desktop Steam client.
- Steam Input layouts are not modified by any tweak.

## Not supported

- Hardware tweaks on anything other than the Lenovo Legion Go (1st gen).
- Other distributions (Bazzite, ChimeraOS, ...).
- X11 Plasma sessions (not tested).
