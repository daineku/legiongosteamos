# Precision Touchpad (upstream InputPlumber): technical details


- `/home/legiongo-steamos/inputplumber/bin/inputplumber`: upstream release binary (sha256 `b3e6cc3e…cd87ad`), or your own build via `LG_IP_BINARY`.
- `/home/legiongo-steamos/inputplumber/share/inputplumber/`: the release's device profiles, capability maps and schemas (unmodified).
- `/home/legiongo-steamos/inputplumber/bin/inputplumber-launch`: sets `XDG_DATA_DIRS` to the upstream data and execs the upstream binary. If that binary fails `--version`, it execs `/usr/bin/inputplumber`.
- `/etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf`: resets `ExecStart` to the launcher.
- Release archive: `inputplumber-x86_64.tar.gz` v0.84.0, sha256 `1626fb22…2457a`.
- Patches apply to the v0.84.0 source tag. They touch only `src/drivers/legion_go/{mod.rs,go_touchpad_driver.rs}`, and are licensed GPL-3.0-or-later like InputPlumber.
- Adoption: an existing manual override `50-legion-desktop-upstream.conf` with files in `/home/inputplumber-upstream/` is detected. The running build is identified by its checksum.
## Patched builds (optional, Experimental)

Tapping the touchpad could move the cursor a few pixels before the click. InputPlumber forwards the finger's roll-off just before lift-off, and only decides "it was a tap" when the finger lifts. Two patches in `patches/` add a lift-off filter to InputPlumber's Legion touchpad driver:

| Variant | Behaviour | Measured on the reference device (real taps) |
|---|---|---|
| `tapfilter` | Holds slow frames for 24 ms and drops the roll-off at lift-off. Fast motion is never delayed. | Taps shifting ≥ 5 px: **36 % → 7 %** (138 taps). About 16 ms added delay during slow movement only. |
| `glide` | 200 ms tap window, then live movement with a gliding hold. | Smoother and lower-lag movement, but taps shifting ≥ 5 px stayed near baseline (35 %, 118 taps). This is what the reference device runs, by its owner's preference. |

Both patches also reject touchpad frames outside the HID range and set a 300 ms tap timeout.

Build them in a throwaway container. This needs podman, which ships with SteamOS, and network access. Nothing on the system changes:

```bash
tweaks/precision-touchpad/build/build-patched.sh tapfilter     # or: glide
LG_IP_BINARY=tweaks/precision-touchpad/build/out/inputplumber-0.84.0-tapfilter ./legiongo.sh install precision-touchpad
```

The build is reproducible. Building these patches with the script produced binaries bit-for-bit identical to the ones tested on the reference device:
- `tapfilter`: sha256 `9f3d5c1b…67cd1`
- `glide`: sha256 `2fed277f…6fc9`

