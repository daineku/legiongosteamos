# Desktop Touchpad Without Steam

**Status: Partially Verified** · Desktop Mode only · no sudo · tweak id `desktop-touchpad` · depends on `precision-touchpad`

## What This Tweak Does

A small user service keeps the Legion Go touchpad working on the KDE desktop **when the Steam client is not running**:
- When Steam is closed or crashes, the service gives the touchpad to KDE.
- When Steam starts again, it hands the touchpad straight back.

Only one of them ever drives the cursor, so there is no double movement.

## Why You Need It

On SteamOS the touchpad reaches the desktop only through Steam:
1. `steamos-manager` tells InputPlumber to expose the controller as a virtual Steam Deck controller, without a separate touchpad device.
2. The Steam client turns touchpad input into mouse movement.
3. Exit Steam in Desktop Mode, or let it crash, and the touchpad is dead. You are left with the touchscreen only.

## What Improves

- The touchpad keeps working after "Exit Steam" or a Steam crash.
- Steam's own touchpad settings apply again as soon as Steam is back, without a controller disconnect.

## Before vs After

BEFORE: Steam closed → the touchpad does nothing.

AFTER: Steam closed → the touchpad works as a normal KDE touchpad within about 2 seconds. Steam reopened → Steam controls it again immediately, with no double cursor movement.

## Requirements

- Lenovo Legion Go (1st gen), SteamOS 3.9.5 (tested), KDE Plasma Desktop Mode.
- **InputPlumber 0.79.2 or newer**, either from SteamOS itself or from the `precision-touchpad` tweak. The installer offers to install that dependency and asks first.
- Your user is in the `wheel` group (the default `deck` user is). InputPlumber's polkit rule lets `wheel` change its target devices without sudo.
- No sudo. Uses python3 and busctl, which ship with SteamOS.

## Installation

```bash
./legiongo.sh install desktop-touchpad
```

## Verification

1. Run `./legiongo.sh status desktop-touchpad`. It should report `installed`.
2. In Desktop Mode, exit Steam (Steam menu → Exit). After about 2 s the touchpad should move the cursor again.
3. The log shows the hand-over: `journalctl --user -u legiongo-desktop-touchpad -f` prints `ENABLE` and `DISABLE` lines.
4. Start Steam again. The touchpad keeps working, and the cursor does not move twice as far.

## Uninstallation

```bash
./legiongo.sh uninstall desktop-touchpad
```

Stopping the service always restores SteamOS's stock target list. The KDE tap-to-click setting for the native pad is restored.

## Known Limitations

- While Steam is not running, the touchpad is a single-contact pad: no two-finger scrolling. KDE's touchpad settings (speed, acceleration) apply.
- Tap-to-click on the native pad comes from InputPlumber itself, so this tweak switches KDE's own tapping off for that device. Otherwise one tap would produce two clicks.
- Verified on the reference device by its owner: Steam exit → touchpad works; Steam restart → no double movement.
- Not explicitly tested: a Steam crash (it uses the same mechanism, since a crash closes the device file), resume from sleep, and switching from Gaming Mode to Desktop Mode. The service has run through many sleep cycles without reported problems.

## Technical Details

- `~/.local/lib/legiongo-steamos/desktop-touchpad/legion-tp-handover.py`: event driven, no polling. It uses inotify on the Deck hidraw node (`IN_OPEN`/`IN_CLOSE`) and on `/dev` (`IN_CREATE` for hidraw, which covers resume and InputPlumber restarts).
  - Rule: if a process named `steam` has the node open, there is no `touchpad` target; otherwise it adds InputPlumber's `touchpad` target.
  - Only that one entry changes, through `org.shadowblip.Input.CompositeDevice.SetTargetDevices`, so the virtual Steam controller keeps running.
  - Hand-back to Steam is immediate. Hand-over to KDE waits 2 s.
  - Measured cost: about 15 MB RSS, 0 wake-ups in 30 s while idle.
- `~/.config/systemd/user/legiongo-desktop-touchpad.service`: `PartOf=plasma-workspace.target`. `ExecStopPost=... --restore` removes the target even after a crash.
- KDE: `kcminputrc` `[Libinput][0][65535][InputPlumber Touchpad] TapToClick=false`. The previous value is restored on uninstall.
- Why not edit `steamos-manager`'s device file: it is on the read-only system partition, and its schema rejects a `touchpad` entry.
