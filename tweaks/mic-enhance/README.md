# Enhanced Internal Microphone

**Experimental** · user audio (Desktop and Gaming Mode) · no sudo · id `mic-enhance`

> A fuller, clearer internal microphone that does not clip on loud sounds.

## What It Does

It adds an input called **"Enhanced Microphone"** and makes it the default:
1. Rumble filter.
2. Warmth and presence EQ.
3. A gentle compressor.
4. A safety limiter at −0.2 dBFS.

It uses only PipeWire's own filter-chain and the CAPS plugins that ship with SteamOS. The original microphone stays available.

## Why You Need It

The internal microphone sounds thin and distorts easily at the default level.

## Before vs After

| | Before | After |
|---|---|---|
| Voice | Thin, harsh peaks | Fuller, even level |
| Loud sounds | Can clip | Limited below 0 dBFS |

## How It Improves Legion Go

Voice chat and calls without a headset sound better.

## Install — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" install mic-enhance
```

## Uninstall — One Command

```bash
d=~/.local/share/legiongo-steamos/v0.2.1; { [ -d "$d" ] || git -c advice.detachedHead=false clone -q --depth 1 -b v0.2.1 https://github.com/daineku/legiongosteamos.git "$d"; } && "$d/legiongo.sh" uninstall mic-enhance
```

This restores your previous default input and audio profile.

## How to Check It Works

Run `pactl get-default-source`; it prints `legiongo_mic_enhanced`. Then record a test clip:

```bash
pw-record --target legiongo_mic_enhanced test.wav
```

Press Ctrl+C to stop, then play `test.wav` back.

## Dependencies

PipeWire `filter-chain.service` and CAPS LADSPA, both part of SteamOS. No sudo, no other tweak.

## Compatibility

Legion Go (1st gen) internal microphone, SteamOS 3.9.5. The installer detects the microphone's audio node on your device. It was validated in isolated test installs.

## Known Limitations

- **Experimental:** tuned by ear on one device; sound is a matter of taste.
- If your voice still distorts, lower the input level in System Settings → Sound.
- Apps that pick a specific device must be switched to "Enhanced Microphone" manually.

Technical details: [docs/technical/mic-enhance.md](../../docs/technical/mic-enhance.md)
