# Precision Touchpad (upstream InputPlumber)

**Status: Partially Verified** (upstream release build) · **Experimental** (patched builds) · System-wide · needs sudo · tweak id `precision-touchpad`

## What This Tweak Does

It runs the **official upstream InputPlumber 0.84.0 release** instead of SteamOS's InputPlumber 0.78.0. InputPlumber is the service that turns the Legion Go controllers and touchpad into the virtual controller Steam uses.
- The stock package stays installed and untouched.
- A small systemd drop-in starts the upstream copy.
- A fail-safe launcher falls back to the stock binary automatically if the upstream copy is ever missing or broken.

Optionally, you can build and install a **patched** InputPlumber with a tap-to-click "lift-off filter" (see *Patched builds*).

## Why You Need It

SteamOS 3.9 ships InputPlumber 0.78.0. Its Legion Go profile reads the right touchpad from the gamepad report, which carries touch data at only about **40 Hz**. Steam therefore gets a new cursor position every 24 ms instead of every 8 ms, and slow cursor movement looks and feels steppy.
- Upstream fixed this in InputPlumber 0.79.2 ([PR #702](https://github.com/ShadowBlip/InputPlumber/pull/702), [issue #538](https://github.com/ShadowBlip/InputPlumber/issues/538)) with a native touchpad driver.
- As of this release, Valve's SteamOS repositories still carry 0.78.0.

## What Improves

- Smoother, more responsive touchpad cursor in Desktop Mode, and on the trackpad in Gaming Mode.
- Measured on the reference device: touchpad updates reaching Steam went from **42 Hz to 106 Hz** while moving (median interval 24 ms → 8 ms).

## Before vs After

BEFORE: the cursor moves in small visible steps, about 40 position updates per second.

AFTER: about 106 position updates per second while moving, with the same speed and acceleration feel (Steam's settings are unchanged).

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

## Requirements

- Lenovo Legion Go (1st gen). The upstream profile covers firmware PIDs 6182–6185 and 61eb–61ee.
- SteamOS 3.9.5 (tested) with InputPlumber older than 0.79.2. If SteamOS already ships 0.79.2 or newer, `check` reports **not-needed** and install refuses.
- **sudo.** Files go to `/home/legiongo-steamos/inputplumber/` (root-owned; `/home` survives SteamOS updates) and `/etc/systemd/system/inputplumber.service.d/`.
- Network access to github.com during installation.
- **Conflicts:** any other InputPlumber `ExecStart` override. It is detected and installation refuses.

## Installation

```bash
./legiongo.sh check precision-touchpad
./legiongo.sh install precision-touchpad
```

The installer:
1. Downloads the release archive.
2. Verifies its SHA-256 against upstream's published checksum.
3. Verifies the binary's SHA-256.
4. Installs the files and restarts InputPlumber. **Controller input pauses for about 3 seconds**; the touchscreen keeps working.

## Verification

```bash
./legiongo.sh status precision-touchpad     # binary: ... (upstream release v0.84.0), service active
systemctl status inputplumber               # Drop-In: 50-legiongo-steamos-inputplumber.conf
```

Then move a finger slowly on the touchpad: the cursor should glide instead of stepping.

## Uninstallation

```bash
./legiongo.sh uninstall precision-touchpad
```

This removes the drop-in and the upstream copy, and restarts InputPlumber on the stock SteamOS package.

## Known Limitations

- **Remove this tweak once SteamOS ships InputPlumber 0.79.2 or newer** (`pacman -Q inputplumber`). `check` will then report `not-needed`.
- Upstream device profiles and capability maps are used as a whole. Behaviour on other controllers that InputPlumber manages can differ slightly from 0.78.
- A post-resume period of erratic cursor movement was observed on the reference device before and after this change. It was not root-caused, and this tweak does not claim to fix it.
- Gaming Mode uses the same InputPlumber, so the change applies there as well. It has not been explicitly tested there beyond normal use.
- Patched builds: the `glide` measurements show it does **not** improve tap precision. Choose `tapfilter` if precise taps matter more to you than glide smoothness.

## Technical Details

- `/home/legiongo-steamos/inputplumber/bin/inputplumber`: upstream release binary (sha256 `b3e6cc3e…cd87ad`), or your own build via `LG_IP_BINARY`.
- `/home/legiongo-steamos/inputplumber/share/inputplumber/`: the release's device profiles, capability maps and schemas (unmodified).
- `/home/legiongo-steamos/inputplumber/bin/inputplumber-launch`: sets `XDG_DATA_DIRS` to the upstream data and execs the upstream binary. If that binary fails `--version`, it execs `/usr/bin/inputplumber`.
- `/etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf`: resets `ExecStart` to the launcher.
- Release archive: `inputplumber-x86_64.tar.gz` v0.84.0, sha256 `1626fb22…2457a`.
- Patches apply to the v0.84.0 source tag. They touch only `src/drivers/legion_go/{mod.rs,go_touchpad_driver.rs}`, and are licensed GPL-3.0-or-later like InputPlumber.
- Adoption: an existing manual override `50-legion-desktop-upstream.conf` with files in `/home/inputplumber-upstream/` is detected. The running build is identified by its checksum.
