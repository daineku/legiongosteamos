# Performance and resource use

All numbers were measured on the reference device: Lenovo Legion Go 83E1, SteamOS 3.9.5, Desktop Mode, idle, keyboard closed, on 2026-11-23 unless noted.
- **CPU** is the share of one core.
- **Wake-ups** are voluntary + involuntary context switches per second, a proxy for timer and poll activity.
- Numbers not measured are marked as such. None are estimated.

## Runtime components

| Tweak | Process | Runs | Mode | CPU idle | Wake-ups/s | Memory (RSS) | Replaces or adds |
|---|---|---|---|---|---|---|---|
| steam-keyboard | `lgk-helper.py` (python3, GLib, inotify, CDP) | continuously in the Desktop session | Desktop only | 0.00 % | 0.07 | 41 MB | adds; event-driven |
| steam-keyboard, keyboard open | same | while the keyboard is open | Desktop | ≈ 3.5 % (earlier measurement: reading the 250 Hz controller reports for the bridge) | — | — | — |
| desktop-touchpad | `legion-tp-handover.py` (python3, inotify) | Desktop session | Desktop only | 0.00 % | 0.00 | 15 MB | adds; event-driven |
| desktop-power-policy | `legion-power-policy.py` (python3, GLib, D-Bus signals) | root service, always | writes only in Desktop Mode | 0.00 % | 0.00 | 39 MB | adds; event-driven, no polling |
| mic-enhance | PipeWire `filter-chain` (existing SteamOS user service) | always | both | 0.00 % (mic idle) | 0.00 | 11 MB | uses an existing service |
| precision-touchpad | `inputplumber` 0.84 (glide) | always | both | 6.1–6.7 % | ≈ 2,040–2,250 | 24 MB after start (55 MB after 5 days) | **replaces** stock InputPlumber (stock: 3.1 %, 1,506/s, 21 MB) |
| smart-auto-brightness | `legiongo-auto-brightness.py` (python3, GLib) | Desktop session | Desktop only | 0.00 % | 0.55 (sensor signals + one 15 s timer) | 30 MB | replaces KWin's automatic brightness (one controller); iio-sensor-proxy 0.03 % CPU either way |
| decky-loader | `PluginLoader` (5 processes) | root service, always | both | 0.00 % | — | 111 MB | adds (Decky's own design) |
| decky-power-plugins | Python back-ends inside Decky | with Decky | Gaming Mode use | included above | — | included above | adds |

There are no timers, cron jobs or background updaters. The installer runs only when called.

### InputPlumber comparison (precision-touchpad)

Each build was restarted and measured for 30 s, idle, on the same device:

| Build | CPU | Wake-ups/s | RSS |
|---|---|---|---|
| stock 0.78.0 | 3.13 % | 1,506 | 20.6 MB |
| upstream 0.84.0 release | 6.27 % | 2,050 | 23.7 MB |
| 0.84.0 glide (our patch) | 6.13 % | 2,043 | 24.0 MB |

- The extra ~3 percentage points come from upstream's native touchpad driver, which reads the touchpad's own interface (the source of the 42 → 106 Hz improvement).
- Our lift-off patch adds no measurable cost.
- The effect on battery draw was not isolated. It is a known trade-off and a candidate for upstream optimisation.

## Power measurements (battery, Desktop Mode)

| Measurement | Result |
|---|---|
| Desktop power policy: before (firmware custom 30 W) → after (balanced + balance_performance), idle | 7.86 W → **7.11 W** (single 2-minute runs, ±0.2 W noise). Burst latency unchanged (0.225 s). |
| CPU boost on vs off, idle 90 s | 7.29 W vs 7.15 W (difference within noise) |
| CPU boost on vs off, fixed 16-process work | 1.59 s vs 1.70 s (boost on 7 % faster); peak 53 °C vs 50 °C |
| CPU boost on vs off, short single-thread bursts | 0.229 s vs 0.224 s (no difference) |
| Rejected: balanced + EPP balance_power | 6.82 W, but bursts 38 % slower |

Not measured:
- AC power draw;
- browser workloads;
- Gaming Mode FPS and frame times (the tweaks do not act there, except InputPlumber and the Decky plugins);
- the battery cost of InputPlumber 0.84's extra CPU.

## GPU and rendering

- The keyboard's transparency uses CSS alpha on the existing panel inside Steam's own window, with no blur and no extra compositing pass.
- No tweak adds a render loop or overlay.

## Design rules

- Event-driven only: inotify, D-Bus signals, logind/UPower events. Nothing polls.
- User services start and stop with the Plasma session (`PartOf=plasma-workspace.target`), so Gaming Mode runs without them.
- Python is used where it was already the verified implementation (stdlib + PyGObject, both shipped with SteamOS). The measured idle cost of those helpers is 0 %.
