# Desktop Touchpad Without Steam: technical details


- `~/.local/lib/legiongo-steamos/desktop-touchpad/legion-tp-handover.py`: event driven, no polling. It uses inotify on the Deck hidraw node (`IN_OPEN`/`IN_CLOSE`) and on `/dev` (`IN_CREATE` for hidraw, which covers resume and InputPlumber restarts).
  - Rule: if a process named `steam` has the node open, there is no `touchpad` target; otherwise it adds InputPlumber's `touchpad` target.
  - Only that one entry changes, through `org.shadowblip.Input.CompositeDevice.SetTargetDevices`, so the virtual Steam controller keeps running.
  - Hand-back to Steam is immediate. Hand-over to KDE waits 2 s.
  - Measured cost: about 15 MB RSS, 0 wake-ups in 30 s while idle.
- `~/.config/systemd/user/legiongo-desktop-touchpad.service`: `PartOf=plasma-workspace.target`. `ExecStopPost=... --restore` removes the target even after a crash.
- KDE: `kcminputrc` `[Libinput][0][65535][InputPlumber Touchpad] TapToClick=false`. The previous value is restored on uninstall.
- Why not edit `steamos-manager`'s device file: it is on the read-only system partition, and its schema rejects a `touchpad` entry.
