# Native Steam Keyboard Enhancement: technical details


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

## Multilingual Input Support (v41)

- Steam types natively only the characters that exist in KDE's **active** XKB layout. Everything else goes through a keymap-swap trick that Chromium and X11 clients drop ([steam-for-linux#13644](https://github.com/ValveSoftware/steam-for-linux/issues/13644)).
- `lgk-inject.js` maps each of Steam's 33 keyboard layouts (`LAYOUTS`, `LAYOUT_IDS`) to:
  - `kind: "xkb"`, with an XKB layout and variant, for direct-key languages;
  - `kind: "native"`, for Steam's IBus input methods (Chinese, Japanese, Korean) and Vietnamese, which are left untouched.
- The user's enabled layouts are read from Steam's keyboard settings store (`GetKeyboardLayoutSettings().selectedLayouts`). The store is found by module **content** in `webpackChunksteamui`, not by its hashed id, and reported to the helper (`layouts` event).
- On a language switch, the helper:
  1. remembers the user's KDE layout ("home");
  2. switches KDE to the exact `(layout, variant)` if it is configured, and confirms it back to the page (`__LGK.kdeLayout`);
  3. restores the home layout on Hide and on exit.

  Missing KDE layouts are logged and listed by `legiongo.sh status steam-keyboard` (from `$XDG_RUNTIME_DIR/lgk-languages.json`). They are never added silently; the installer adds them only with `LG_KEYBOARD_LAYOUTS`.
- Physical long-press chords (real Shift + evdev key) are used only on layouts whose Steam key grid was verified to match XKB key for key (`grid: "ansi"`: qwerty, russian), and only once KDE is confirmed on the matching layout. Other layouts keep Steam's own long-press popup.
- Live check on the reference device (2026-11-23): v41 detected the enabled layouts `[qwerty → us, russian → ru]` and tracked the current language, with no unsupported hooks. The helper's matching and reporting logic is unit-tested (`tests/test_lgk_helper.py`).

## Physical typing on grid-verified layouts (v45/v46)

**Problem:** Steam types a character by looking up a key code in its own copy of the layout. On the reference device that table went stale: Russian `о` produced keycode 158 (`XF86WWW`, "LaunchWebBrowser"), although KWin's keymap was correct (`Cyrillic_o` on `<AC07>`). The old v40 script showed the same failure, so it was not caused by our code, and a Steam restart fixed it.

**Fix (`typePhysical` in lgk-inject.js):** on layouts marked `grid: "ansi"` (qwerty, russian), once lgk-helper has confirmed KDE on the matching XKB layout, a key of the main grid is sent as the evdev scancode of its grid position (`posScan`) through lgk-helper's uinput device. Space, Backspace and Enter are sent the same way.
- **Shift:** set when Steam's Shift is active (Steam then shows the shifted labels).
- **Letters:** uppercase with Shift or Caps Lock, Steam's own rule.
- **One-shot Shift:** a Shift already used by the previous key is ignored even before Steam's React state updates.
- **One path:** all keys of the layout go the same way, so fast typing cannot be reordered. Double Space uses it too.

**Safety:** lgk-helper forgets the layout confirmation whenever it (re)connects (`resyncLang`), because an exiting helper restores the user's KDE layout. Physical typing therefore never sends Russian key positions to an English layout.

**Verified live (2026-11-27):**
- the full Russian alphabet including `о` and `ё`, typed back-to-back;
- `Привет` with one-shot Shift; Caps Lock (`МИР`, digits unchanged);
- shifted symbols (`"`, `№`, `!`, `@`); English punctuation;
- double space (`да. Нет`);
- a helper restart while typing (`окно`);
- all key events trusted, none mapped to media keys.
