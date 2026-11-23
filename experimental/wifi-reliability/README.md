# Wi-Fi reliability (experimental research, not an installable tweak)

**Status: EXPERIMENTAL — evidence collection only. Nothing here changes your system.**

## Why this is not a tweak (yet)

On the reference Legion Go, Wi-Fi reconnects noticeably faster after sleep than it used to, and long interruptions became rarer. The owner observed this in daily use, and the journal agrees:

| | Resume → Wi-Fi connected |
|---|---|
| Before (one recorded resume, 2026-11-13) | 19.8 s |
| After (22 resumes, 2026-11-15 … 2026-11-23) | median **1.5 s**, p90 19.6 s, max 75.7 s |

The change that was made at that time, a static regulatory country via `options cfg80211 ieee80211_regdom=XX` in `/etc/modprobe.d/`, **never took effect**:
- the kernel's global regulatory domain stays `00` (world);
- every regulatory change in the journal is a `BEACON_HINT`;
- no change of type USER or COUNTRY appears.

So it cannot be the cause, and it is not shipped as a fix.

The most likely explanation is SteamOS itself. SteamOS 3.9.5's release notes include "Enhanced wpa_supplicant to support fast WiFi reconnect on resume from sleep", with `wpa_supplicant` as the default backend. That is plausible, but **unproven**: there is only one baseline sample, and the network environment differed (phone hotspot vs. home router).

| Category | Finding |
|---|---|
| A. Proven configuration changes | static-country modprobe option (present, but not applied by the kernel) |
| B. User-observed improvements | faster reconnect after sleep, fewer long interruptions |
| C. Measured | resume → connected: median 1.5 s over 22 resumes (no comparable baseline) |
| D. Unconfirmed causal explanations | SteamOS 3.9.5 fast-reconnect support in wpa_supplicant |
| E. Ineffective changes | the static regulatory country (`iw reg get` → `00`) |

## Help collect evidence

```bash
experimental/wifi-reliability/wifi-report.sh          # this boot
experimental/wifi-reliability/wifi-report.sh --all    # every boot in the journal
```

It is read-only and prints no network names or addresses. If you can compare SteamOS versions, or Wi-Fi power-save on/off, on the same network, please open an issue with the output.

## What would make this a tweak

A change that measurably shortens reconnects, or reduces drops, on the same network, can be applied without touching regulatory settings, and can be reverted. Candidates to measure next:
- Wi-Fi power saving: SteamOS sets `wifi.powersave=3`; Steam's "Wi-Fi power management" toggle changes it;
- the `iwd` backend vs `wpa_supplicant`.

## If you applied the static-country option yourself

It is harmless but does nothing on this kernel. Remove it with:

```bash
sudo rm /etc/modprobe.d/legion-wifi-regdom.conf   # then reboot
```
