# Decky Power & Controller Plugins (safe setup)

## Overview

**Reference Verified** for the safe setup and SimpleDeckyTDP (LegionGoRemapper controller features: Experimental) · Legion Go hardware · Gaming Mode · needs sudo · depends on `decky-loader` · id `decky-power-plugins`

> Per-game TDP and Legion Go controller features in Gaming Mode, installed with safe defaults and our safety fixes.

## Problem

SteamOS's own performance overlay has no Legion Go fan, RGB or remapping controls, and its TDP control is generic. These plugins fill that gap; our patch and settings make their first start safe.

## Enhancement

It installs two plugins by Aarron Lee from their official releases (SHA-256 verified):
- **SimpleDeckyTDP** v1.0.7: per-game TDP, CPU boost, SMT, EPP and GPU controls in the Quick Access menu.
- **LegionGoRemapper** v0.3.0: Legion Go back-button remapping, RGB, custom fan curves, charge limit.

What we add:

| Change | Why |
|---|---|
| Safety patch for LegionGoRemapper (in `patches/`) | Fixes four defects: (1) a missing setting could switch the **touchpad off**; (2) loading the plugin switched the **LEDs off**; (3) fan curves were built in a random order, without validation or a minimum; we add a floor of 70/80/95/100 % at 70/80/90/100 °C; (4) a custom fan curve stayed active after unload. |
| Starting settings for SimpleDeckyTDP | Its defaults disable CPU boost and set a power-saving EPP. Ours keep boost and SMT on, use EPP balance_performance with a 25 W default, and skip its one-time SMU (`ryzenadj`) write at start. |
| Starting settings for LegionGoRemapper | Every feature (remapping, RGB, fan curves, charge limit) starts **off**, until you enable it. |
| Its optional udev rule is not installed | That rule makes every Lenovo USB device world-writable, and the plugin works without it. |

Your own plugin settings are never overwritten. Starting settings are written only if none exist.

## User benefit

You get Legion Go-specific power and controller controls in Gaming Mode without the surprises of the stock first start.

### Before vs After

| | Stock plugins | With this tweak |
|---|---|---|
| First start of SimpleDeckyTDP | CPU boost off, power-saving EPP | Boost on, balance_performance |
| Missing touchpad setting | Touchpad switched off | Touchpad stays on |
| Loading LegionGoRemapper | LEDs switched off | LEDs untouched unless RGB is enabled |
| Custom fan curve | Unordered, no minimum | Ordered, validated, safety floor |

## Compatibility

| | Status |
|---|---|
| Install, safety patch, safe first start (boost on, no SMU write; touchpad/LEDs untouched) | Reference Verified |
| SimpleDeckyTDP per-game TDP in Gaming Mode | Reference Verified (per-game profile in use on the reference device) |
| LegionGoRemapper remapping, RGB, fan curves, charge limit | Experimental: never enabled on the reference device |
| Other devices | not applicable (LegionGoRemapper drives Legion Go hardware) |

### Dependencies

`decky-loader` (asked for), sudo, network access to github.com. In Gaming Mode, turn Steam's own TDP limit **off** so the two do not fight.

## Installation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install decky-power-plugins
```

If Decky Loader is missing, the installer explains it and asks before installing it too. If anything fails, both are rolled back.

## Verification

In Gaming Mode: Quick Access (…) → plug icon → SimpleDeckyTDP and LegionGoRemapper are listed. Check that the TDP slider shows 25 W and boost is on.

## Uninstallation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" uninstall decky-power-plugins
```

## Performance

| | Measured / known |
|---|---|
| Memory and CPU | included in Decky Loader's numbers (0.00 % at idle in Desktop Mode) |
| SimpleDeckyTDP in Gaming Mode | re-asserts its values every 15 s (upstream behaviour) |

## Limitations

- Fan control needs the firmware's custom mode. Changing the firmware profile resets custom curves to firmware cooling.
- Plugins can break after Steam client updates until upstream releases fixes. See [docs/THIRD_PARTY.md](../../docs/THIRD_PARTY.md).
- LegionGoRemapper's fan and charge features need the `acpi_call` kernel module, which this project does not install (see the audit).

## Technical details

See [docs/THIRD_PARTY.md](../../docs/THIRD_PARTY.md).
