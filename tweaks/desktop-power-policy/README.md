# Desktop Power Policy

**Experimental** · Desktop Mode (system service) · needs sudo · id `desktop-power-policy`

> Keeps the desktop efficient on battery and fast on AC, without touching Gaming Mode.

## What It Does

A small event-driven service, active **only in Desktop Mode**:

| Power source | Lenovo firmware profile | CPU energy preference |
|---|---|---|
| Battery | balanced (15 / 15 / 30 W) | balance_performance |
| Charger | performance (20 / 20 / 35 W) | balance_performance |

It also turns CPU boost, SMT and automatic GPU clocks back on if a game tool left them off. In Gaming Mode it writes nothing, so Steam or SimpleDeckyTDP stay in control.

## Why You Need It

After gaming, the Legion Go often stays in a high-power custom firmware profile on the desktop, wasting battery. Some game tools also leave CPU boost disabled, which makes the desktop sluggish.

## Before vs After

Measured on the reference device, Desktop Mode on battery, light use (single 2-minute runs, ±0.2 W):

| | Battery draw | Short CPU burst |
|---|---|---|
| Before (firmware custom 30 W) | 7.86 W | 0.225 s |
| After | **7.11 W** (about −10 %) | 0.225 s (unchanged) |

This is one device and one workload, not a battery-life promise.

## How It Improves Legion Go

Desktop use draws a little less power on battery without feeling slower, and Gaming Mode settings no longer leak into the desktop.

## Install — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install desktop-power-policy
```

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall desktop-power-policy
```

This restores the firmware profile and energy preference that were active when you installed it.

## How to Check It Works

`~/.local/share/legiongo-steamos/v0.2.1/legiongo.sh status desktop-power-policy` shows the firmware profile and EPP. `journalctl -u legion-power-policy -n 3` shows lines like `applied desktop policy (...): battery, balanced`. Pause the policy with `sudo touch /etc/legion-power/disabled`.

## Dependencies

- sudo (root service in `/etc`).
- The firmware profile driver `lenovo-wmi-gamezone` and amd-pstate EPP, both present in SteamOS 3.9.5.
- Optional: SimpleDeckyTDP / LegionGoRemapper (the `decky-power-plugins` tweak). In Desktop Mode the policy unloads their frontends from the desktop Steam client, so only one tool manages power there.

## Compatibility

Legion Go (1st gen), SteamOS 3.9.5. The battery path was measured. The charger path is implemented but was **not tested**. Gaming Mode is untouched by design. The installer was validated in isolated test installs.

## Known Limitations

- **Experimental:** the values are the reference owner's choice, not a universal optimum. You can change `POLICY` in `/etc/legion-power/legion-power-policy.py` and restart the service.
- It writes a small evidence log to `/var/log/legion-power/` (battery before/after sleep), which is kept after uninstall.

Technical details: [docs/technical/desktop-power-policy.md](../../docs/technical/desktop-power-policy.md)
