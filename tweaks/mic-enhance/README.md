# Enhanced Internal Microphone

## Overview

**Reference Verified** (Lenovo Legion Go, SteamOS 3.9.5; default input in daily use) · portable by capability · user audio · no sudo · id `mic-enhance`

> A fuller, clearer internal microphone that does not clip on loud sounds.

## Problem

The internal microphone sounds thin and distorts easily at the default level.

## Enhancement

It adds an input called **"Enhanced Microphone"** and makes it the default:
1. Rumble filter.
2. Warmth and presence EQ.
3. A gentle compressor.
4. A safety limiter at −0.2 dBFS.

It uses only PipeWire's own filter-chain and the CAPS plugins that ship with SteamOS. The original microphone stays available.

## User benefit

Voice chat and calls without a headset sound better.

### Before vs After

| | Before | After |
|---|---|---|
| Voice | Thin, harsh peaks | Fuller, even level |
| Loud sounds | Can clip | Limited below 0 dBFS |

## Compatibility

Reference Verified on the Legion Go (1st gen) internal microphone, SteamOS 3.9.5. Other devices with exactly one internal analog microphone are compatible by capability, untested; the EQ was tuned for the Legion Go microphone. The installer detects the microphone's audio node.

### Dependencies

PipeWire `filter-chain.service` and CAPS LADSPA, both part of SteamOS. No sudo, no other tweak.

## Installation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" install mic-enhance
```

## Verification

Run `pactl get-default-source`; it prints `legiongo_mic_enhanced`. Then record a test clip:

```bash
pw-record --target legiongo_mic_enhanced test.wav
```

Press Ctrl+C to stop, then play `test.wav` back.

## Uninstallation

```bash
d=~/.local/share/legiongo-steamos/v0.2.5
{ [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.5 https://github.com/daineku/legiongosteamos.git "$d"; } &&
"$d/legiongo.sh" uninstall mic-enhance
```

This restores your previous default input and audio profile.

## Performance

| | Measured (reference device) |
|---|---|
| Idle | runs inside SteamOS's existing `filter-chain` service: 0.00 % CPU with the microphone idle, 11 MB RSS |
| While recording | a few biquad filters and one compressor per sample; not separately measured |

## Limitations

- Tuned by ear on the reference device; sound is a matter of taste.
- If your voice still distorts, lower the input level in System Settings → Sound.
- Apps that pick a specific device must be switched to "Enhanced Microphone" manually.

## Technical details

See [docs/technical/mic-enhance.md](../../docs/technical/mic-enhance.md).
