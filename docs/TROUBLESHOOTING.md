# Troubleshooting

Start with:

```bash
./legiongo.sh status            # every tweak
./legiongo.sh check <tweak>     # requirements, read-only
```

State, backups and logs: `~/.local/state/legiongo-steamos/<tweak>/` (the `log` file lists every action).

## General

| Symptom | What to do |
|---|---|
| `status` shows `partial` | A recorded file is missing or was edited. Run `install` again to restore it, or `uninstall` to remove the tweak. |
| `install` says `external` | A manual setup of the same fix exists. Use `adopt`, or remove it first. |
| `install` says `untested` | Your SteamOS version is not in the tested list. Use `--force` only if you accept the risk. |
| `sudo: a password is required` | Set a password for `deck` with `passwd` (SteamOS ships without one). |
| "kept ...: it was changed after installation" during uninstall | Intentional. Your edited file was not deleted. Remove it manually if you no longer need it. |

## steam-keyboard

| Symptom | What to do |
|---|---|
| Keyboard looks stock | Restart Steam once (needed after the debugger flag is created). Check `systemctl --user status legiongo-steam-keyboard` and `journalctl --user -u legiongo-steam-keyboard -n 30`. |
| Wrong size after resizing | Hide and reopen the keyboard. |
| Russian characters missing in Chrome | KDE needs the `ru` layout: install with `LG_KEYBOARD_ADD_RU=1`, or add Russian in System Settings → Keyboard → Layouts. |
| Disable temporarily | `touch ~/.config/legiongo-steamos/steam-keyboard/lgk-disabled`, then restart Steam |
| Completely stock again | `./legiongo.sh uninstall steam-keyboard`, then restart Steam |

## precision-touchpad

| Symptom | What to do |
|---|---|
| Controllers unresponsive right after install/uninstall | Wait about 5 s (InputPlumber restart). If they stay dead: `sudo systemctl restart inputplumber`, or reboot. |
| Check which build runs | `./legiongo.sh status precision-touchpad` |
| Emergency fallback | Removing the drop-in returns to stock: `sudo rm /etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf && sudo systemctl daemon-reload && sudo systemctl restart inputplumber` |

## desktop-touchpad

| Symptom | What to do |
|---|---|
| Pad dead after exiting Steam | `journalctl --user -u legiongo-desktop-touchpad -n 20`. A `FAILED` line usually means InputPlumber is older than 0.79.2 or the user is not in `wheel`. |
| Cursor moves twice as far | Should never happen: Steam opening the controller removes the native pad. Restart the service and report the journal lines. |
| Double click on a single tap | KDE tapping must be off for "InputPlumber Touchpad" (the installer does this). Check System Settings → Touchpad. |

## desktop-power-policy

| Symptom | What to do |
|---|---|
| See what it did | `journalctl -u legion-power-policy -n 20` |
| Pause it | `sudo touch /etc/legion-power/disabled` (resume: `sudo rm` the file) |
| Different values wanted | Edit `POLICY` in `/etc/legion-power/legion-power-policy.py`, then `sudo systemctl restart legion-power-policy` |

## mic-enhance

| Symptom | What to do |
|---|---|
| Enhanced Microphone missing | `systemctl --user restart filter-chain`, then `journalctl --user -u filter-chain -n 20` |
| Still distorted | Lower the input level in System Settings → Sound |
| An app uses the raw mic | Select "Enhanced Microphone" in that app |
