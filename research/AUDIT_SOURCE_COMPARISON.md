# Source comparison audit: findings

Date: 2026-11-10. Scope: the whole app, compared against

- **M-VAVE `fm1_open`** (github.com/m-vave/fm1_open, commit `4c7496d`): the DX7 engine in `web/synth/` (`dx7synth.c`, `dx7note.c`, `dx7env.c`, `dx7pitchenv.c`, `dx7lfo.c`, `dx7core.c`, `dx7math.c`, `adsr.c`), the voice unpacker in `app/fm_library.c`, and the page table in `app/screen.c`.
- `research/FUNCTION_SPEC.md` and `research/VISUAL_SPEC.md`.
- The hardware photos in `research/images/`.

Changes are in the working tree and are not committed.

---

## 1. How the sound was verified

M-VAVE's C engine could not be compiled and run locally (executing the downloaded code was blocked). Instead:

1. The reference voice was transcribed into a Python model by reading the C source (single note: note init, envelopes, pitch EG, LFO, operator core including the algorithm 4/6 feedback chains, ADSR, DC blocker).
2. Every factory voice was rendered through that model and through the app's Swift engine at 44.1 kHz, with varied notes (36–84), velocities (40/100/127), a key release, and ADSR enabled on every eighth voice.

| Measure | Result |
|---|---|
| Voices compared | 128 |
| Median level difference (per 2048-sample block) | 0.003 dB |
| Median sample error relative to signal | −49.5 dB |
| Voices with a level difference above 0.5 dB | 1 (D02 BDWHOCARES, 0.61 dB) |

A few noisy or high-feedback voices (BDWHOCARES, BRUSHES, SYN LEAD 7) match in level but not sample for sample. They are chaotic, so one-LSB frequency rounding differences diverge.

**Limit of this check:** the Python model is my own reading of the C. A misreading shared by the model and the Swift port would not show up. A direct render from the compiled C engine would close that gap.

Further checks:

- **Algorithms:** all 32 routings (modulators, carriers, feedback source and destination) decoded from the `dx7core.c` flag table and compared with `Algorithms.swift`: 0 mismatches.
- **Factory banks:** the bundled `.syx` files are identical to the research copies, and the VMEM SHA-256 equals M-VAVE's (`ecad0b86…aad25`).
- **Sine tables:** the firmware's `dx7_sin_log_table` and `dx7_sin_exp_table` are reproduced exactly by `round(-log2(sin((i+0.5)·π/2/1024))·1024)` and `round((2^(i/1024)−1)·4096)`. The app generates them from these formulas.
- **Voice lifetime:** 8 s after releasing a chord, 61 factory voices still have live voices. The same 61 are predicted from the reference envelopes (47 with a release slower than 8 s, 14 with a non-zero L4 that sustains, as on a DX7).
- **Smoke test:** all 128 voices, mono legato and fall-back, sustain pedal, 30 keys down (12 voices), ADSR, arpeggiator and controllers: no non-finite samples.
- **Build and tests:** simulator build succeeds; `FirmwareMenuTests` passes.

---

## 2. Sound: mismatches found and fixed

| # | Finding | Reference | Fix |
|---|---|---|---|
| S1 | Velocity was passed to the engine unscaled, so every voice was louder and brighter than the hardware | `dx7synth_keydown`: `(vel*100)>>7` | Scaled in `startVoice` |
| S2 | Operators used a clean interpolated float sine with linear gain ramps | `mk_sin`: 4096-step log-sine + exponent tables, attenuation added in the log domain, gain ramped in the log domain, fresh notes fade in from silence | Integer kernel ported (`FMEngine.mkSin`, Q24 phase, Int32 buses) |
| S3 | Global ADSR used invented curves (cubic, up to 8 s, sustain 0–100 %) | `adsr.c`: attack `8·A` ms, decay `100+8·D` ms, release `100+19·R` ms, sustain `(100+7·S)/1000`, per-sample smoothing 0.5 / 0.35 / 0.125 | Ported; engine now takes the panel values 0–100 |
| S4 | A released voice was retired as soon as its carriers were silent, cutting voices whose release level rises again | `note_finished`: all six envelopes ended and below `100<<14` | Ported |
| S5 | Oscillator phase was only reset when Osc Key Sync was on | `dx7note_init` resets phase and gain on every note; mono hand-over keeps them | Ported |
| S6 | A stolen voice kept its envelope level | Envelope restarts from 0 | Ported |
| S7 | Mono mode: glide started from the current glide position, legato did not restart pitch EG or ADSR, releasing back to a held key glided | Glide from the previous note; legato keeps operator envelopes but restarts pitch EG, ADSR and LFO; fall-back has no glide | Ported |
| S8 | A note transposed outside 0–127 was clamped | The note is ignored | Ported |
| S9 | Algorithms 4 and 6: operators inside the feedback loop could drop out individually | Rendered as one chain whenever the feedback operator is audible | Ported |
| S10 | Envelope increment was truncated before scaling by the block size (up to ~5 % rate error at slow rates away from 44.1 kHz) | n/a (sample-rate adaptation) | Scaled after multiplying |
| S11 | **Filter cutoff was about one octave above the displayed value.** The filter ran two iterations per sample with a coefficient computed for one, and was capped near 11.5 kHz | Stock algorithm unpublished; spec recommends a TPT SVF | Replaced with a TPT SVF. Measured: 0.0 dB at the displayed cutoff with Q = 0, about −11 dB one octave above, stable to 20 kHz |

