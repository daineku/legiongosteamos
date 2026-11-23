# Development audit

This audit records every modification found on the **reference device** (Lenovo Legion Go 83E1, SteamOS 3.9.5 build 20261023.100, kernel 7.2.7-valve2, Plasma 6.7.3 Wayland, steamos-manager 26.4.1, stock InputPlumber package 0.78.0). It was made on 2026-11-23 by inspecting the live configuration:
- systemd system and user units, drop-ins, `/etc/udev`, `/etc/modprobe.d`;
- KDE config files, PipeWire/WirePlumber state, Decky plugins;
- the project working directories and their change logs, backups and measurement captures from the earlier development sessions.

Shell history was not replayed. Each item was checked against the files actually present and active.

Legend:
- **A** active
- **B** proven to work (measured or confirmed by the device owner)
- **C** experimental
- **D** obsolete
- **E** has dependencies
- **F** safely reproducible
- **G** needs device-specific adaptation
- **H** must not be distributed

## Packaged

### 1. Native Steam keyboard enhancement → `tweaks/steam-keyboard`
| Field | Value |
|---|---|
| Original problem | Stock Steam OSK in Desktop Mode: bottom gap, Close/Move key, hidden under Plasma popups, no Ctrl/Alt, Tab ignored by Chrome (sent as text `"\t"`, Shift dropped), Russian characters dropped by Chromium and X11 clients (steam-for-linux#13644), controller taken over by Steam's built-in keyboard action set |
| Solution | Runtime injection into Steam's SharedJSContext over the local CEF debugger. A user helper (`lgk-helper.py`) handles re-injection, KDE layout sync, the controller bridge and optional AT-SPI auto-open. A KWin script reports the active window. A KWin rule puts the keyboard on layer 8. |
| Files on device | `~/.local/lib/legion-desktop-build/lgk/{lgk-helper.py,lgk-inject.js,lgk-kwin.js}`, `~/.config/systemd/user/lgk-helper.service`, `~/.config/kwinrulesrc` (rule `lgk-osk-layer`), `~/.config/legion-desktop-build/lgk-autoopen-off`. Personal settings: `~/.config/kxkbrc` (`us,ru`, indicator hidden), `~/.config/plasmarc` (layout OSD off), tray layout item removed. |
| Dependencies | Steam CEF debugger flag `~/.local/share/Steam/.cef-enable-remote-debugging` (pre-existing, also used by Decky). python3-gi (Gio, Atspi). `/dev/uinput` and the `deck-uhid` hidraw via logind uaccess ACLs (stock). |
| Permissions | user only |
| Scope | Desktop Mode only (`PartOf=plasma-workspace.target`) |
| Status | A, B (all features confirmed on the device by the owner; Tab/Shift+Tab verified with trusted Chrome key events and live typing), E, F |
| Risks | Depends on Steam UI internals (method names, `g_PopupManager`, DOM). Guarded: unsupported hooks are skipped and the stock keyboard keeps working. The debugger flag lets local processes control the Steam UI. |
| Packaging decisions | Script v40 copied verbatim. Only the two flag paths were changed to `~/.config/legiongo-steamos/steam-keyboard/`. Auto-open off by default (the reference configuration). `ru` layout optional (`LG_KEYBOARD_ADD_RU=1`). Tray, OSD and indicator changes not packaged (personal preference). |
| Historical | Earlier versions used a Chrome flag `--force-renderer-accessibility` (removed when auto-open was turned off) and a spell-check bar (rejected as glitchy, removed). Neither is packaged. **D** |

### 2. Upstream InputPlumber override → `tweaks/precision-touchpad`
| Field | Value |
|---|---|
| Original problem | InputPlumber 0.78 reads the touchpad from the gamepad report at about 42 Hz |
| Solution | Upstream v0.84.0 in `/home/inputplumber-upstream`, systemd drop-in `/etc/systemd/system/inputplumber.service.d/50-legion-desktop-upstream.conf`, fail-safe launcher |
| Running build | `0.84.0-legionfix5` ("glide" lift-off filter), sha256 `2fed277f…6fc9` |
| Permissions | root |
| Scope | System (Desktop and Gaming Mode) |
| Status | A. B for the rate fix (42 → 106 Hz measured; the owner confirmed smoothness). Tap filter: `legionfix4` measured 36 % → 7 % taps shifting ≥ 5 px; `legionfix5` measured 35 % (no tap improvement) but kept by the owner for its smoother glide. C for patched builds. E, F. |
| Reproducibility | Patches regenerated against the pristine v0.84.0 source tag. `build/build-patched.sh` produced **bit-identical** binaries to the device's `legionfix5` (glide) and `legionfix4` (tapfilter). |
| Risks | Restarting InputPlumber pauses controller input for about 3 s. Upstream profiles replace 0.78's. Becomes obsolete when SteamOS ships ≥ 0.79.2 (checked automatically). |
| Packaging decisions | Default installs the unmodified upstream release (sha-verified download). Patched builds are opt-in through `LG_IP_BINARY`. Install path renamed to `/home/legiongo-steamos/inputplumber`. Development builds legionfix1–3 and 6 are not published (superseded). |

### 3. Touchpad hand-over → `tweaks/desktop-touchpad`
| Field | Value |
|---|---|
| Original problem | steamos-manager forces InputPlumber targets `[deck-uhid, keyboard, mouse]` (no `touchpad`), so the pad is dead whenever Steam is not running |
| Solution | `legion-tp-handover.py` user service. It adds or removes only the `touchpad` target based on whether a `steam` process holds the Deck hidraw open (inotify, no polling). KDE `TapToClick=false` for "InputPlumber Touchpad" (InputPlumber already generates tap clicks). |
| Files on device | `~/.local/lib/legion-desktop-build/legion-tp-handover.py`, `~/.config/systemd/user/legion-tp-handover.service`, `~/.config/kcminputrc` |
| Dependencies | InputPlumber ≥ 0.79.2 (native touchpad driver) → `precision-touchpad`, or a newer SteamOS. User in `wheel` (polkit). |
| Status | A, B (owner verified: Steam exit → pad works, Steam restart → no double movement), E, F |
| Not verified | Steam crash, resume, Gaming→Desktop switch (the mechanism covers them; no explicit test) |

### 4. Desktop power policy → `tweaks/desktop-power-policy`
| Field | Value |
|---|---|
| Original problem | Desktop Mode inherited Gaming Mode power state (firmware custom 30 W). Some Gaming Mode tools disable boost or set balance_power. |
| Solution | Root service `/etc/legion-power/legion-power-policy.py` + `/etc/systemd/system/legion-power-policy.service`. Desktop only: battery → gamezone balanced, AC → performance, EPP balance_performance, boost/SMT/GPU auto ensured. Unloads SimpleDeckyTDP/LegionGoRemapper frontends in desktop Steam. Evidence log `/var/log/legion-power/evidence.jsonl`. |
| Permissions | root |
| Status | A. B on battery (7.86 → 7.11 W idle, unchanged burst latency; 22 suspend/resume cycles logged without problems). AC path not tested. C overall. |
| Packaging decisions | Script copied verbatim. The hard-coded Steam home is templated (`@USER_HOME@`), and the doc references were updated. Paths unchanged, so the reference device shows "identical". The `legion-power` CLI is not packaged: it referenced the private project directory and plugin setup. |

### 5. Internal microphone enhancement → `tweaks/mic-enhance`
| Field | Value |
|---|---|
| Original problem | Internal mic thin and distorting; needed the duplex profile |
| Solution | `~/.config/pipewire/filter-chain.conf.d/60-legion-mic-enhance.conf` (EQ + CAPS compressor + clamp), default source `legion_mic_enhanced`, card profile `output:analog-stereo+input:analog-stereo`, low hardware input volume |
| Status | A. C: tuned by ear; no formal confirmation recorded. F, G (the ALSA node name is detected at install). |
| Packaging decisions | Node and file names renamed (`legiongo_…`). The hardware input volume is not changed (documented as a tip). |

## Not packaged

| Modification found | Why it is not published | Class |
|---|---|---|
| Static Wi-Fi regulatory domain, `/etc/modprobe.d/legion-wifi-regdom.conf` | Re-investigated in v0.2.0 (see below). **Never applied by the kernel**, so it cannot be the cause of the observed faster reconnects. Kept as research in `experimental/wifi-reliability/` with a read-only measurement tool. | A, E |
| udev rule `/etc/udev/rules.d/70-legion-go-libinput-ignore-raw.rules` (libinput ignores raw Legion USB interface 1) | Addresses a re-enumeration race that was confirmed to exist but was **not shown to cause** the post-resume cursor symptom it was meant for. No measured benefit. | A, C |
| `acpi_call` kernel module built for the exact kernel (`/etc/legion-power/modules/<kver>/`, `legion-acpi-call.service`) | Out-of-tree kernel module: taints the kernel, must be rebuilt after every kernel update, and was only needed for LegionGoRemapper's fan/charge features, which are seeded OFF | A, E, G |
| SimpleDeckyTDP v1.0.7 and LegionGoRemapper v0.3.0 Decky plugins with local safety patches and seeded settings | **Integrated in v0.2.0** as `decky-power-plugins` (pinned releases, SHA-256, our BSD-licensed patch, settings overlay). | A, E, F |
| Decky Loader (`plugin_loader.service`) | **Integrated in v0.2.0** as `decky-loader` (pinned v3.3.1, binary identical to the reference install). | A, F |
| Remote-desktop app (Flatpak, user service) and its connection settings | Personal setup with account and peer identifiers; generic app installation, not a Legion Go fix | A, H |
| Steam Input configset for the Legion Go (backup only; restored to stock) | Not active: the stock configset is in place | D |
| KDE cursor theme, mouse acceleration for the stick mouse, tray/OSD layout tweaks | Personal preference | A, H |
| Diagnostic KWin scripts (`cursorlog`, `jumpwatch`) and capture tools | Session-only diagnostics, not fixes | D |
| InputPlumber development builds `legionfix1-3`, `legionfix6` | Superseded by the published variants; `legionfix6` (16 ms) was only simulated, never measured | D, C |
| systemd `NetworkManager` / `systemd-logind` drop-ins | Stock SteamOS files, not modifications | — |

## Open questions recorded during the audit

- Post-resume erratic cursor for about one minute: observed, not root-caused. No tweak claims to fix it.
- Controllers occasionally needing a manual reconnect before one test session: observed once, not investigated.
- Gaming Mode effects of `precision-touchpad` and `desktop-power-policy`: by design limited; not benchmarked.

## v0.2.0 reassessment (2026-11-23)

### Wi-Fi

| Category | Finding | Evidence |
|---|---|---|
| A. Proven configuration changes | `/etc/modprobe.d/legion-wifi-regdom.conf` (static country) | file present since 2026-11-13; `/sys/module/cfg80211/parameters/ieee80211_regdom` set |
| B. User-observed improvements | faster reconnect after sleep, fewer long interruptions | owner's daily use |
| C. Measured | resume → Wi-Fi connected: one baseline sample 19.8 s (2026-11-13); after: median 1.5 s, p90 19.6 s, max 75.7 s over 22 resumes | journal; `experimental/wifi-reliability/wifi-report.sh --all` |
| D. Unconfirmed causal explanation | SteamOS 3.9.5 "fast WiFi reconnect on resume" in wpa_supplicant (backend `wpa_supplicant`, set in Valve's `99-valve-wifi-backend.conf`) | release notes; no A/B test |
| E. Ineffective | the static country: global regdom stays `00`; all 20 regdom changes this boot are `BEACON_HINT`; none is USER/COUNTRY | `iw reg get`, journal |

Other Wi-Fi configuration checked and found **stock**:
- NetworkManager conf (`10-steamos-defaults.conf`, `20-connectivity.conf`, Valve's `99-valve-wifi-backend.conf` with `wifi.powersave=3`);
- no dispatcher scripts; iwd inactive; mt7921e parameters default;
- no Wi-Fi related services or scripts from this project.

Conclusion: nothing distributable. A Wi-Fi tweak needs a measured A/B result on the same network.

### Multilingual keyboard

v40 had Russian-only code paths: `XKB_FOR = {russian: "ru", qwerty: "us"}`, a reset to `us` on hide, and grid chords tied to that map. v41 makes them generic:
- a table of all 33 Steam layouts (XKB layout/variant or Steam-native IME);
- the user's enabled layouts read from Steam's settings store;
- an exact `(layout, variant)` match against KDE's configured layouts;
- the user's own layout restored instead of `us`;
- physical long-press chords limited to grid-verified layouts.

### Third-party components

Decky Loader, SimpleDeckyTDP, LegionGoRemapper and InputPlumber are now integrated with pinned releases and source patches. See [THIRD_PARTY.md](THIRD_PARTY.md). acpi_call remains excluded (out-of-tree kernel module).
