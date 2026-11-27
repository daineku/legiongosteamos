# Smart Auto Brightness

## Overview

**Experimental** (new in v0.2.4) · portable by capability · Desktop Mode · no sudo · id `smart-auto-brightness`

> Adaptive brightness that follows the room gently instead of reacting to your hand.

## Problem

KDE Plasma 6.7's built-in automatic brightness (in KWin) has three properties that make it jumpy:
- it maps the light level to an **absolute** brightness;
- it reacts **2 seconds** after the light changes by 20 %;
- it learns a curve from your manual adjustments.

On the Legion Go the light sensor sits near the right hand. Covering it for a moment drops the reading from about 100 to about 16 lux. On the reference device the screen then dimmed from 100 % to about 33 % within 4 seconds, and jumped back when the hand moved.

## Enhancement

One controller replaces KWin's automatic mode. Nothing else touches brightness, so two controllers never fight.

- **Baseline = what you set.** Any brightness change not made by this controller (slider, brightness keys, Plasma) becomes the new baseline.
- **±10 % at most.** 10× darker than when you set the baseline → −10 %; 10× brighter → +10 % (capped at maximum). Never below 5 %, unless you set it lower yourself.
- **Shadows are ignored.**
  - A hand can only make the sensor darker, so the light is judged by the 90th percentile of the last 30 seconds.
  - It is re-evaluated every 15 seconds, and a change needs two evaluations in a row that agree.
  - Readings below 5 lux count as 5 lux.
- **Soft changes.** It only adjusts when the difference is at least 2 % of the range, and ramps over 2 seconds.
- **After sleep:** old readings are discarded, and fresh light decides.
- **Plasma's own API.** It uses `org.kde.ScreenBrightness`, the same path as the brightness slider. KWin's automatic setting is switched off while it runs and restored when it stops (logout, crash, uninstall).

## User benefit

The screen keeps the brightness you chose. It gets slightly brighter in a bright room and slightly dimmer in a dark one, and your hand never makes it flicker.

### Before vs After

| | KWin automatic brightness | Smart Auto Brightness |
|---|---|---|
| Hand covers the sensor for 2–3 s | 100 % → ≈ 33 % within 4 s, then back | no change |
| Room light changes permanently | large jump along the learned curve | at most ±10 % of your setting, ramped |
| You move the slider | the curve is reshaped | the new baseline, respected |

## Compatibility

Needs:
- an ambient light sensor through iio-sensor-proxy;
- Plasma 6 with `org.kde.ScreenBrightness` and KWin automatic brightness (`kscreen-doctor` shows "Automatic brightness: supported").

| Device | Status |
|---|---|
| Lenovo Legion Go (1st gen), SteamOS 3.9.5 | **Experimental**: new; see Verification for what was tested |
| Other SteamOS devices with a light sensor | compatible by capability, untested |

### Dependencies

None (python3 with GObject introspection, iio-sensor-proxy, kscreen-doctor and jq ship with SteamOS).

## Installation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install smart-auto-brightness
```

## Verification

On the reference device (2026-11-26, dim room, about 4 lux): covering the sensor repeatedly for about 6 s in total over 90 s left the brightness unchanged at your 30 %. An earlier median-based draft did react (±8 %) and was replaced. The controller logic (shadows, ±10 %, persistence, manual baseline, floor) is unit-tested. Not yet observed in daylight.

1. `status smart-auto-brightness` should show `working: yes`. One controller is active, and KWin's automatic mode is off.
2. Cover the sensor (top right of the screen) with your hand for a few seconds. The brightness does not change.
3. Move the brightness slider. `journalctl --user -u legiongo-auto-brightness -n 5` shows `manual change -> baseline …`.

## Uninstallation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" uninstall smart-auto-brightness
```

KWin's automatic brightness is restored to its setting from before installation.

## Performance

| | Measured (reference device) |
|---|---|
| Light sensor while claimed | iio-sensor-proxy 0.03 % CPU, 2.7 wake-ups/s (the same as with KWin's mode, which also claims it) |
| Controller | 0.00 % CPU, 0.55 wake-ups/s, 30 MB RSS (python3, event-driven: sensor D-Bus signals, one timer every 15 s) |

Sampling less often would not save measurable power: the sensor stays claimed in both cases.

## Limitations

- It reacts to lasting light changes within about 30–60 seconds, by design.
- KWin's learned curve is not used while this runs. It is kept and restored on uninstall.
- Gaming Mode uses Steam's own adaptive brightness setting; this tweak does not run there.

## Technical details

- `~/.local/lib/legiongo-steamos/smart-auto-brightness/legiongo-auto-brightness.py`: the controller.
- `kwin-auto-brightness.sh`: switches KWin's automatic mode on the internal panel through `kscreen-doctor output.<panel>.autoBrightness.enable|disable`.
- `~/.config/legiongo-steamos/smart-auto-brightness/kwin-auto-before`: KWin's state before installation.
- `~/.config/systemd/user/legiongo-auto-brightness.service`: `PartOf=plasma-workspace.target`, `ExecStartPre` switches KWin off, `ExecStopPost` restores it.
- Root cause analysis, from the KWin Plasma/6.7 source:
  - `AutoBrightnessCurve` stores 11 lux values for 0 %…100 %;
  - `Workspace::applyLightChanges` applies `curve.sample(lux)` as absolute brightness;
  - the deadzone is `KWIN_AUTO_BRIGHTNESS_DEADZONE` (default 20 %) with a 2 s single-shot timer;
  - there is no lux filtering.