Already matching the reference before the audit: envelope rate/level tables and scaling, keyboard level and rate scaling, velocity table, output-level curve, detune formula, fixed-frequency mode, pitch EG tables, LFO speed formula, waveforms and delay, pitch and amplitude modulation sensitivity, feedback scaling (including the extra shift for algorithms 4, 6 and 32), DC blocker coefficient, and out-of-range factory values being clamped on import (e.g. BASS 4 PMD 127, SYN LEAD 6 detune 15).

---

## 3. Display and knobs: mismatches found and fixed

| # | Finding | Evidence | Fix |
|---|---|---|---|
| D1 | Header showed a number after the preset name (octave + 3) | `photo_screens_op_env_tuning_globe.jpg`: "128 WHAT IF" has nothing after it. The "3" in "001 PIANO 3" was part of an old preset name | Removed |
| D2 | Voice Transpose shown as −24…+24 | Same photo shows "Transpose 18"; WHAT IF stores 18 in the factory bank | Shows the stored 0–48 value |
| D3 | Operator pages in the pre-V15 order, plus a non-stock "Freq" tile | V15 manual (spec 4.1) and the `screen.c` page table | Now Tuning (Detune / FreqCoarse / FreqFine / OutLevel), Envelope, Env Level, Sens (AmpMod / Key Velo / OscMode), Scaling, Curves |
| D4 | FX tile read "Distort-/ion" | `photo_fx_page.jpg`: "Distort / ion", no hyphen | Hyphen removed |
| D5 | Rename forced lower-case letters to upper case, although the editor has an a–z class and the factory bank contains "Organ 2" | Spec 4.3 | Case kept |
| D6 | Copy Voice could not be left with K3 counter-clockwise | Spec 4.3 | Added |

Confirmed correct: Detune shown as −7…+7 (WHAT IF OP1 stores 8, photo shows 1), tile layout and K1–K4 mapping, footer format (`1/6 OP1 Tuning`, `1/2 Arpeggio`, `Freq: 30%`), FX grid and red cursor dot, algorithm diagram, key-to-note mapping, EDIT key labels, white-key step LEDs, octave LED blink rates, popups and refusal messages, LFO / PIT / GLO / ARP / SEQ page contents.

---

## 4. Other bugs fixed

| # | Finding | Fix |
|---|---|---|
| B1 | Arpeggiator: the first note waited for the free-running clock (up to one step late) | Clock restarts on the first key of a phrase |
| B2 | Arpeggiator: turning Latch off left the latched notes playing forever | Latched notes are dropped when Latch is off and no key is down |
| B3 | Arpeggiator: switching ARP back on replayed the previously latched chord | Held notes cleared on enable |
| B4 | A single-voice SysEx dump with out-of-range bytes could crash the Curves page (index past the curve names) | Dumps are clamped to DX7 ranges; the lookup is masked |
| B5 | Channel aftertouch, CC2 (breath), CC4 (foot) and CC121 were ignored | Added, routed as in `dx7synth.c` (aftertouch to pitch modulation, CC2/CC4 to amplitude modulation) |
| B6 | DX7 parameter-change SysEx (`F0 43 1n pp qq vv F7`), listed in the official MIDI guide, was ignored | Added; writes the edit buffer |
| B7 | Stale header comment in `FXChain.swift` described a fixed effect order | Corrected |

---

## 5. Open items (not changed)

1. **Operator page order is a judgement call.** The photos (a V14 unit) show Envelope first and Tuning third. The app targets V15, where the manual and M-VAVE's page table agree on the order now used. Page titles other than "Envelope" and "Tuning" are guesses.
2. **Effects other than the filter** are approximations: the stock reverb, delay, distortion, chorus and phaser algorithms are unpublished. The app's effects are stereo; the hardware is mono.
3. **Filter cutoff steps.** The hardware shows values such as 1004 Hz that the app's 100-step curve (`100·200^(v/100)`) does not land on. The real table is unknown.
4. **Not implemented:** MIDI out, external clock sync. The Sync tiles on the ARP and SEQ pages do nothing.
5. **PLAY/STOP LED colour.** The manual says green (play) and orange (stop); the photo notes say red. The app uses green and red.
6. **SEQ long notes.** The spec says existing notes are not overwritten when a long note is extended; the app clears the steps it ties over. The spec wording is ambiguous.
7. **Voice allocation order** differs from the firmware's rotating cursor (the app takes the lowest idle voice, then the oldest released). No audible difference expected.
8. **Sample rate.** The firmware runs at 44.1 kHz; the app runs at the device rate (usually 48 kHz) with envelope and LFO rates rescaled. The ADSR smoothing coefficients are per-sample and not rescaled.
9. **Groove firmware and drum kit** are original code with no source to compare against. They were read for obvious bugs only; none fixed.
10. **Stock firmware image** (`FM-1_015.fwsc`) is scrambled, so on-screen strings could only be checked against photos and the spec.
11. **Stock vs open firmware.** The engine comparison is against M-VAVE's open firmware source. That the stock V15 engine is identical is an assumption, supported by the shared lineage and by the spec's measured match to MSFA.

---

## 6. Files changed

| File | Change |
|---|---|
| `FM1/Engine/FMEngine.swift` | S1–S10, B5 |
| `FM1/Engine/FXChain.swift` | S11, B7 |
| `FM1/Engine/FMPatch.swift` | D5, B4, B6 (range table, `sanitize`, `setParameter`, `parseParameterChange`) |
| `FM1/Engine/AudioController.swift` | B5, B6 |
| `FM1/Engine/ArpSeq.swift` | B1–B3 |
| `FM1/App/SynthModel.swift` | D1–D3, D6, B3, B4, B6, ADSR values passed as 0–100 |
| `FM1/UI/ScreenView.swift` | D1, D4 |
| `README.md` | Engine and MIDI descriptions updated |
