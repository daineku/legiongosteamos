# Desktop Power Policy

## Overview

**Reference Verified** (Lenovo Legion Go, SteamOS 3.9.5) · portable by capability · Desktop Mode (system service) · needs sudo · id `desktop-power-policy`

> Keeps the desktop responsive during everyday work, without unnecessarily aggressive CPU behaviour at idle, and leaves Gaming Mode to Steam.

## Problem

After gaming, the Legion Go often stays in a high-power custom firmware profile on the desktop, wasting battery. Some game tools also leave CPU boost disabled, which makes the desktop sluggish.

## Enhancement

A small event-driven service, active **only in Desktop Mode**:

| Power source | Lenovo firmware profile | CPU energy preference |
|---|---|---|
| Battery | balanced (15 / 15 / 30 W) | balance_performance |
| Charger | performance (20 / 20 / 35 W) | balance_performance |

It also turns CPU boost, SMT and automatic GPU clocks back on if a game tool left them off. In Gaming Mode it writes nothing, so Steam or SimpleDeckyTDP stay in control.

**Portable by capability.** The policy uses whatever the device offers and skips the rest:
- **Lenovo firmware profiles:** only on the Legion Go;
- **EPP:** amd-pstate-epp, or intel_pstate in active mode;
- **CPU boost:** per-policy cpufreq `boost`.

`check` lists what it found. On a device with none of these it reports *incompatible*.

**CPU boost is not "maximum frequency".** Boost on keeps dynamic frequency scaling. The CPU still idles low and only boosts under load. Measured on the reference device, idle on battery: boost on 7.29 W vs boost off 7.15 W (within noise). Boost on made fixed 16-process work 7 % faster (1.59 s vs 1.70 s), at about +3 °C peak temperature. Short single-thread bursts were the same.

## User benefit

Desktop use draws a little less power on battery without feeling slower, and Gaming Mode settings no longer leak into the desktop.

### Before vs After

Measured on the reference device, Desktop Mode on battery, light use (single 2-minute runs, ±0.2 W):

| | Battery draw | Short CPU burst |
|---|---|---|
| Before (firmware custom 30 W) | 7.86 W | 0.225 s |
| After | **7.11 W** (about −10 %) | 0.225 s (unchanged) |

This is one device and one workload, not a battery-life promise.

## Compatibility

| | Status |
|---|---|
| Legion Go (1st gen), SteamOS 3.9.5: battery path | Reference Verified, measured (−0.75 W idle) |
| Legion Go: AC path | Reference Verified functionally: 7 automatic switches to the performance profile on charger/resume in the logs, 0 errors (power on AC not measured) |
| Legion Go: 22+ suspend/resume cycles | re-applied after every resume |
| Other devices with EPP / boost control (e.g. Steam Deck) | compatible by capability, untested. The Legion Go values are not assumed to be optimal there. |

### Dependencies

- sudo (root service in `/etc`).
- The firmware profile driver `lenovo-wmi-gamezone` and amd-pstate EPP, both present in SteamOS 3.9.5.
- Optional: SimpleDeckyTDP / LegionGoRemapper (the `decky-power-plugins` tweak). In Desktop Mode the policy unloads their frontends from the desktop Steam client, so only one tool manages power there.

## Installation

```bash
d=~/.local/share/legiongo-steamos/v0.2.3
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install desktop-power-policy
```

## Verification

`~/.local/share/legiongo-steamos/v0.2.3/legiongo.sh status desktop-power-policy` shows the firmware profile and EPP. `journalctl -u legion-power-policy -n 3` shows lines like `applied desktop policy (...): battery, balanced`. Pause the policy with `sudo touch /etc/legion-power/disabled`.

## Uninstallation

```bash
d=~/.local/share/legiongo-steamos/v0.2.3
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.3 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" uninstall desktop-power-policy
```

This restores the firmware profile and energy preference that were active when you installed it.

## Performance

| | Measured (reference device) |
|---|---|
| Service | 0.00 % CPU at idle, 0 wake-ups/s, 39 MB RSS; event-driven (logind, UPower, inotify), no polling |
| Desktop idle on battery | 7.86 W → 7.11 W (single 2-minute runs, ±0.2 W) |
| CPU boost on vs off | sustained 16-process work 7 % faster, ≈ +3 °C peak; idle draw 7.29 vs 7.15 W (within noise); short bursts unchanged |
| Gaming Mode | writes nothing |

## Limitations

- The values are the reference owner's choice, not a universal optimum. You can change `POLICY` in `/etc/legion-power/legion-power-policy.py` and restart the service.
- It writes a small evidence log to `/var/log/legion-power/` (battery before/after sleep), which is kept after uninstall.

## Technical details

See [docs/technical/desktop-power-policy.md](../../docs/technical/desktop-power-policy.md).
