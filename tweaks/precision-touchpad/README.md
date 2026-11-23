# Precision Touchpad

**Reference Verified** (Lenovo Legion Go, SteamOS 3.9.5; `glide` in daily use, `tapfilter` measured, `release` used for the rate fix) · Legion Go hardware · system-wide · needs sudo · id `precision-touchpad`

> Improves touchpad responsiveness and cursor precision, making desktop navigation and small-button interaction more comfortable.

## What It Does

It runs a maintained InputPlumber 0.84 build next to SteamOS's own, untouched copy. InputPlumber is the service that turns the Legion Go controllers and touchpad into the virtual controller Steam uses.
- It reads the touchpad through its native interface: about **106 updates per second instead of about 42**.
- It adds a tap-to-click filter, depending on the variant.
- A fail-safe launcher switches back to the stock InputPlumber automatically if our copy is ever missing or broken.

Three variants (choose with `LG_IP_VARIANT`):

| Variant | What you get | Evidence on the reference device |
|---|---|---|
| `glide` (default) | Native rate + smooth, low-lag movement with a short tap window | Daily use since 2026-11-16; the owner's preferred feel. Tap shift ≥ 5 px stayed at 35 % (no tap-precision gain). |
| `tapfilter` | Native rate + taps that click where the cursor is | Taps moving the cursor ≥ 5 px: **36 % → 7 %** (138 taps). About 16 ms extra delay on slow movement only. |
| `release` | Unmodified official InputPlumber 0.84.0 (native rate only) | 42 → 106 Hz measured |

The patched builds come from the source patches in this folder. Rebuilding them gives bit-for-bit identical binaries; the installer verifies the SHA-256 of whatever it installs.

## Why You Need It

SteamOS 3.9 ships InputPlumber 0.78, which reads the right touchpad from the gamepad report at about 40 Hz. The cursor moves in small steps. Tapping also often moves the cursor a few pixels just before the click, so small buttons get missed.

## Before vs After

| | Stock SteamOS 3.9.5 | With this tweak |
|---|---|---|
| Touchpad updates | ~42 per second (24 ms steps) | ~106 per second (8 ms) |
| Slow cursor movement | Visibly steppy | Smooth |
| Tap on a small button (`tapfilter`) | Cursor shifts ≥ 5 px in about 1 of 3 taps | About 1 in 14 taps |

## How It Improves Legion Go

Desktop navigation, text selection and hitting small close or checkbox buttons with the touchpad become comfortable. The trackpad in Gaming Mode benefits too.

## Install — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install precision-touchpad
```

For the tap-precision variant, insert `LG_IP_VARIANT=tapfilter` before `"$d/legiongo.sh"`. For the unmodified upstream build, use `LG_IP_VARIANT=release`. The installer asks for your sudo password, and controller input pauses for about 3 seconds while InputPlumber restarts.

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall precision-touchpad
```

This returns to the stock SteamOS InputPlumber.

## How to Check It Works

1. Run `~/.local/share/legiongo-steamos/v0.2.2-beta/legiongo.sh status precision-touchpad`. It shows the binary (variant) and that the service is active.
2. Move a finger slowly on the touchpad: the cursor glides instead of stepping.

## Dependencies

- Network access to github.com during installation.
- sudo. Files go to `/home/legiongo-steamos/inputplumber/` and a systemd drop-in in `/etc`. Both survive SteamOS updates; `/usr` is never touched.
- No other tweak.

## Compatibility

The installer checks **features, not version numbers**:

| Detected on your device | What happens |
|---|---|
| Stock InputPlumber reads the touchpad at ~40 Hz (SteamOS 3.9.x) | Install recommended |
| Stock InputPlumber already reads the touchpad natively | `release` variant reported as *upstream equivalent* (skipped). `glide`/`tapfilter` still add tap filtering and stay installable. |
| Stock InputPlumber newer than 0.84 | Refused (it would be a downgrade) until the patches are rebuilt for that version. See [docs/MAINTAINING.md](../../docs/MAINTAINING.md). |
| Not a Legion Go (1st gen) | Refused (*incompatible*) |

Tested: Legion Go 83E1, SteamOS 3.9.5. The installer was validated in isolated test installs; it has not been run on a second physical device.

## Recovery

The launcher never leaves you without controls. It starts the **stock** SteamOS InputPlumber instead when:
- our build is missing or broken;
- it crashed 4 times within 3 minutes (it tries our build again at the next boot);
- a SteamOS update ships a stock InputPlumber **newer** than our build (never a downgrade).

Emergency return to stock (SSH, a TTY or a USB keyboard), which removes only this tweak's drop-in:

```bash
sudo /home/legiongo-steamos/inputplumber/bin/legiongo-ip-restore-stock
```

## Resource cost

The native touchpad driver in InputPlumber 0.84 reads the touchpad interface continuously. Measured idle, 30 s each, reference device:

| Build | CPU (one core) | wake-ups/s |
|---|---|---|
| stock 0.78 | 3.1 % | 1,506 |
| upstream 0.84 release | 6.3 % | 2,050 |
| glide | 6.1 % | 2,043 |

That is the price of 106 Hz instead of 42 Hz. Our patch adds nothing measurable on top.

## Known Limitations

- The variant choice is a trade-off: `glide` feels smoother, `tapfilter` clicks more precisely.
- A short period of erratic cursor movement after resume was seen before and after this change. It is not fixed by this tweak.
- Gaming Mode uses the same InputPlumber. It was used normally there but not benchmarked.
- Double-tap and tap-and-drag: in daily use with `glide` on the reference device; with `tapfilter` only taps were measured.

Technical details: [docs/technical/precision-touchpad.md](../../docs/technical/precision-touchpad.md)
