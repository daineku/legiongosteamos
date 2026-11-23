# Native Steam Keyboard Enhancement

**Status: Partially Verified** · Desktop Mode only · no sudo · tweak id `steam-keyboard`

## What This Tweak Does

It keeps **Valve's own on-screen keyboard** (the one you open with the Steam button + X) and improves how it behaves in KDE Desktop Mode. The changes are applied at runtime each time the keyboard opens. No Steam file is patched or replaced, and nothing changes in Gaming Mode.

A small user service (`legiongo-steam-keyboard.service`) starts with the Plasma session. It loads a script into the running Steam client and adds a few KDE integrations:

| Area | Behaviour |
|---|---|
| Placement | Flush with the bottom edge, edge to edge. The top position sits directly under the KDE panel. |
| Move key | Replaces the large Emoji key. Tap it to switch between bottom and top. |
| Hide key | Closes the keyboard immediately. |
| Transparency | The panel is about 55 % opaque and the keys are slightly transparent. Labels stay solid. |
| Ctrl / Alt keys | Added next to the language key. Tap = next key only, tap twice = lock, hold = held (e.g. Alt+Tab). They are sent as physical keys, so shortcuts work on every layout. |
| Language key | A short tap switches language. Hold it for 500 ms to open Steam's emoji picker. |
| Long press | Releasing on a key types its secondary symbol (`0` → `)`, `9` → `(`, ...). |
| Tab / Shift+Tab | Sent as a genuine Tab key, so web forms and dialogs move to the next or previous field. |
| Backspace hold | Terminals: characters, accelerating. Other apps: 6 characters, then whole words. |
| English / Russian | With KDE's `us,ru` layouts, the language key also switches KDE's active layout, so Russian text arrives reliably in Chrome and X11 apps. |
| Stacking | The keyboard stays above the app launcher and Plasma popups (a KWin window rule). |
| Legion Go controls while the keyboard is open | Left/right sticks move the keyboard's key cursors. Triggers press keys or click. The touchpad stays the mouse. The D-pad becomes arrow keys. |
| Auto-open | Optional, **off by default**. The keyboard opens when a text field gets focus (uses accessibility events). |

## Why You Need It

