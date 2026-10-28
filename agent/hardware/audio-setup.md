---
name: audio-setup
description: "Laptop audio on Omarchy — EasyEffects per-output presets, WirePlumber output priority (BT > wired > speakers), why the filter-chain EQ was dropped (2026-10-21)"
metadata:
  node_type: memory
  type: project
  originSessionId: 091ba320-5412-40bc-944a-69eff2850544
  modified: 2026-10-21T04:28:40.931Z
---

Hardware: Realtek ALC256 via Intel SOF, with 2.0 speakers and no smart amp or hidden bass pair. Speakers and headphones are **separate card profiles**, so plugging in headphones removes the speaker sink. PipeWire 1.6.9, WirePlumber 0.5.18.

**Sound processing: EasyEffects 8.3** (with lsp-plugins-lv2 and calf)
- The speakers autoload the JackHack96 preset **Advanced Auto Gain**, via `~/.local/share/easyeffects/autoload/output/<speaker node.name>:Speaker.json`.
- Every other output falls back to the empty preset **Flat**. The settings `outputAutoloadingUsesFallback` and `outputAutoloadingFallbackPreset` are in `[Window]` of `~/.config/easyeffects/db/easyeffectsrc`.
- Autoload files are named `<node.name>:<route description>.json`.
- Autostart: `~/.config/autostart/easyeffects-service.desktop` with `--service-mode --hide-window`. EE 8 still shows its window if given only `--service-mode`.
- EE follows the default sink, so the priority rules below still decide the output.

**Output priority**
- `~/.config/wireplumber/wireplumber.conf.d/60-output-priority.conf` sets bluez_output 3000, `*Headphones__sink` 2000, raw Speaker 1000 and HDMI/USB 50. It disables `hooks.default-nodes.state`, since past picks would otherwise outrank priority.
- `~/.local/share/wireplumber/scripts/output-priority-reset.lua` (marked `optional`) clears `default.configured.audio.sink` whenever a new sink appears. Manual picks therefore hold only until a device connects.
- The mic default is unaffected; Mic1 is the internal digital mic.
- BT and wired auto-switching were not yet tested on real hardware as of 2026-10-21.

**Why:** the user found my PipeWire filter-chain EQ (hosted in Omarchy's speaker-tuning slot) sounded bad and asked for EasyEffects + Advanced Auto Gain. Omarchy speaker tuning is now OFF, because it conflicts with EE. The old EQ is kept at `~/.config/pipewire/swiftgo-speaker-eq.conf.keep`.
**How to apply:** for sound changes, use EasyEffects presets and ask the user to listen. I can't judge tuning by ear, so treat my EQ values as unverified. Related: [[system-omarchy]].
