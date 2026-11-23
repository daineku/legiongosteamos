# Compatibility

## Evidence levels

| Level | Meaning |
|---|---|
| **Reference Verified** | Working behaviour confirmed on the reference Legion Go, and the installer passed isolated install / reinstall / rollback tests |
| **Experimental** | A working implementation or observed improvement exists, but reliability, compatibility or causality is still under investigation |
| **Upstream equivalent** | (reported by `check` on a device) Stock SteamOS already provides what the tweak would install. The tweak stays maintained and available, but is skipped there. |
| **Incompatible** | (reported by `check` on a device) The detected environment cannot safely use the tweak. Nothing is changed. |

No tweak has been tested on a second physical Legion Go. The installers detect the target device instead of assuming the reference device. They depend on none of the reference device's user name, home path, Steam account, language, country, earlier manual changes or patched binaries; the sandboxed tests check this.

## Reference device

| Component | Version |
|---|---|
| Device | Lenovo Legion Go 83E1 ("Legion Go 8APU1"), BIOS N3CN40WW |
| SteamOS | 3.9.5 (build 20261023.100), kernel 7.2.7-valve2, Plasma 6.7.3 Wayland |
| steamos-manager | 26.4.1 |
| InputPlumber | stock 0.78.0; tweak 0.84.0 (glide build) |
| Decky Loader | v3.3.1 · SimpleDeckyTDP v1.0.7 · LegionGoRemapper v0.3.0 (patched) |

## Matrix

| Tweak | SteamOS 3.9.5 / Legion Go 83E1 | Other SteamOS | Detection (what `check` looks at) |
|---|---|---|---|
| steam-keyboard | Reference Verified (multilingual sync beyond EN/RU: Experimental) | untested (`--force`) | KDE tools, python-gi, Steam installed, debugger flag, uinput; Steam UI hooks at runtime (unsupported hooks switch off individually) |
| precision-touchpad | Reference Verified | untested | Legion Go DMI; stock InputPlumber profile has a native touchpad interface? (→ `release` upstream equivalent); stock version newer than 0.84 → conflict (no downgrade) |
| desktop-touchpad | Reference Verified | untested | `wheel` group, busctl; dependency satisfied by stock InputPlumber with a native touchpad driver or by `precision-touchpad` |
| decky-loader | Reference Verified | untested | Steam installed; existing Decky → `external` (adoptable) |
| decky-power-plugins | Experimental | untested | Legion Go DMI; Decky; existing plugins → `external` |
| desktop-power-policy | Experimental (battery measured, AC untested) | untested | `lenovo-wmi-gamezone` platform profile, amd-pstate EPP, python-gi |
| mic-enhance | Experimental | untested | filter-chain service, CAPS, exactly one internal analog mic node |

## What can break after updates

| Tweak | Depends on | Failure mode |
|---|---|---|
| steam-keyboard | Steam client UI internals: keyboard component methods, `g_PopupManager`, `VirtualKeyboardManager.HandleVirtualKeyDown`, the webpack module with `GetKeyboardLayoutSettings`, keyboard DOM attributes | Each hook is guarded and reported as `unsupported` (`doctor`); the stock keyboard keeps working |
| precision-touchpad | `inputplumber.service`; the Legion Go driver files the patches touch | The launcher falls back to stock if our binary fails. A newer stock version blocks installation until the patches are rebuilt. |
| desktop-touchpad | InputPlumber D-Bus `SetTargetDevices`, the `touchpad` target, process name `steam` | Logs `FAILED` and leaves the targets as SteamOS set them |
| decky-loader / plugins | Steam client injection points | Decky or plugins stop loading until upstream fixes them; Steam itself is unaffected |
| desktop-power-policy | `lenovo-wmi-gamezone`, EPP sysfs, logind/UPower | Logs the missing interface and changes nothing |
| mic-enhance | PipeWire filter-chain, CAPS, ALSA node naming | Re-run install to detect the new node; the raw microphone keeps working |

## Multilingual Input Support (steam-keyboard)

| Steam keyboard layout | Handling | Status |
|---|---|---|
| English (qwerty), Russian | KDE layout synced (`us`, `ru`); physical long-press symbols | Reference Verified |
| German, French, Spanish, Italian, Portuguese, Polish, Czech, Danish, Finnish, Norwegian, Swedish, Hungarian, Romanian, Greek, Ukrainian, Bulgarian (+ phonetic), Turkish Q/F, US-International, Dvorak, Colemak | KDE layout synced when that layout is configured in KDE; Steam's own long-press popup | Experimental (same mechanism, not tested by native speakers) |
| Chinese (all), Japanese (all), Korean, Vietnamese | Steam's own IBus input method / native path, untouched; KDE stays on your layout | Steam native behaviour |
| Right-to-left scripts | Not offered by Steam's keyboard | — |

## Interaction with other software

- Decky Loader and `steam-keyboard` share Steam's debugger flag (reference counted).
- `desktop-power-policy` stays out of Gaming Mode. In Desktop Mode it unloads SimpleDeckyTDP/LegionGoRemapper frontends from the desktop Steam client.
- Steam Input layouts are not modified by any tweak.

## Not supported

Legion Go S, Legion Go 2, other handhelds, other distributions (Bazzite, ChimeraOS, ...), X11 Plasma sessions (not tested).