In Desktop Mode the stock Steam keyboard was designed for Gaming Mode:
- It floats with a gap at the bottom.
- Its Close/Move key moves the keyboard instead of closing it.
- It hides behind the app launcher.
- It has no Ctrl or Alt keys.
- Tab does nothing in Chrome, because Steam sends Tab as a text character.
- Russian characters are often lost in Chrome and X11 apps. This is a Steam keymap-swap bug, [steam-for-linux#13644](https://github.com/ValveSoftware/steam-for-linux/issues/13644).
- The Legion Go's sticks and touchpad are taken over by Steam's built-in keyboard controls.

## What Improves

- Typing in Desktop Mode with the touchscreen or the controller feels like using a normal keyboard.
- Forms can be filled with Tab and Shift+Tab without touching the screen again.
- Shortcuts (Ctrl+C/V/Z, Alt+Tab) and Russian text work.
- The keyboard no longer floats with a gap at the bottom or hides under menus.

## Before vs After

| | Before | After |
|---|---|---|
| Position | Floating, gap at the bottom | Flush bottom, or directly under the panel at the top |
| Close | Close/Move key moves the keyboard | Hide closes, the move key toggles top/bottom |
| Tab in Chrome | Nothing happens | Focus moves to the next field; Shift+Tab goes back |
| Russian in Chrome | Characters can be dropped | Typed as real keys on KDE's `ru` layout |
| Ctrl/Alt shortcuts | Not available | Ctrl and Alt keys, layout independent |
| Under the launcher | Keyboard hidden behind it | Keyboard on top |

## Requirements

- Lenovo Legion Go (1st gen). The keyboard features work on other SteamOS devices, but the controller bridge expects the Legion Go's InputPlumber virtual controller.
- SteamOS 3.9.5 (tested), KDE Plasma 6 Desktop Mode (Wayland).
- Steam client installed.
- **Steam's local debugger.** The script is applied through Steam's local debugger on `127.0.0.1:8080`. It is enabled by the empty file `~/.local/share/Steam/.cef-enable-remote-debugging`. [Decky Loader](https://decky.xyz/) uses the same file. If the file is missing, the installer asks before creating it. While it exists, other local programs can also control the Steam client UI.
- No sudo. Uses python3 with GObject introspection, which ships with SteamOS.
- **Conflicts:** any other tool that modifies the Steam keyboard. A manual copy of this tweak is detected (see Adoption).

## Installation

```bash
git clone https://github.com/daineku/legiongosteamos.git
cd legiongosteamos
./legiongo.sh check steam-keyboard
./legiongo.sh install steam-keyboard
```

If the installer created the debugger flag, **restart Steam once**. Otherwise the keyboard is enhanced the next time it opens.

Options (environment variables for `install`):

| Variable | Effect |
|---|---|
| `LG_KEYBOARD_AUTOOPEN=1` | Do not create the "auto-open off" flag, so the keyboard opens on text-field focus. |
| `LG_KEYBOARD_ADD_RU=1` | Add the Russian layout to KDE's keyboard layouts (restored on uninstall). |

Example: `LG_KEYBOARD_ADD_RU=1 ./legiongo.sh install steam-keyboard`

## Verification

1. Run `./legiongo.sh status steam-keyboard`. It should report `installed`.
2. Run `systemctl --user status legiongo-steam-keyboard`. It should be `active (running)`.
3. Open the keyboard (Steam button + X). It should sit flush at the bottom with a keyboard icon instead of the Emoji key, and Ctrl and Alt keys next to the language key.
4. In Chrome, open a page with two text fields, type in the first one and press Tab. The second field should get focus.

The service log is in `journalctl --user -u legiongo-steam-keyboard`. The script reports anything Steam changed in its status:

```bash
journalctl --user -u legiongo-steam-keyboard -n 20
```

## Uninstallation

```bash
./legiongo.sh uninstall steam-keyboard
```

Then restart Steam (or reboot) for the completely stock keyboard.
- The KWin rule is removed and the KDE layouts are restored (if this tweak added `ru`).
- The debugger flag is removed only if this tweak created it and Decky Loader is not installed.

## Known Limitations

- It depends on the internals of the Steam client UI: component method names, the `g_PopupManager` object and the keyboard's DOM. A Steam client update can turn individual features off. Every hook is guarded, so the keyboard itself keeps working with stock behaviour. Unsupported hooks are logged.
- Only the Steam keyboard languages `qwerty` (→ `us`) and `russian` (→ `ru`) are mapped to KDE layouts.
- Symbols that exist only in the US layout (for example `@`) still go through Steam's fragile path while the Russian layout is active.
- Resizing the keyboard while it is open can occasionally leave it at the wrong size. Hide and reopen it to fix this.
- Auto-open needs accessibility events. For Chrome web fields it also needs Chrome started with `--force-renderer-accessibility` (this costs some CPU on heavy pages).
- The keyboard script itself was verified on the reference device. A fresh installation through this installer has only been tested in the simulated test suite.

## Technical Details

| File | Installed to | Purpose |
|---|---|---|
| `files/lgk-helper.py` | `~/.local/lib/legiongo-steamos/steam-keyboard/` | Session helper: CDP injection, re-injection on Steam restart (inotify on `~/.steam/steam.pid`), optional AT-SPI auto-open state machine, KDE layout sync, controller bridge (reads the InputPlumber `deck-uhid` hidraw while the keyboard is open, drives a small uinput device) |
| `files/lgk-inject.js` | same | Runs inside Steam's `SharedJSContext`. It wraps prototype methods of the keyboard component (`TypeKeyInternal`, `TypeKey`, `BIsKeyEnabled`, `BShowGlyphs`, `LongPressTimerExpired`, `componentDidUpdate`), the layout's `rgLayout`, `Window.ResizeTo` and `VirtualKeyboardManager.HandleVirtualKeyDown` (Tab). `__LGK.teardown()` restores everything. |
| `files/lgk-kwin.js` | same | KWin script. Reports the active window's geometry and class to the helper over D-Bus. |
| `files/legiongo-steam-keyboard.service` | `~/.config/systemd/user/` | `PartOf=plasma-workspace.target`, so it never runs in Gaming Mode |
| KWin rule `legiongo-osk-layer` | `~/.config/kwinrulesrc` (key by key) | Keyboard window on layer 8 (above Plasma popups) |
| Flag `lgk-autoopen-off` | `~/.config/legiongo-steamos/steam-keyboard/` | Auto-open disabled |
| Flag `lgk-disabled` | same | Create it to disable all enhancements at the next Steam start |

- Tab fix: Steam's keyboard ends Tab with `ControllerKeyboardSendText("\t")`, a text tab that Chromium ignores, and drops Shift. The script keeps Steam's pipeline but sends HID 43 (plus a real Left Shift) through `SteamClient.Input.ControllerKeyboardSetKeyState`.
- Resource use (measured): about 41 MB RSS. No CPU while the keyboard is closed (event driven). About 3.5 % of one core while it is open, from reading the 250 Hz controller reports.
- Adoption: `./legiongo.sh adopt steam-keyboard` records an existing manual setup (`lgk-helper.service` with files in `~/.local/lib/legion-desktop-build/lgk/`) without changing it.
