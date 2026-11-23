# Native Steam Keyboard Enhancement

**Reference Verified** (Lenovo Legion Go, SteamOS 3.9.5) · portable: any SteamOS device with KDE Desktop Mode · Desktop Mode only · no sudo · id `steam-keyboard`

> Turns Valve's original on-screen keyboard into a practical desktop typing tool, with multilingual input, reliable navigation and controller-friendly typing, without replacing it.

## What It Does

It keeps **Valve's own on-screen keyboard** (Steam button + X) and improves how it behaves in KDE Desktop Mode. The changes are applied at runtime each time the keyboard opens. No Steam file is patched, and Gaming Mode is not affected.

- **Placement:** flush with the bottom edge, or directly under the KDE panel. A move key switches between the two.
- **A real Hide key.** After Hide, the keyboard stays closed for that field.
- **Slight transparency.**
- **Ctrl and Alt keys** on every layout (Ctrl+C/V/Z, Alt+Tab).
- **Tab / Shift+Tab** move between form fields.
- **Long press** types a key's second symbol.
- **Multilingual Input Support:** KDE's keyboard layout follows the Steam keyboard language, so characters arrive as real keys, including in Chrome. Your own layout comes back when the keyboard closes.
- **Stacking:** the keyboard stays above the app launcher and popups.
- **Controller typing (input profiles, detected automatically):**
  - **Dual-joystick** (Lenovo Legion Go and other handhelds whose controller InputPlumber presents as a virtual Steam Deck controller): the left and right sticks move two independent key cursors, LT presses the key under the left cursor, and R3 (right stick click) presses the key under the right cursor. RT stays the desktop left click, the touchpad stays the mouse, and the D-pad gives arrow keys. Normal controller behaviour returns when the keyboard closes.
  - **Dual-trackpad** (Steam Deck): Steam's own dual-trackpad typing; our bridge stays off.
  - **Touchscreen:** always available.
- **Auto-open on text-field focus:** optional, off by default.

## Why You Need It

The stock keyboard was designed for Gaming Mode, and for a device with two trackpads:
- In Desktop Mode it floats with a gap at the bottom, and its Close key moves it.
- It hides behind menus and has no Ctrl or Alt keys.
- Tab does nothing in Chrome.
- Characters outside the active KDE layout are often lost in Chrome ([steam-for-linux#13644](https://github.com/ValveSoftware/steam-for-linux/issues/13644)).
- **The Legion Go has one trackpad, not two.** Steam's dual-cursor typing has nothing to steer it with, and Steam takes over the sticks with its own keyboard controls.

## Before vs After

| | Before | After |
|---|---|---|
| Position | Floating, gap at the bottom | Flush bottom, or under the panel at the top |
| Closing | Close/Move key moves it | Hide closes it |
| Tab in a web form | Nothing | Next field; Shift+Tab goes back |
| Russian (and other layouts) in Chrome | Characters can be dropped | Real key events once the KDE layout exists |
| Controller typing on Legion Go | No dual-cursor typing | Two sticks = two key cursors |
| Shortcuts | No Ctrl/Alt | Ctrl and Alt on every layout |

## How It Improves Legion Go

Forms, chat and terminal commands can be typed in Desktop Mode with the touchscreen or entirely with the controller, in your languages. The Legion Go's two sticks do the job the Steam Deck's two trackpads do.

## Install — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install steam-keyboard
```

If Steam's local debugger is not enabled yet, the installer asks before enabling it; then restart Steam once. Options (in front of `"$d/legiongo.sh"`):

| Option | Effect |
|---|---|
| `LG_KEYBOARD_LAYOUTS="de fr"` | Add these KDE layouts (XKB codes; variants as `us(intl)`) so your Steam keyboard languages can sync. Removed again on uninstall. |
| `LG_KEYBOARD_AUTOOPEN=1` | Open the keyboard automatically on text-field focus |

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.2-beta; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.2-beta https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall steam-keyboard
```

Restart Steam afterwards for the completely stock keyboard. Only what the tweak added is removed.

## How to Check It Works

1. Open the keyboard (Steam button + X). It is flush at the bottom, with a keyboard icon instead of the Emoji key and Ctrl/Alt next to 🌐.
2. In Chrome, type in a form field and press Tab. The next field gets focus.
3. Tap 🌐 and type. Hide the keyboard: your KDE layout is back.
4. On the Legion Go: move both sticks. Two cursors move; LT and R3 press keys.
5. `~/.local/share/legiongo-steamos/v0.2.2-beta/legiongo.sh status steam-keyboard` shows "working: yes", and each enabled Steam language as *synced*, *needs a KDE layout*, or *handled by Steam* (input methods).

## Dependencies

- Steam's local debugger flag `~/.local/share/Steam/.cef-enable-remote-debugging`, shared with Decky Loader. While it exists, local programs can control the Steam client UI.
- python3 with GObject introspection and KDE's tools. Both ship with SteamOS.
- No other tweak.

## Compatibility

| Feature | Lenovo Legion Go, SteamOS 3.9.5 | Steam Deck / other SteamOS devices |
|---|---|---|
| Placement, Hide, transparency, stacking, Ctrl/Alt, long press, Backspace | Reference Verified | compatible by capability, untested |
| Tab / Shift+Tab | Reference Verified (trusted Chrome key events; on-screen Shift + Tab) | compatible by capability, untested |
| Multilingual: English ↔ Russian sync, restore on Hide, reopen | Reference Verified (v41, live on 2026-11-23) | compatible by capability, untested |
| Multilingual: other XKB layouts (de, fr, es, ua, …) | same code path; not tested by native speakers | — |
| Input-method languages (Chinese, Japanese, Korean, Vietnamese) | Steam's native path, untouched | Steam's native path |
| Dual-joystick typing | Reference Verified | InputPlumber handhelds: compatible by capability, untested. Steam Deck: not used (dual-trackpad is native) |
| Auto-open on focus (optional) | verified earlier (v28–v36), off by default since v37 | — |

The keyboard script depends on Steam client internals. Each hook is checked when the keyboard opens; a hook that a Steam update changed switches itself off, and the stock behaviour stays. `doctor` lists them. Because of this, SteamOS versions are not blocked (version policy: feature checks).

## Known Limitations

- Layout sync needs the matching KDE layout. Nothing is added unless you ask (`LG_KEYBOARD_LAYOUTS`).
- Physical long-press symbols are used on grid-verified layouts (English, Russian); other layouts keep Steam's long-press popup.
- Right-to-left scripts are not offered by Steam's keyboard.
- Resizing while open can leave a wrong size. Hide and reopen to fix it.

Technical details: [docs/technical/steam-keyboard.md](../../docs/technical/steam-keyboard.md)
