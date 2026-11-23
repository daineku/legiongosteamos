# Desktop Touchpad Without Steam

**Reference Verified** on the reference Legion Go · Desktop Mode · no sudo · id `desktop-touchpad`

> Preserves touchpad cursor control when the Steam client is closed.

## What It Does

A tiny background helper (event-driven, about 15 MB of memory, no polling):
- gives the touchpad to KDE whenever Steam is not running;
- hands it back to Steam the moment Steam starts.

Only one of them ever moves the cursor.

## Why You Need It

On SteamOS the touchpad reaches the desktop only through the Steam client. Exit Steam in Desktop Mode, or let it crash, and the touchpad stops working; only the touchscreen is left.

## Before vs After

| | Before | After |
|---|---|---|
| Steam closed or crashed | Touchpad dead | Touchpad works as a normal KDE touchpad within ~2 s |
| Steam started again | Steam controls the pad | Steam controls the pad (no double movement) |

## How It Improves Legion Go

You can quit Steam on the desktop and keep working with the touchpad.

## Install — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install desktop-touchpad
```

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall desktop-touchpad
```

## How to Check It Works

Exit Steam (Steam menu → Exit). After about 2 seconds the touchpad moves the cursor. `journalctl --user -u legiongo-desktop-touchpad -n 5` shows `ENABLE native touchpad`.

## Dependencies

- An InputPlumber with the native touchpad driver. If SteamOS's own InputPlumber lacks it (SteamOS 3.9.x), the installer explains this and offers to install `precision-touchpad` first (only after you agree). If you decline, nothing is changed.
- Your user in the `wheel` group (the default `deck` user is).

## Compatibility

Legion Go (1st gen), SteamOS 3.9.5: Reference Verified. The owner checked Steam exit and restart, and the logs show 6 automatic hand-over cycles and 4 controller re-enumerations (resume) handled without a failure. Other devices: not applicable (it drives the Legion Go's InputPlumber composite device). The installer verifies that the service runs and watches the controller.

## Known Limitations

- Without Steam the pad is single-touch: no two-finger scrolling.
- KDE's own tap-to-click is switched off for this pad, because InputPlumber already sends tap clicks (otherwise one tap would click twice). It is restored on uninstall.

Technical details: [docs/technical/desktop-touchpad.md](../../docs/technical/desktop-touchpad.md)
