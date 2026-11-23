# Native Steam Keyboard Enhancement

**Reference Verified** on the reference Legion Go (Multilingual Input Support for languages other than English/Russian: **Experimental**) · Desktop Mode · no sudo · id `steam-keyboard`

> Enhances the original Steam keyboard for everyday Desktop Mode typing, multilingual input, focus stability and navigation.

## What It Does

It keeps **Valve's own on-screen keyboard** (Steam button + X) and improves how it behaves in KDE Desktop Mode. The changes are applied at runtime each time the keyboard opens. No Steam file is patched, and Gaming Mode is not affected.

- **Placement:** flush with the bottom edge, or directly under the KDE panel. A move key switches between the two.
- **A real Hide key.**
- **Slight transparency**, so you can see what is behind the keyboard.
- **Ctrl and Alt keys**, which work on every layout (Ctrl+C/V/Z, Alt+Tab).
- **Long press** types a key's second symbol (`0` → `)`).
- **Tab and Shift+Tab** move between form fields, like a real keyboard.
- **Multilingual Input Support:** when you switch the Steam keyboard language, KDE's keyboard layout follows it. Characters then arrive as real keys, also in Chrome and other apps that drop them otherwise.
- **Stacking:** the keyboard stays above the app launcher and other popups.
- **Legion Go controls while the keyboard is open:** sticks move key cursors, the triggers press keys, the touchpad stays the mouse, and the D-pad gives arrow keys.
- **Auto-open on text-field focus:** optional, off by default.

## Why You Need It

The stock keyboard was made for Gaming Mode:
- In Desktop Mode it floats with a gap at the bottom, and its Close key moves it instead of closing it.
- It hides behind menus and has no Ctrl or Alt keys.
- Tab does nothing in Chrome.
- Characters that are not in the active KDE layout (for example Cyrillic or accented letters) are often lost in Chrome. This is a Steam bug, [steam-for-linux#13644](https://github.com/ValveSoftware/steam-for-linux/issues/13644).

## Before vs After

| | Before | After |
|---|---|---|
| Position | Floating, gap at the bottom | Flush bottom, or under the panel at the top |
| Closing | Close/Move key moves it | Hide closes it |
| Tab in a web form | Nothing happens | Next field; Shift+Tab goes back |
| Non-English text in Chrome | Characters can be dropped | Typed as real keys once the KDE layout exists |
| Shortcuts | No Ctrl/Alt | Ctrl and Alt keys on every layout |
| App launcher open | Keyboard hidden behind it | Keyboard on top |

## How It Improves Legion Go

You can fill in forms, chat and type commands in Desktop Mode with the touchscreen or the controller, in your languages, without fighting the keyboard.

## Install — One Command

Open Konsole in Desktop Mode and paste:

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install steam-keyboard
```

If Steam's local debugger is not enabled yet, the installer asks before enabling it, and you then restart Steam once.

Options (put them in front of the last part of the command, e.g. `LG_KEYBOARD_LAYOUTS="de fr" "$d/legiongo.sh" install steam-keyboard`):

| Option | Effect |
|---|---|
| `LG_KEYBOARD_LAYOUTS="de fr"` | Adds these KDE keyboard layouts (XKB codes; variants as `us(intl)`), so your Steam keyboard languages can sync. Removed again on uninstall. |
| `LG_KEYBOARD_AUTOOPEN=1` | Opens the keyboard automatically when a text field gets focus. |

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall steam-keyboard
```

Restart Steam afterwards for the completely stock keyboard. Only what the tweak added is removed; your KDE settings stay.

## How to Check It Works

1. Open the keyboard (Steam button + X). It sits flush at the bottom, with a keyboard icon instead of the Emoji key and Ctrl/Alt next to the language key.
2. In Chrome, type in a form field and press Tab. The next field gets focus.
3. Switch the keyboard language with the 🌐 key and type a few letters.
4. Run `~/.local/share/legiongo-steamos/v0.2.1/legiongo.sh status steam-keyboard`. It shows each Steam keyboard language you enabled, and whether it is *synced* to a KDE layout, *needs a KDE layout*, or is handled by Steam itself (input methods).

## Dependencies

- Steam's local debugger: an empty file `~/.local/share/Steam/.cef-enable-remote-debugging`, also used by Decky Loader. While it exists, local programs can control the Steam client UI.
- python3 with GObject introspection and KDE's tools. Both ship with SteamOS.
- No other tweak.

## Compatibility

| Item | Status |
|---|---|
| Legion Go (1st gen), SteamOS 3.9.5, Plasma 6 Wayland | Reference Verified (all keyboard features; English/Russian input) |
| Other Steam keyboard languages with an XKB layout: German, French, Spanish, Ukrainian, Greek, Czech, Nordic, Polish, Portuguese, Romanian, Turkish, Hungarian, Italian, Bulgarian, Dvorak, Colemak, US-International | Experimental: same mechanism, not tested by a native speaker |
| Chinese, Japanese, Korean, Vietnamese | Steam's own input-method path is left untouched (no layout sync) |
| Other SteamOS devices | Keyboard features should work; the controller bridge expects the Legion Go |
| Installer | Validated in isolated test installs; a fresh install on a second device has not been done |

## Known Limitations

- It depends on Steam client internals. After a Steam update, individual features can switch themselves off; the keyboard itself keeps working. `./legiongo.sh doctor` reports it.
- Layout sync needs the matching KDE layout. Nothing is added unless you ask (`LG_KEYBOARD_LAYOUTS`).
- Physical long-press symbols are used only on grid-verified layouts (English, Russian). Other layouts keep Steam's own long-press popup.
- Right-to-left languages are not offered by Steam's keyboard.
- Resizing while open can leave a wrong size. Hide and reopen to fix it.

Technical details: [docs/technical/steam-keyboard.md](../../docs/technical/steam-keyboard.md)
