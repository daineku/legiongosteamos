# Enhanced Internal Microphone: technical details


- `~/.config/pipewire/filter-chain.conf.d/60-legiongo-mic-enhance.conf`: the `libpipewire-module-filter-chain` graph.
  - Builtin biquads (`bq_highpass`, `bq_lowshelf`, `bq_peaking`) feed `caps.so` `Compress` (measure RMS, mode 2, threshold 0.3, strength 0.6, attack 0.05, release 0.4), then the builtin `clamp` (±0.977).
  - Capture `target.object` is the internal ALSA input node. The installer detects it, because SteamOS hides it behind a loopback device.
  - Output: mono `Audio/Source` `legiongo_mic_enhanced`.
- It runs inside the existing user `filter-chain.service`, separate from the main PipeWire process, so a restart does not interrupt playback.
- Default source: `pactl set-default-source`, which is stored by WirePlumber.
