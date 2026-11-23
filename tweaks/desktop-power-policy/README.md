# Desktop Power Policy

**Status: Experimental** · Desktop Mode (system service) · needs sudo · tweak id `desktop-power-policy`

## What This Tweak Does

An event-driven root service (`legion-power-policy.service`) applies a power policy **only while Desktop Mode is active**:

| Power source | Lenovo firmware profile (gamezone) | CPU EPP |
|---|---|---|
| Battery | `balanced` (firmware limits 15 / 15 / 30 W) | `balance_performance` |
| AC adapter | `performance` (20 / 20 / 35 W) | `balance_performance` |

It also re-enables CPU boost, SMT and automatic GPU clocks if a Gaming Mode tool left them disabled.
- In Gaming Mode it **writes nothing**. Steam's own performance settings, or a Decky plugin such as SimpleDeckyTDP, stay in full control.
- If SimpleDeckyTDP or LegionGoRemapper are installed, the service unloads only their frontends from the desktop Steam client. Otherwise they would also try to manage power in Desktop Mode.
- It records the battery level before and after each sleep, and a few snapshots of Gaming Mode values, in `/var/log/legion-power/evidence.jsonl`.

## Why You Need It

After Gaming Mode, the firmware often stays in a "custom" high-limit profile (for example 30 W), and Desktop Mode keeps running with gaming power limits. Some Gaming Mode tools also leave CPU boost disabled or a power-saving EPP set, which makes the desktop feel sluggish.

## What Improves

Measured on the reference device in Desktop Mode, on battery (single 2-minute runs, ±0.2 W noise):

| Configuration | Battery draw (median) | Short CPU burst |
|---|---|---|
| Before: firmware custom 30 W, EPP balance_performance | 7.86 W | 0.225 s |
| This policy: balanced + balance_performance | **7.11 W** (about −10 %) | 0.225 s (unchanged) |
| Rejected: balanced + balance_power | 6.82 W | 0.310 s (+38 % slower) |

So idle and light desktop use draws about 0.75 W less with unchanged responsiveness. **This is one device and one workload.** It is not a battery-life promise.

## Before vs After

BEFORE: Desktop Mode inherits whatever power limits the last game or tool left behind.

AFTER: Desktop Mode always uses the firmware's balanced profile on battery and its performance profile on AC, with boost enabled.

## Requirements

- Lenovo Legion Go (1st gen) with the `lenovo-wmi-gamezone` platform-profile driver (SteamOS 3.9.5 kernel 7.2 has it), and the amd-pstate EPP interface.
- SteamOS 3.9.5 (tested). **sudo**: it installs a root service in `/etc`, which survives SteamOS updates.
- python3 with GObject introspection, and UPower (both ship with SteamOS).
- **Conflicts:** any other tool that sets the firmware profile or EPP in Desktop Mode (for example power-profiles-daemon policies or scripts of your own). Gaming Mode tools do not conflict.

## Installation

```bash
./legiongo.sh install desktop-power-policy
```

## Verification

```bash
./legiongo.sh status desktop-power-policy      # gamezone profile and EPP, service state, last action
journalctl -u legion-power-policy -n 5         # "applied desktop policy (...): battery, balanced, EPP balance_performance"
```

Pause the policy at any time with `sudo touch /etc/legion-power/disabled`, and resume it with `sudo rm /etc/legion-power/disabled`.

## Uninstallation

```bash
./legiongo.sh uninstall desktop-power-policy
```

This stops and removes the service and restores the firmware profile and EPP that were active when you installed it. The evidence log in `/var/log/legion-power/` is kept; delete it manually if you like.

## Known Limitations

- **Experimental.** The battery path is measured. The AC path (performance profile) is implemented but was **not tested** with a charger.
- The policy values are the reference device owner's choice. They are documented, not universally optimal. Change `POLICY` in `/etc/legion-power/legion-power-policy.py` and restart the service to use your own (a re-install then reports the file as changed).
- Desktop/Gaming detection relies on logind session types. A setup with an unusual session layout could be misdetected; check the journal.
- Gaming Mode behaviour (FPS, thermals) is not affected by design, and was not benchmarked.

## Technical Details

- `/etc/legion-power/legion-power-policy.py` (python3, GLib main loop, no polling):
  - Listens to logind seat0 session changes, UPower `OnBattery`, logind `PrepareForSleep`, and Steam restarts (inotify on `~/.steam/steam.pid`).
  - Writes only values that differ, and verifies them by read-back.
  - Writes `/sys/class/platform-profile/*/profile` (gamezone), `cpu*/cpufreq/energy_performance_preference`, `cpufreq/boost`, `smt/control` and `power_dpm_force_performance_level`.
  - Decky plugin frontends are unloaded through Steam's local debugger, only if that debugger is enabled.
- `/etc/systemd/system/legion-power-policy.service`: `WantedBy=multi-user.target`, `Restart=on-failure`.
- The installer writes your home directory into the script (to find `~/.steam/steam.pid`).
- Not part of this tweak: the `acpi_call` kernel module and the SimpleDeckyTDP / LegionGoRemapper plugin setup that the reference device also uses. See `docs/DEVELOPMENT_AUDIT.md`.
