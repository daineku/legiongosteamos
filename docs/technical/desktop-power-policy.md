# Desktop Power Policy: technical details


- `/etc/legion-power/legion-power-policy.py` (python3, GLib main loop, no polling):
  - Listens to logind seat0 session changes, UPower `OnBattery`, logind `PrepareForSleep`, and Steam restarts (inotify on `~/.steam/steam.pid`).
  - Writes only values that differ, and verifies them by read-back.
  - Writes `/sys/class/platform-profile/*/profile` (gamezone), `cpu*/cpufreq/energy_performance_preference`, `cpufreq/boost`, `smt/control` and `power_dpm_force_performance_level`.
  - Decky plugin frontends are unloaded through Steam's local debugger, only if that debugger is enabled.
- `/etc/systemd/system/legion-power-policy.service`: `WantedBy=multi-user.target`, `Restart=on-failure`.
- The installer writes your home directory into the script (to find `~/.steam/steam.pid`).
- Not part of this tweak: the `acpi_call` kernel module and the SimpleDeckyTDP / LegionGoRemapper plugin setup that the reference device also uses. See `docs/DEVELOPMENT_AUDIT.md`.
