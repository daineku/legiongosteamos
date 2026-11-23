# Third-party components

The Legion Go experience on the reference device depends on several community projects. This page records, for each one, what it is, why the Legion Go needs it, exactly what this project changes, and how it is installed, updated and rolled back.

General rules:
- Upstream releases are **pinned** (version + SHA-256 of the official asset).
- Our changes are **visible source patches or configuration files** in this repository, never opaque binaries.
- A newer upstream release is **never** installed or declared compatible automatically. A weekly GitHub Actions job opens a review issue instead (see [MAINTAINING.md](MAINTAINING.md)).

| Component | Version pinned | Integration | Tweak |
|---|---|---|---|
| InputPlumber | v0.84.0 (`117cb04e`) | B pinned release + D source patches (+ published reproducible builds) | `precision-touchpad`, needed by `desktop-touchpad` |
| Decky Loader | v3.3.1 (`ffd103b9`) | A managed by our installer + B pinned release | `decky-loader` |
| SimpleDeckyTDP | v1.0.7 (`7172b499`) | B pinned release + C settings overlay | `decky-power-plugins` |
| LegionGoRemapper | v0.3.0 (`6ea20449`) | B pinned release + C settings overlay + D safety patch | `decky-power-plugins` |
| CAPS LADSPA plugins | SteamOS package `caps` 0.9.26 | F uses the SteamOS package as is | `mic-enhance` |
| Steam client (on-screen keyboard) | user's installed client | runtime script, nothing redistributed | `steam-keyboard` |
| acpi_call kernel module | — | not integrated (see the end of this page) | — |

---

## InputPlumber

