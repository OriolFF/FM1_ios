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

## Firmware menu

Toolbar **Firmware** chip (or ⋯ → Firmware… in full-screen mode) lists the ported firmwares, like the
hardware updater: **FM-1 Stock V15** (original — always available to restore) and **FM Pocket Groove G1.0**.
Installing shows a flashing progress screen on the TFT and reboots the panel; presets, patterns and globals
are kept. Add new ports in `FM1/App/Firmware.swift`.

## Groove firmware (groovebox)

Install **FM Pocket Groove** from the Firmware menu. Inspired by the community FM-1 firmwares
(Felucca / SLOOP / FM-1+VA / FM1 Open — see `research/FIRMWARE_*_SEQ.md`):

* 8 patterns, each with an FM **synth track** (chords, tie, gate, chance/FILL conditions, ratchet ×1–4,
  up to 4 parameter locks per step) and an **11-lane 808-style drum track** (`DrumKit.swift`), per-track length 1–64 (polymeter), swing.
* SEQ page: white keys = steps (OCT± pages), black keys = drum lanes, SEL = track, hold step + knobs = step edit.
* Pages: Pattern · Euclid generator · Kit (level/tune/decay/tone) · Tools (clear, copy, density fill).
* Hold GLO = perform layer (mute/solo/fill/tap tempo). REC records the synth track live or step-by-step.

## Controls (same as the hardware)

* **MASTER** volume · **SELECT** pages / cursor / confirm · **PRESETS** 001–128 · **ALGORITHM** 1–32
  (hold OCT− / OCT+ and turn = transpose) · **KNOB1–4** = the four on-screen tiles.
* **OCT− / OCT+** octave −3…+3 (both = reset). LEDs blink slow/fast/solid for ±1/±2/±3.
* **FX** chain page (SELECT cursor, SEL grab + SELECT reorder, K1–K3 params, K4 on/off) · **ENV** global ADSR ·
  **LFO** · **EDIT** operator editor (black keys: OP1–OP6, PIT, GLO, MONO, POLY; hold OP = mute) · **GLO** globals.
* **HOME** oscilloscope (hold = Bluetooth MIDI) · **SAVE** hold to store · **ARP** · **SEQ** · **PLAY/STOP**
  (hold = panic) · **REC** step recording (hold REC + SELECT moves the step cursor; hold a chord + SELECT = long note).
* Toolbar: colourways, full-screen mode, SysEx import/export, Bluetooth MIDI.
* **Full-screen mode** (toolbar ⤢ button): drops the case and stretches the panel to the whole iPad
  screen (taller keys, bigger display). The ⋯ button in the top-right corner switches back.

Knobs: drag up/right to turn clockwise.

This is an unofficial fan recreation; it uses no M-VAVE logos or artwork.
