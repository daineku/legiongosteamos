# Compatibility

## Tested environment

| Component | Version |
|---|---|
| Device | Lenovo Legion Go 83E1 ("Legion Go 8APU1"), BIOS N3CN40WW |
| SteamOS | 3.9.5 (build 20261023.100), kernel 7.2.7-valve2 |
| KDE Plasma | 6.7.3, Wayland |
| steamos-manager | 26.4.1 |
| InputPlumber (stock) | 0.78.0 |

Other SteamOS versions are reported as `untested`, and need `--force`. Other devices are reported as unsupported for hardware-specific tweaks.

## Update sensitivity per tweak

| Tweak | Depends on | What can break after an update | Failure mode |
|---|---|---|---|
| steam-keyboard | Steam client UI internals: keyboard component method names (`TypeKeyInternal`, ...), `g_PopupManager`, `VirtualKeyboardManager.HandleVirtualKeyDown`, keyboard DOM attributes (`data-key`, ...), Steam's local CEF debugger | A Steam **client** update can rename internals | Each hook is guarded. Missing ones are skipped and listed as `unsupported`, and the stock keyboard keeps working. Check `journalctl --user -u legiongo-steam-keyboard`. |
| precision-touchpad | `inputplumber.service` unit name; Legion Go HID PIDs | A SteamOS update that ships InputPlumber ≥ 0.79.2 makes it unnecessary | The launcher falls back to stock if the upstream binary is unusable. `check` reports `not-needed`; uninstall it then. |
| desktop-touchpad | InputPlumber D-Bus API (`SetTargetDevices`, `touchpad` target), steamos-manager target list, process name `steam` | InputPlumber or steamos-manager API changes | Logs `FAILED` and leaves targets as SteamOS set them (stock behaviour) |
| desktop-power-policy | `lenovo-wmi-gamezone` platform profile, amd-pstate EPP sysfs, logind/UPower D-Bus | A kernel driver rename | Logs "gamezone platform profile not available" and changes nothing else |
| mic-enhance | PipeWire filter-chain, CAPS LADSPA, ALSA node naming | A different codec node name | Re-run `install` to detect the new node; the original microphone keeps working regardless |

## Interaction with other software

- **Decky Loader** uses the same Steam debugger flag as `steam-keyboard`. Uninstalling the keyboard tweak never removes the flag while Decky is installed.
- **SimpleDeckyTDP / LegionGoRemapper / other TDP tools:** `desktop-power-policy` stays out of Gaming Mode. In Desktop Mode it unloads those plugins' frontends from the desktop Steam client, so only one tool manages power there.
- **Gaming Mode** is not changed by `steam-keyboard`, `desktop-touchpad` or `mic-enhance` beyond the shared audio default. `precision-touchpad` changes InputPlumber for both modes.
- **Steam Input layouts** are not modified by any tweak.

## Not supported

Legion Go S, Legion Go 2, other handhelds, non-SteamOS distributions (Bazzite, ChimeraOS, ...), X11 Plasma sessions (not tested).
