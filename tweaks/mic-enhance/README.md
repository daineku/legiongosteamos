# Enhanced Internal Microphone

**Status: Experimental** · user audio (Desktop and Gaming Mode) · no sudo · tweak id `mic-enhance`

## What This Tweak Does

It adds a virtual input called **"Enhanced Microphone"**, built with PipeWire's own filter-chain, and makes it the default input. The internal microphone's signal passes through:

1. High-pass at 85 Hz (removes rumble and handling noise).
2. Low shelf +3 dB at 180 Hz (warmth).
3. Peak −2.5 dB at 400 Hz (less "boxy" sound).
4. Peak +2 dB at 3.5 kHz (presence, intelligibility).
5. A soft RMS compressor (CAPS `Compress`, +4 dB makeup).
6. A safety clamp at −0.2 dBFS against clipping.

If the audio card profile has no microphone input, it switches the card to the duplex profile (speakers + microphone).

## Why You Need It

On the reference device the internal microphone sounded thin and distorted easily at the default gain. It also only worked with the duplex audio profile.

## What Improves

Fuller, more even voice pickup, without hard clipping on loud sounds. The original microphone stays available, so any app can still select it.

## Before vs After

BEFORE: the raw internal microphone, thin, with distortion at high levels.

AFTER: the "Enhanced Microphone" input, EQ'd and compressed, with peaks clamped below 0 dBFS.

## Requirements

- Lenovo Legion Go (1st gen) internal microphone (Realtek codec on the Ryzen HD Audio controller), SteamOS 3.9.5 (tested).
- PipeWire `filter-chain.service` and the CAPS LADSPA plugins. Both ship with SteamOS.
- No sudo.

## Installation

```bash
./legiongo.sh install mic-enhance
```

## Verification

1. Run `./legiongo.sh status mic-enhance`. It should report `installed`.
2. Run `pactl get-default-source`. It should print `legiongo_mic_enhanced`.
3. Record a short clip, for example with `pw-record --target legiongo_mic_enhanced test.wav` (Ctrl+C to stop), and play it back.

## Uninstallation

```bash
./legiongo.sh uninstall mic-enhance
```

This removes the filter, and restores the previous default input and audio profile (if this tweak changed them).

## Known Limitations

- **Experimental:** the sound is a matter of taste. It was tuned by ear on one device, and the owner never formally confirmed it as final.
- If your voice is still distorted, lower the microphone level in System Settings → Sound. The reference device uses a low hardware input level (around 30 %).
- Apps that pick a specific device instead of the system default must be switched to "Enhanced Microphone" manually.
- Restarting `filter-chain.service` briefly interrupts recording.

## Technical Details

- `~/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf`: the `libpipewire-module-filter-chain` graph.
  - Builtin biquads (`bq_highpass`, `bq_lowshelf`, `bq_peaking`) feed `caps.so` `Compress` (measure RMS, mode 2, threshold 0.3, strength 0.6, attack 0.05, release 0.4), then the builtin `clamp` (±0.977).
  - Capture `target.object` is the internal ALSA input node. The installer detects it, because SteamOS hides it behind a loopback device.
  - Output: mono `Audio/Source` `legiongo_mic_enhanced`.
- It runs inside the existing user `filter-chain.service`, separate from the main PipeWire process, so a restart does not interrupt playback.
- Default source: `pactl set-default-source`, which is stored by WirePlumber.
