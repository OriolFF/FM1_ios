# FM Pocket — an iPad recreation of the M-VAVE FM-1

A native SwiftUI + AVAudioEngine iPad app that reproduces the M-VAVE FM-1 pocket FM synthesizer
(stock firmware V15 behaviour): the front panel, the 240×240 TFT screens, the control scheme and the
6-operator DX7-compatible engine, including the 128 factory voices.

## Build

```sh
brew install xcodegen          # once
xcodegen generate
open FM1.xcodeproj             # or:
xcodebuild -project FM1.xcodeproj -scheme FM1 -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```

iPadOS 18+, landscape only. To run on a device, set your signing team in Xcode.

## What's inside

| Area | Files |
|---|---|
| 6-op FM engine (MSFA-style envelopes/levels/scaling, 32 algorithms, LFO, pitch EG, mono/glide, global ADSR, op mute) | `FM1/Engine/FMEngine.swift`, `Algorithms.swift` |
| DX7 voice format + SysEx (32-voice bank / single voice import, bank export) | `FM1/Engine/FMPatch.swift` |
| Effect chain: Filter, Reverb, Delay, Distortion, Chorus, Phaser (re-orderable, per preset) | `FM1/Engine/FXChain.swift` |
| Arpeggiator (7 modes) + 16×16-step sequencer (step record, long notes, chain, per-step rate) | `FM1/Engine/ArpSeq.swift` |
| AVAudioEngine host, CoreMIDI / Bluetooth MIDI (notes, PC, bend, CC1/64, FX CC0–23 on the effect channel, SysEx) | `FM1/Engine/AudioController.swift` |
| Panel UI state machine (modes, pages, popups, LEDs, dialogs, persistence) | `FM1/App/SynthModel.swift` |
| Panel, knobs, rubber buttons, silicone keys, TFT screen renderer | `FM1/UI/*` |

Factory voices: `FM1/Resources/Banks/*.syx` (V15 factory banks A–D, extracted from M-VAVE's
Apache-2.0 recovery image in github.com/m-vave/fm1_open).

Research notes and reference photos used for the recreation are in `research/`.

## Controls (same as the hardware)

* **MASTER** volume · **SELECT** pages / cursor / confirm · **PRESETS** 001–128 · **ALGORITHM** 1–32
  (hold OCT− / OCT+ and turn = transpose) · **KNOB1–4** = the four on-screen tiles.
* **OCT− / OCT+** octave −3…+3 (both = reset). LEDs blink slow/fast/solid for ±1/±2/±3.
* **FX** chain page (SELECT cursor, SEL grab + SELECT reorder, K1–K3 params, K4 on/off) · **ENV** global ADSR ·
  **LFO** · **EDIT** operator editor (black keys: OP1–OP6, PIT, GLO, MONO, POLY; hold OP = mute) · **GLO** globals.
* **HOME** oscilloscope (hold = Bluetooth MIDI) · **SAVE** hold to store · **ARP** · **SEQ** · **PLAY/STOP**
  (hold = panic) · **REC** step recording (hold REC + SELECT moves the step cursor; hold a chord + SELECT = long note).
* Toolbar: colourways, SysEx import/export, Bluetooth MIDI.

Knobs: drag up/right to turn clockwise.

This is an unofficial fan recreation; it uses no M-VAVE logos or artwork.