| | |
|---|---|
| Project | InputPlumber, https://github.com/ShadowBlip/InputPlumber |
| Maintainer | ShadowBlip (the OpenGamepadUI / ChimeraOS developers) |
| License | GPL-3.0 |
| SteamOS ships | 0.78.0 (SteamOS 3.9.5) |
| We use | v0.84.0, source tag commit `117cb04e949f842397b96178bcc0d7fc7ba23acf`; release archive `inputplumber-x86_64.tar.gz` sha256 `1626fb22…2457a`; release binary sha256 `b3e6cc3e…cd87ad` |
| What it does | It reads the Legion Go controllers and touchpad and presents them as one virtual controller (a Steam Deck "deck-uhid" device) that Steam Input understands. |
| Why the Legion Go needs it | Without it, Steam does not see the detachable controllers as one controller. SteamOS uses it by default on the Legion Go. |
| Problem we solve | 0.78 takes touchpad positions from the gamepad report at about 42 Hz. Upstream 0.79.2+ reads the touchpad interface natively at about 106 Hz (PR #702). Tapping also moved the cursor before the click (finger roll-off), because the driver forwards every frame and decides "tap" only at lift-off. |
| Our changes | `tweaks/precision-touchpad/patches/legion-touchpad-{glide,tapfilter}.patch`, touching only `src/drivers/legion_go/{mod.rs,go_touchpad_driver.rs}`. Both reject frames outside the HID range (X/Y > 1024), set a 300 ms tap timeout, and add a lift-off filter: slow frames are held briefly and dropped if the finger lifts. `tapfilter` holds for 24 ms; `glide` uses a 200 ms tap window, then live movement with a gliding hold. |
| Improvement (measured on the reference device) | Rate 42 → 106 Hz (all variants). Taps shifting the cursor ≥ 5 px: 36 % → 7 % with `tapfilter`; `glide` stayed at 35 % but feels smoother (it is the owner's daily choice). |
| Difference from upstream | Only the two patches. Device profiles and capability maps are upstream's, unmodified. |
| Binary provenance | `build/build-patched.sh <variant>` (podman, `rust:1.92`, the toolchain from upstream's Dockerfile, `cargo build --release --locked`) rebuilds **bit-identical** binaries: glide `2fed277f…6fc9`, tapfilter `9f3d5c1b…67cd1`. These are published as assets of the release `inputplumber-0.84.0-patches-1`; the installer accepts only these checksums. GPL source: upstream tag + the patches in this repository. |
| Compatibility requirements | Legion Go 1st gen (USB PIDs 6182–6185, 61eb–61ee); `inputplumber.service`; stock InputPlumber not newer than 0.84.0 (otherwise installing would be a downgrade and is refused until the patches are rebased). |
| Install / update | `legiongo.sh install precision-touchpad` (`LG_IP_VARIANT=glide|tapfilter|release`), `legiongo.sh update precision-touchpad`. |
| Rollback | `legiongo.sh uninstall precision-touchpad`: the drop-in and our copy are removed and the stock service restarts. Emergency: delete `/etc/systemd/system/inputplumber.service.d/50-legiongo-steamos-inputplumber.conf` and restart `inputplumber`. |
| Resume / controller fixes | None claimed. A post-resume erratic cursor period was observed and not root-caused. |

## Decky Loader

| | |
|---|---|
| Project | Decky Loader, https://github.com/SteamDeckHomebrew/decky-loader |
| Maintainer | SteamDeckHomebrew team |
| License | GPL-2.0 |
| We use | v3.3.1 (`ffd103b9`), asset `PluginLoader` sha256 `7bb73b05…0c315` (the reference device's binary is identical) |
| What it does | A root service that injects a plugin menu into the Steam client (Quick Access menu) and runs plugin back-ends. |
| Why the Legion Go needs it | Legion Go-specific controls (TDP per game, fans, RGB, remapping, charge limit) are only available as Decky plugins. |
| Gaming vs Desktop Mode | Plugins are meant for Gaming Mode. Decky also loads them into the desktop Steam client. `desktop-power-policy` unloads the power plugins' frontends there so that only one tool manages power. |
| Our changes | None to Decky itself. We install the pinned release the same way Decky's installer does (`~/homebrew/{services,plugins,settings,data,logs}`, `/etc/systemd/system/plugin_loader.service`, Steam debugger flag) instead of running its unpinned `curl | sh` script. |
| Steam debugger flag | `~/.local/share/Steam/.cef-enable-remote-debugging` is shared with `steam-keyboard`. Ownership is reference counted in `~/.local/state/legiongo-steamos/.shared/`. |
| Known issues | A Steam client update can break Decky or a plugin until upstream catches up. Decky's own updater can move past the pinned version; this project then reports the files as changed. |
| Recovery after a Steam update | 1. `sudo systemctl restart plugin_loader`. 2. If the menu is still missing, check https://github.com/SteamDeckHomebrew/decky-loader/releases for a fix and open an issue here. 3. As a last resort, `legiongo.sh uninstall decky-power-plugins` and then `decky-loader`. Steam itself is never modified, so removing Decky always returns a working stock client. |
| Install / update / rollback | `legiongo.sh install decky-loader`; `update decky-loader`; `uninstall decky-loader` (refused while `decky-power-plugins` is installed). |

## SimpleDeckyTDP

| | |
|---|---|
| Project | SimpleDeckyTDP, https://github.com/aarron-lee/SimpleDeckyTDP |
| Maintainer | Aarron Lee |
| License | BSD-3-Clause (LICENSE file in the release; GitHub shows NOASSERTION) |
| We use | v1.0.7 (`7172b499`), asset `SimpleDeckyTDP.zip` sha256 `dae7cf43…0ad38` |
| What it does | Per-game TDP, CPU boost, SMT, EPP and GPU mode in Gaming Mode. On the Legion Go it uses the Lenovo firmware interfaces. |
| Why the Legion Go needs it | SteamOS's own TDP slider is generic. Lenovo's firmware profiles and custom TDP are not exposed. |
| Our changes | A settings overlay, `tweaks/decky-power-plugins/files/SimpleDeckyTDP-settings.json`, written only if no settings exist: boost on, SMT on, EPP `balance_performance`, 25 W default, `supportsRyzenadjCoall: false`. |
| Improvement | Upstream's first start disables CPU boost and sets EPP balance_power, and runs a one-time `ryzenadj --set-coall` SMU write. Ours starts with full performance and no SMU write. Read back on the reference device after the first apply. |
| Difference from upstream | Only the starting settings. Code unmodified. |
| Requirements | Decky Loader; Steam's own TDP limit **off** in Gaming Mode. |
| Update | Pinned. The plugin's OTA updater downloads without checksum verification; prefer `legiongo.sh update decky-power-plugins` after we pin a reviewed version. |
| Rollback | `legiongo.sh uninstall decky-power-plugins`. |

## LegionGoRemapper

| | |
|---|---|
| Project | LegionGoRemapper, https://github.com/aarron-lee/LegionGoRemapper |
| Maintainer | Aarron Lee |
| License | BSD-3-Clause (patch redistribution permitted; notice kept in the patch header) |
| We use | v0.3.0 (`6ea20449`), asset `LegionGoRemapper.tar.gz` sha256 `b89084ec…6d9e1` |
| What it does | Legion Go back-button remapping, RGB, custom fan curves, charge limit, and touchpad toggle via Lenovo's HID/WMI interfaces. |
| Our changes | `tweaks/decky-power-plugins/patches/LegionGoRemapper-v0.3.0-safety.patch` and a settings overlay with every feature off. |
| What the patch fixes | 1. `sync_touchpad`: a missing setting sent *touchpad OFF*; now it defaults to on. 2. `sync_rgb_settings`: loading switched the LEDs off unless RGB control was enabled; now it is a no-op. 3. `save_fan_settings`: the curve is built in fixed 10…100 °C order without mutating the stored profile, points are validated 0…115, a floor of 70/80/95/100 % applies at 70/80/90/100 °C, firmware cooling is restored on error, and a logger crash is fixed. 4. `_unload`: restores firmware cooling if a custom curve was active. |
| Not installed | The project's optional udev rule (`ATTRS{idVendor}=="17ef", MODE="0666"`), which makes every Lenovo USB device world-writable. The root back-end does not need it. |
| Reproducibility | The patched release is byte-identical to the plugin running on the reference device. |
| Verification | Touchpad and LED state unchanged after load (reference device). Remapping, fan curves and charge limit **not tested**. |
| Requirements | Fan and charge features need the `acpi_call` kernel module (not provided, see below). |
| Rollback | `legiongo.sh uninstall decky-power-plugins`. |

## CAPS LADSPA plugins

The SteamOS package `caps` (0.9.26, GPL-3.0 by Tim Goetze). `mic-enhance` uses its `Compress` plugin unmodified through PipeWire's filter-chain. Nothing is redistributed.

## Steam client

The `steam-keyboard` tweak modifies the running Steam client's keyboard UI at runtime through Steam's local debugger. No Steam file is changed or redistributed. Restarting Steam without the tweak gives the stock keyboard back.

## Not integrated

| Component | Reason | What would make it distributable |
|---|---|---|
| `acpi_call` kernel module (nix-community/acpi_call, GPL) | Out-of-tree module: it must be compiled for every SteamOS kernel, taints the kernel, and is unsigned. Only LegionGoRemapper's fan and charge features need it. | A build script that compiles against the exact `linux-neptune` headers package in a container, with a version-locked install that skips safely after kernel updates. It exists privately on the reference device but has had no review outside it. |
