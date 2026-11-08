# M-VAVE FM-1: Functional Specification for the iPad Recreation

Research date: 2026-11-08. Target: the **stock M-VAVE firmware**, mainly **V15** (single-timbral, 12 voices), which is what the printed manual and most reviews describe. **V16** (multitimbral) changes are listed separately in section 11 so you can choose a target.

**Evidence tags**
- **[C]** Confirmed by a primary source: the official manual, official release notes, the official MIDI guide, or M-VAVE's own source repo. The source ID is in brackets, e.g. [C:S2].
- **[C3]** Confirmed by a reliable third-party source that measured or reverse-engineered the hardware.
- **[I]** Inferred. These are my reasoning or a best guess and should be verified on hardware.

Source list: see section 14 (S1–S16).

**Companion files in this folder (generated from M-VAVE's Apache-2.0 recovery image, see section 9)**
- `FM1_V15_factory_bank_A.syx` … `_D.syx`: the four standard DX7 32-voice bulk dumps, 4104 bytes each, holding the exact 128 factory voices in factory order.

---

## 1. Hardware overview

| Item | Value | Tag |
|---|---|---|
| Synthesis | 6-operator FM, 32 DX7 algorithms, DX7 voice format | [C:S1,S2,S6] |
| Engine code | C port of Google MSFA / Dexed msfa (algorithms, envelopes, LFO, note scaling) in fixed-point, by M-VAVE | [C:S7 THIRD_PARTY.md] |
| SoC | JieLi AC791N (PI32v2 CPU), running FreeRTOS | [C:S7, S15] |
| Sample rate | 44,100 Hz, processed in 128-frame blocks (FM1 SDK) | [C:S7 sdk/synth.json, fm1_block.h] |
| USB audio | 44.1 kHz, 16-bit; L = R (the engine and effects are mono) | [C3:S8] |
| Polyphony | 12 voices in POLY mode (V15); MONO mode is last-note priority | [C:S1,S2] |
| Presets | 128, numbered 001–128, in banks A–D of 32 voices each | [C:S1,S2,S7] |
| Display | 1.54" colour TFT, 240×240 px, RGB565 | size [C:S1]; resolution [C:S7 lcd.inc] |
| Encoders | 7 endless encoders (SELECT, PRESETS, ALGORITHM, K1–K4) plus 1 MASTER volume pot (300°) | [C:S1,S2,S7] |
| Buttons | 14: OCT−, OCT+, FX, SEL, ENV, LFO, EDIT, GLO, HOME, SAVE, ARP, SEQ, PLAY/STOP, REC | [C:S1,S7 screen.c enum] |
| Keyboard | 27 silicone keys with one LED per key, F3–G5 at octave 0. The keys are plain switches with no velocity sensing | keys [C:S1]; no velocity sensing [I] (open-firmware key scan is on/off debounce only; V13 added a fixed "Global Velocity 1–127") |
| I/O | 3.5 mm TRS stereo out (carries the mono signal), 3.5 mm TRS MIDI IN (Type A), USB-C (MIDI, audio, power, updates), BLE MIDI, built-in speaker (muted when headphones are plugged in) | [C:S1,S2,S10] |
| MIDI out | USB and BLE only. There is no DIN/TRS MIDI out | [C:S1,S7 README] |
| Battery | 2000 mAh, about 12 h; on-screen battery icon; LOW BATTERY full-screen overlay | [C:S1] |

---

## 2. Panel layout and controls

Physical arrangement [C:S1/S2 section headings]:
- **Left panel:** MASTER pot, SELECT encoder, PRESETS encoder, ALGORITHM encoder, OCT− and OCT+ buttons (each with an LED).
- **Centre:** the TFT.
- **Right panel:** K1–K4 encoders, a top row of buttons (FX, SEL, ENV, LFO, EDIT, GLO), and a bottom row of buttons (HOME, SAVE, ARP, SEQ, PLAY/STOP, REC).
- **Bottom:** the 27-key keyboard.

The exact left-to-right button order within each row follows the manual's listing order and the firmware enum. **[I]** for the physical positions.

### 2.1 Encoders

| Control | Normal function | Modified function | Tag |
|---|---|---|---|
| **MASTER** (pot) | Output volume; shows a "Volume X" popup | none | [C:S1] |
| **SELECT** | Changes the page within the current mode (CW = next page, CCW = previous). The bottom bar shows e.g. `1/2 Arpeggio` | In FX mode it moves the cursor across the 6 effect slots. With an effect grabbed (SEL), it moves that effect in the chain. In SEQ record it moves the step cursor (see 6.2). In dialogs it confirms (rename, copy, reset) | [C:S1,S2] |
| **PRESETS** | Steps through presets 001–128 with wrap-around. Each detent **loads the preset immediately**. A list popup shows number, name and highlight for about 1 s. The top bar always shows the loaded `NNN NAME` | Inactive while SEQ is on, because the voice comes from the pattern's Voice parameter (V15) | [C:S1,S2] |
| **ALGORITHM** | Selects algorithm 01–32 for the current voice; shows an algorithm-diagram popup (carriers, modulators, feedback loop) for about 1 s | **Hold OCT− and turn:** transpose 0 to −12. **Hold OCT+ and turn:** transpose 0 to +12. Shows "Transpose XX". Global (not per voice), auto-saved to global settings | [C:S1,S2] |
| **K1–K4** | Context parameters; the bottom bar names the parameter and shows its value | see section 4 | [C:S1] |

### 2.2 Buttons

| Button | Short press | Long press / combo | Tag |
|---|---|---|---|
| **OCT− / OCT+** | Octave shift of −3…+3, one octave per press; "Octave X" popup | **OCT− and OCT+ together** reset octave and transpose to 0. Hold either one and turn ALGORITHM for transpose | [C:S1] |
| Octave LEDs | 0: both off. ±1: slow blink. ±2: fast blink. ±3: solid. The lit LED is on the side of the shift's sign | none | [C:S1] |
| **FX** | Enter or exit the Effect Chain page | none | [C:S1] |
| **SEL** | FX page only. Grab or release the highlighted effect (SEL LED lights; the slot's dot goes from blinking to solid); turn SELECT to swap it with neighbours | V16: hold SEL on the FX page to rename the FX group | [C:S1,S5] |
| **ENV** | V09+: toggles the global ADSR amp envelope **on** (LED lit) and opens its page; press again to turn it **off**. It is off by default | none | [C:S2,S3] |
| **LFO** | Enter or exit the LFO pages | none | [C:S1] |
| **EDIT** | Enter or exit the operator editor; the keyboard's black keys become section selectors (2.3) | none | [C:S1] |
| **GLO** | Enter or exit global settings | none | [C:S1] |
| **HOME** | Return to the home (oscilloscope) screen from anywhere | **Long press** toggles Bluetooth. LED blinking = BT on but not connected; solid = connected; off = BT off | [C:S1] |
| **SAVE** | **Press and hold** to write all pending changes (voice, FX, SEQ patterns, globals) to flash. The LED is lit while saving; "Preset Saved" popup | V16: opens a menu ALL / Globe / Preset / Pattern | [C:S1,S5] |
| **ARP** | Toggle the arpeggiator (LED) and open its page. Refused with "Disable SEQ to enter" if SEQ is on | none | [C:S1] |
| **SEQ** | Toggle the sequencer (SEQ LED plus orange STOP LED) and open its page; the keys become step indicators. Refused with "Disable ARP to enter" if ARP is on | none | [C:S1,S2] |
| **PLAY/STOP** | SEQ only: start (green PLAY LED) or stop (orange STOP LED). "Enable SEQ first" otherwise | V16: hold = **Panic** (stops seq/arp, clears stuck notes) | [C:S2,S5] |
| **REC** | SEQ only: enter record (red REC LED) from stop or play; press again to leave record | **Hold REC and turn SELECT** while recording to move the step cursor (rests and replacement) | [C:S2] |

### 2.3 Keyboard and combo keys

- MIDI note = `keyIndex(0..26) + 53 + octave*12 + transpose`, so key 0 is F3 (53) and key 26 is G5 (79) at octave and transpose 0 [C:S1]. Overall reach is about 8 octaves [C:S6].
- Each key has an LED that lights while the key is held, or while the arp or sequencer plays it [C:S1].
- **EDIT-mode labels on the black keys** [C:S1 names; key positions from S7 `edit_keys = {1,3,5,8,10,13,15,17,20,22}`]:

| Key index | Note at oct 0 | EDIT label |
|---|---|---|
| 1 | F#3 | OP1 |
| 3 | G#3 | OP2 |
| 5 | A#3 | OP3 |
| 8 | C#4 | OP4 |
| 10 | D#4 | OP5 |
| 13 | F#4 | OP6 |
| 15 | G#4 | PIT (pitch EG) |
| 17 | A#4 | GLO (voice common) |
| 20 | C#5 | MONO |
| 22 | D#5 | POLY |

  Key positions are confirmed for M-VAVE's open firmware (same hardware) and match the review's "first six black keys = OP1–OP6" [C3:S10]. That the stock firmware uses the same keys is **[I]** but very likely.
- In EDIT mode, the 8 OP/PIT/GLO LEDs blink to show they are selectable, and the selected one is solid. Of MONO/POLY, the active mode is solid and the other blinks [C:S1].
- **Short press OPn** selects that operator. The unit remembers the last page per operator (V13) [C:S2,S3].
- **Long press OPn** mutes that operator until the preset changes (V15) [C:S2,S3]. Stock bug: muting was mirrored (OP1 muted OP6, etc.) [C3:S9]. Do not reproduce it.
- **Normal mode:** the keys play notes. **ARP mode:** the keys feed the arp. **SEQ mode:** the keys enter notes, and in V15 the **16 white keys** act as step LEDs (solid = step has notes, off = empty, blinking = playhead) [C:S1,S2; white-key mapping I:S7 `white_keys[16]`].

---

## 3. Screen layout and global UI behaviour

The 240×240 screen has three zones [C:S1]:
- **Top bar:** current preset `NNN NAME` (e.g. `032 BRASS 1`), plus a battery icon at the top right.
- **Centre:** mode content: oscilloscope (home), parameter boxes or bar graphs, 3×2 FX grid, algorithm diagram, popups.
- **Bottom bar:** mode name plus page indicator (e.g. `1/2 LFO`), and the knob names and values of the parameter being edited (e.g. `CutOff: 1004Hz`, `Mix: 70%`).

**Home screen:** a real-time oscilloscope of the output, drawn as a yellow line on grey [C:S1]. In V16 the colours are user-editable RGB [C:S5].

**Popups** overlay the centre for about 1 s [C:S1]:

| Popup | Trigger |
|---|---|
| Voice list | turning PRESETS |
| Algorithm diagram | turning ALGORITHM |
| `Octave X` | OCT− / OCT+ |
| `Transpose X` | hold OCT and turn ALGORITHM |
| `Volume X` | MASTER |
| `Preset Saved` | SAVE |
| `LOW BATTERY` | low battery; persistent and overrides everything |
| Text notices | `Disable SEQ to enter`, `Disable ARP to enter`, `Enable SEQ first`, `Reset Success`, `Globe Saved` |

**Modes are mutually exclusive pages:** HOME, FX, ENV, LFO, EDIT (with sub-sections), GLO, ARP, SEQ. Pressing a mode's button again returns to HOME (except ENV and ARP/SEQ, which toggle their function off) [C:S1,S2].

ENV values are drawn as block bar graphs; other values are drawn as boxes with numbers [C:S1].

---

## 4. Pages and parameters (V15 stock)

Ranges are as displayed. The DX7 storage value is in parentheses where it differs. The page order follows the V15 official manual [C:S2], which matches M-VAVE's open firmware page table (`TUNE/LVL, OP RATES, OP LEVELS, SENS/OSC, SCALING, CURVES, PITCH RATES, PITCH LEVELS, COMMON, LFO, LFO MOD`) [C:S7 screen.c].

The original V09-era manual [S1] ordered the operator pages differently: P1 rates, P2 levels, P3 Detune 0–14 / Coarse / Fine / OscMode, P4 AMS / KeyVel / OutLevel. **Use the V15 order.**

### 4.1 EDIT → OP1…OP6 (6 pages, K1–K4) [C:S2]

| Page | Title (open fw) | K1 | K2 | K3 | K4 |
|---|---|---|---|---|---|
| 1 | Tuning & Level | Detune −7…+7 (DX7 0–14) | Freq Coarse 0–31 | Freq Fine 0–99 | Output Level 0–99 |
| 2 | Envelope Rates | Rate 1 0–99 | Rate 2 0–99 | Rate 3 0–99 | Rate 4 0–99 |
| 3 | Envelope Levels | Level 1 0–99 | Level 2 0–99 | Level 3 0–99 | Level 4 0–99 |
| 4 | Sensitivity & Mode | Amp Mod Sens 0–3 | Key Velocity Sens 0–7 | Osc Mode Ratio/Fixed | – |
| 5 | Keyboard Scaling | L Depth 0–99 | R Depth 0–99 | Break Point A-1…C7 (0–99) | – |
| 6 | Keyboard Scaling 2 | L Curve −LN/−EX/+EX/+LN | R Curve (same) | Rate Scaling 0–7 | – |

- The manual lists the curves as −LN/−EX/+LN/+EX. The DX7 storage order is 0 = −LIN, 1 = −EXP, 2 = +EXP, 3 = +LIN [I: DX7 standard].
- The frequency display (ratio such as `1.00`, or fixed Hz) is not documented. Use DX7/Dexed conventions [I].

### 4.2 EDIT → PIT (pitch EG, 2 pages) [C:S2]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 | PEG Rate 1 0–99 | PEG Rate 2 0–99 | PEG Rate 3 0–99 | PEG Rate 4 0–99 |
| 2 | PEG Level 1 0–99 | PEG Level 2 0–99 | PEG Level 3 0–99 | PEG Level 4 0–99 |

### 4.3 EDIT → GLO (voice common, 2 pages) [C:S2,S3]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 | Algorithm 1–32 | Feedback 0–7 | Osc Key Sync On/Off | Transpose 0–48 (24 = no shift; DX7 "C3") |
| 2 (V15) | **Init Voice**: turn CW to load the init template | **Rename**: turn CW to open the editor | **Copy Voice**: turn CW to open, CCW to exit | (in Copy) choose the source voice; SELECT confirms the overwrite |

**Rename UI:**
- OP1 / OP2 / OP3 / OP4 select the character class: A–Z, a–z, symbols, digits.
- OP5 deletes.
- K3 picks the character.
- SELECT confirms; K2 CCW cancels.
- 10-character DX7 name. [C:S2,S3]

### 4.4 EDIT → MONO / POLY keys

These switch voice mode: MONO is last-note priority; POLY gives up to 12 voices. The mode is stored per preset [I] (V16 makes glide per Voice part).

### 4.5 LFO (2 pages) [C:S1,S2]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 | Wave: Triangle, Saw Down, Saw Up, Square, Sine, Sample & Hold | Speed 0–99 | PMD 0–99 | AMD 0–99 |
| 2 | Delay 0–99 | Pitch Mod Sens 0–7 | LFO Key Sync 0/1 (Free/Sync) | Osc Sync 0/1 (same parameter as GLO Osc Key Sync) |

The LFO speed table equals Dexed's, entry for entry [C3:S8].

### 4.6 ENV (global ADSR, 1 page)

This is an FM-1 extension that sits on top of the DX7 voice and is stored per preset in an extra settings record.

| K1 | K2 | K3 | K4 |
|---|---|---|---|
| Attack 0–100% | Decay 0–100% | Sustain 0–100% | Release 0–100% |

- History: the range was 0–8 in V09 [S1], then 0–10, then **0–100** from V15 [C:S2,S3].
- On/Off is the ENV button (V09+). Off by default [C:S2,S3].
- Semantics: amplitude envelope applied to the whole voice output, multiplied with the DX7 operator EGs [I]. Attack 0 = instant; Release 0 = abrupt.

### 4.7 FX (Effect Chain)

**Page:** a 3×2 grid of 6 slots, bright = on, dim = off, with a blinking dot under the selected slot [C:S1].
- SELECT moves the cursor.
- SEL grabs the effect and SELECT reorders it (swapping with neighbours).
- K4 turns the effect on (CW) or off (CCW).
- V15: the chain and settings are **saved with each preset** [C3:S10,S8].

Knob layout [C:S1,S2]:
- Filter and Reverb: K1 Type, K2 Param1, K3 Param2, K4 On/Off.
- Delay, Distortion, Chorus, Phaser: K1 P1, K2 P2, K3 P3, K4 On/Off.

| Effect | K1 | K2 | K3 | Panel display | Tag |
|---|---|---|---|---|---|
| Filter | Type LP / BP / HP | Cutoff 100 Hz–20 kHz, 100 log steps (CC range 0–107) | Q 0–100 (V15 manual; CC range 0–10) | `CutOff: 1004Hz` | [C:S1,S2,S4] |
| Reverb | Type Room / Hall / Plate | Decay 0–100% | Mix 0–100% | % | [C:S2] |
| Delay | "Decay" = feedback 0–100% | Rate (time) 0–100% | Mix 0–100% | % | [C:S2,S4] |
| Distortion | Gain 0–100% | Tone 0–100% | Level 0–100% | % | [C:S2] |
| Chorus | Freq (rate) 0–100% | Depth 0–100% | Mix 0–100% | % | [C:S2] |
| Phaser | Freq (rate) 0–100% | Depth 0–100% | Mix 0–100% | % | [C:S2] |

- The default chain order is Filter, Reverb, Delay, Distortion, Chorus, Phaser [C3:S8 record default].
- The original manual used 10% steps for the FX parameters; V15 uses 0–100 [C:S1,S3].
- The effects are mono, and reviewers find them low-fi [C3:S10].
- Third-party firmware lists distortion sub-types Soft Clip / Hard Clip / Foldback [S8]. **Not** in the stock manual, so treat as [I] / optional.
- Algorithm design (filter topology, reverb type) is not published. Use standard designs: a TPT SVF for the filter, a Freeverb/Dattorro-style reverb, etc. [I].

### 4.8 GLO (global settings, V15: 2 pages) [C:S2,S3]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 MIDI & Pitch | MIDI Channel ALL/1–16 (default ALL; called "Note Channel" before V13) | Effect Channel 1–16 (default 2) | Pitch Bend Up 1–24 st | Pitch Bend Down 1–24 st |
| 2 System | **Reset Patches**: CW opens a dialog; K1–K4 choose bank A/B/C/D; SELECT CW confirms (CCW cancels); "Reset Success". Restores the bank to the **last imported** voices | **Velocity** 1–127 (fixed velocity for the onboard keyboard, V13+) | **Glide mode** Full Time / Fingered (works only in MONO) | **Glide Val** 0–100 (0–1 s) |

- The earliest manual's page 2 was "Reset Patches" (factory reset of all 128) plus "Globe Save" (write globals) [C:S1]. V15 replaced it with the page above.
- Glide is in MONO only. Fingered glides only legato [C:S2].

### 4.9 ARP (V15: 2 pages) [C:S1,S2,S3]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 | Mode | Octave 1–4 | Rate (note value) | Tempo 30–300 BPM |
| 2 | Gate 20–100% | Swing 50–75% | Latch On/Off | Sync On/Off (follow external MIDI clock, V13+) |

**Modes** [C:S1,S2]:

| Mode | Pattern |
|---|---|
| Up | low → high |
| Down | high → low |
| Inclusive | ping-pong, endpoints repeated |
| Exclusive | ping-pong, endpoints not repeated |
| Random | random order |
| Order | as played |
| Repeat | each note repeated before moving on |

The product page lists "Bidirectional" instead of "Repeat" [S6]. The manual is authoritative.

- **Rate values:** not listed in the manual. V13 added 1/1 and 1/2 [C:S3]. The likely full set is 1/1, 1/2, 1/4, 1/4T, 1/8, 1/8T, 1/16, 1/16T, 1/32, 1/32T [I: S8 Fm1Seq table].
- **Latch:** notes keep playing after release, and new keys replace the set [C:S1].
- **V16:** the arp also takes notes from external MIDI [C:S5].

---

## 5. Presets, banks, saving

- **Storage:** 128 user-writable slots; slots 001–032 = bank A, 033–064 = B, 065–096 = C, 097–128 = D [C:S1,S7,S10].
- **Selecting:** PRESETS encoder, or MIDI Program Change 0–127 → 001–128 (V13+) [C:S3,S4].
- **Editing:** edits go to an edit buffer. Changing the preset **discards unsaved edits** [C3:S8].
- **Saving:** hold SAVE to write the current preset (over its own slot), FX, patterns and globals [C:S1]. There is no "save to another slot" step. To duplicate a sound, go to the destination slot and use GLO page 2 → Copy Voice to pull the source in, then SAVE [C:S2].
- **Init Voice / Rename / Copy:** see 4.3.
- **Reset Patches:** per bank (V15), restores the last imported bank, not necessarily the factory one [C:S2].

**SysEx bank import** [C:S1,S2,S4]:
1. Send a standard DX7 32-voice bulk dump: `F0 43 0n 09 20 00 <4096 B VMEM> <cs> F7`.
2. A bank-select screen appears; K1–K4 choose A/B/C/D.
3. The bank is written after a short delay.
4. V16: nothing is written until a bank is chosen; on failure a reason is shown and the user can retry.

Over the TRS MIDI port, large dumps may need inter-packet delays [C3: elektronauts p.5].

**Single voice:** a DX7 single-voice dump `F0 43 0n 00 01 1B <155 B VCED> <cs> F7` replaces the current preset [C3:S8,S9]. Sources differ on whether it is auto-saved (S8: written at once; S9, about a derived firmware: held until SAVE). **[I]** Recommendation: load it into the edit buffer and require SAVE.

**Export:** none on V15. V16 adds Bank Export of 32 voices as standard DX7 .syx (DX7 data only, no ENV/FX) [C:S5].

**Velocity:** the engine scales MIDI velocity by 100/127 before msfa [C3:S8, measured on a derived firmware; I for stock]. Note-On with velocity 0 = Note-Off (V15) [C:S3].

---

## 6. Sequencer (V15)

### 6.1 Pages [C:S2]

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1 | Pattern 1–16 | Clear (turn to clear the pattern) | Chain 1–16 (play N patterns consecutively from the current one) | Step (length) 1–16 |
| 2 | Voice 1–128 (preset bound to this pattern; PRESETS is disabled in SEQ) | Rate (note value; editable per step while recording) | Tempo 30–300 BPM | Gate 20–100% |
| 3 | Swing 50–75% | Sync On/Off (external clock) | Transpose −24…+24 | – |

### 6.2 Behaviour

- **Pattern pool:** 16 patterns of 16 steps, polyphonic steps (chords allowed), auto-stored in flash [C:S1,S2,S10].
- **Recording:**
  - REC (red) starts step recording. Each played note or chord goes into the next step. Filled steps light their key LED [C:S1].
  - **Long notes:** on the current step, hold the note and turn SELECT to the end step, then release. Existing notes are not overwritten [C:S2,S3].
  - **Rests and replacement:** while recording, hold REC and turn SELECT to move to a step. Hold keys to add or replace notes, or leave the step empty for a rest [C:S2,S3].
  - **Rate during recording:** each step can carry its own Rate (V09) [C:S2,S3].
- **Playback:**
  - PLAY/STOP starts and stops. The playhead step LED blinks [C:S1].
  - Tempo is shared with the ARP. Sync follows MIDI clock: F8 = clock, FA = start from step 0, FB = same as start (no resume), FC = stop [C:S4].
- **Limitations (V15):** no probability, ratchet, parameter locks or motion recording [C3:S10]. V16 adds 64 steps, ratchet ×1–×4, and an 8×8 arrangement (section 11).

---

## 7. MIDI implementation (stock V15) [C:S4 official "FM-1 MIDI EN.docx", S2, S3]

- **Ports:** USB-MIDI, BLE-MIDI and 3.5 mm TRS IN (31,250 baud) are all active at once [C:S1].
- **Out:** notes with velocity from the keyboard, arp and sequencer, on USB and BLE, using the MIDI channel [C:S1].
- **Channels:** two channel settings.
  - **MIDI Ch** (notes etc.): default **ALL/omni**.
  - **Effect Ch** (FX CCs): default **2**, with no ALL option. A CC on the FX channel is always interpreted as FX, so CC1 on ch2 = Filter Type, not the mod wheel.

### 7.1 MIDI Channel messages

| Msg | Response |
|---|---|
| 9n Note On, vel 1–127 | play (vel 0 = note off) |
| 8n Note Off | release |
| Cn Program Change 0–127 | preset 001–128 |
| En Pitch Bend (14-bit) | bend within the GLO up/down range |
| Dn Channel Aftertouch | modulation (DX7-style; default routes to pitch via the LFO [I]) |
| Bn CC1 Mod Wheel | LFO pitch-mod depth, scaled by the voice's Pitch Mod Sens [I: msfa controllers] |
| Bn CC2 Breath, CC4 Foot | amplitude modulation via the operators' AMS (still listed in V16 notes as "sound-modulation controls") [C:S5; mapping I] |
| Bn CC64 Sustain | sustain |

(Early reviews claimed no mod wheel or sustain support; the official MIDI guide lists both.)

### 7.2 Effect Channel CCs 0–23 (V15) [C:S4]

| CC | Effect | Parameter | Range |
|---|---|---|---|
| 0 | Filter | On/Off | 0 = off, ≥1 = on |
| 1 | Filter | Type | 0 LPF, 1 BPF, 2 HPF |
| 2 | Filter | Cutoff | 0–107 |
| 3 | Filter | Q | 0–10 |
| 4 | Reverb | On/Off | 0 / ≥1 |
| 5 | Reverb | Type | 0 Room, 1 Hall, 2 Plate |
| 6 | Reverb | Decay | 0–100 |
| 7 | Reverb | Mix | 0–100 |
| 8 | Delay | On/Off | 0 / ≥1 |
| 9 | Delay | Decay (feedback) | 0–100 |
| 10 | Delay | Rate | 0–100 |
| 11 | Delay | Mix | 0–100 |
| 12 | Distortion | On/Off | 0 / ≥1 |
| 13 | Distortion | Gain | 0–100 |
| 14 | Distortion | Tone | 0–100 |
| 15 | Distortion | Level | 0–100 |
| 16 | Chorus | On/Off | 0 / ≥1 |
| 17 | Chorus | Freq | 0–100 |
| 18 | Chorus | Depth | 0–100 |
| 19 | Chorus | Mix | 0–100 |
| 20 | Phaser | On/Off | 0 / ≥1 |
| 21 | Phaser | Freq | 0–100 |
| 22 | Phaser | Depth | 0–100 |
| 23 | Phaser | Mix | 0–100 |

- Values above the maximum are clamped [C3:S9].
- The CC numbers are fixed per effect and do not follow the chain order [C3:S9].
- Note that CC7 on the FX channel is Reverb Mix, not volume [C:S4].

### 7.3 System messages

- **System Real-Time:** F8 clock (follow BPM), FA start, FB continue (acts as start), FC stop [C:S4].
- **SysEx parameter change:** `F0 43 10 pp qq vv F7` → write VCED parameter `pp*128 + qq` (0–155) = `vv` [C:S4]. This is the DX7 voice-parameter-change format (sub-status 1, channel 0, group 0, with the high bit in pp), so Dexed-style editors work.
- **SysEx bulk:** DX7 32-voice (VMEM) and 1-voice (VCED) dumps; see section 5.
- **Identity:** the updater handshake is `F0 00 32 45 00 00 00 40 7F F7` (M-VAVE proprietary). Stock firmware **cannot send voices back** [C3:S8]. You do not need to reproduce this.

### 7.4 V16 changes to the MIDI implementation (summary; full list in section 11) [C:S5]

- FX CCs move to **CC70–93** on the Effect Ch: Filter 70–73, Reverb 74–77, Delay 78–81, Distortion 82–85, Chorus 86–89, Phaser 90–93. Each group of four is On/Off plus three parameters, in the same order as V15. CC0–23 is retired.
- CC7 = master volume, CC11 = expression (CC121 resets expression to 127).
- Per-Voice receive channels.
- Notes 0–26 on the Effect Ch light the 27 key LEDs without sounding.

---

## 8. Sound engine notes for implementation

- **Core:** use MSFA/Dexed semantics (DX7 EG rate/level tables, output-level curve, keyboard scaling curves, LFO table, pitch-EG table, 32 algorithm graphs, feedback 0–7) [C:S7].
  - M-VAVE's open source tree has a readable C version: `web/synth/dx7core.c`, `dx7env.c`, `dx7lfo.c`, `dx7pitchenv.c`, `dx7note.c`, `dx7math.c` in github.com/m-vave/fm1_open (Apache-2.0 derived parts).
  - Detail: in algorithms 4 and 6 (0-based 3 and 5), feedback is applied across the operator group, as in MSFA [C:S7 dx7core.c].
- **Measured accuracy:** factory presets on hardware match a msfa render within about 0.6 dB per octave band [C3:S8]. The FM-1 is slightly softer above 6 kHz: about −1 dB (6–10 kHz), −2 dB (10–14 kHz), −3.5 dB (14–20 kHz). The output is 16-bit. Optional "hardware character" emulation: a gentle HF shelf plus 16-bit quantisation [C3:S8].
- **Voice allocation:** 12 voices. Steal priority: silent voice > released voice > same pitch > oldest [C3:S8 model of msfa].
- **Per-preset transpose:** VCED 144, where 24 = none, is applied to incoming notes [C3:S8].
- **Signal flow (V15)** [I, from S1/S2/S10]:
  1. DX7 voice sum.
  2. Optional global ADSR (ENV).
  3. 6-slot mono FX chain in user order.
  4. MASTER volume.
  5. Output: mono to both channels, plus the speaker.
- **Per-preset extra data** beyond the 128-byte DX7 voice (V15) [C3:S8; layout I]:
  - FX on/type/params and chain order.
  - ENV A/D/S/R/on.
  - Probably MONO/POLY.
  - S8 documents a 59-byte "settings record":
    - FX params: 3 bytes per effect at [0..17].
    - Chain: (id, on, type) × 6 at [27..44].
    - ADSR 0–100 at [54..57]; on at [58].

---

## 9. Factory presets (V15 order, verified)

Extracted from M-VAVE's own V15 recovery image `sdk/firmware/FM-1_015.fwsc` via `app/fm_factory.inc` in github.com/m-vave/fm1_open (Apache-2.0; VMEM SHA-256 `ecad0b86…aad25`) [C:S7].

They are stored as standard DX7 VMEM. Bank D (097–128) is the DX7 ROM-cartridge "percussion / effects" style set (BOWOAN, TUB BELLS, WHAT IF …). The other banks are M-VAVE-named voices.

The `.syx` files next to this document reproduce these banks byte-for-byte. Columns are `No | Name | Alg | FB`.

**Bank A**

| No | Name | Alg | FB |
|---|---|---|---|
| 001 | PIANO 1 | 5 | 6 |
| 002 | ORGAN 1 | 32 | 0 |
| 003 | SYN LEAD 1 | 5 | 0 |
| 004 | SYN PAD 1 | 15 | 7 |
| 005 | PIANO 2 | 5 | 7 |
| 006 | Organ 2 | 22 | 7 |
| 007 | SYN LEAD 2 | 22 | 7 |
| 008 | SYN PAD 2 | 2 | 3 |
| 009 | PIANO3 | 6 | 4 |
| 010 | ORGAN 3 | 32 | 6 |
| 011 | SYN LEAD 3 | 7 | 7 |
| 012 | SYN PAD 3 | 2 | 6 |
| 013 | PIANO 4 | 5 | 7 |
| 014 | ORGAN 4 | 32 | 5 |
| 015 | SYN LEAD 4 | 7 | 0 |
| 016 | SYN PAD 4 | 5 | 7 |
| 017 | PIANO 5 | 5 | 6 |
| 018 | ORGAN 5 | 29 | 0 |
| 019 | SYN LEAD 5 | 2 | 7 |
| 020 | SYN PAD 5 | 9 | 6 |
| 021 | PIANO 6 | 9 | 6 |
| 022 | ORGAN 6 | 29 | 0 |
| 023 | SYN LEAD 6 | 14 | 7 |
| 024 | SYN PAD 6 | 6 | 0 |
| 025 | PIANO 7 | 5 | 6 |
| 026 | ORGAN 7 | 5 | 7 |
| 027 | SYN LEAD 7 | 7 | 4 |
| 028 | SYN PAD 7 | 18 | 6 |
| 029 | PIANO 8 | 5 | 6 |
| 030 | ORGAN 8 | 32 | 2 |
| 031 | SYN LEAD 8 | 3 | 7 |
| 032 | SYN PAD 8 | 2 | 7 |

**Bank B**

| No | Name | Alg | FB |
|---|---|---|---|
| 033 | GUITAR 1 | 8 | 7 |
| 034 | DS GUITAR1 | 14 | 2 |
| 035 | BASS 1 | 16 | 6 |
| 036 | SYN BASS1 | 17 | 6 |
| 037 | GUITAR 2 | 15 | 7 |
| 038 | DS GUITAR2 | 4 | 7 |
| 039 | BASS 2 | 14 | 7 |
| 040 | SYN BASS2 | 1 | 7 |
| 041 | GUITAR 3 | 8 | 7 |
| 042 | DS GUITAR3 | 4 | 5 |
| 043 | BASS 3 | 17 | 7 |
| 044 | SYN BASS3 | 16 | 7 |
| 045 | GUITAR 4 | 8 | 7 |
| 046 | DS GUITAR4 | 20 | 7 |
| 047 | BASS 4 | 21 | 0 |
| 048 | SYN BASS4 | 18 | 6 |
| 049 | GUITAR 5 | 8 | 7 |
| 050 | DS GUITAR5 | 16 | 7 |
| 051 | BASS 5 | 16 | 7 |
| 052 | SYN BASS5 | 5 | 6 |
| 053 | GUITAR 6 | 14 | 4 |
| 054 | DS GUITAR6 | 14 | 2 |
| 055 | BASS 6 | 9 | 5 |
| 056 | SYN BASS6 | 16 | 7 |
| 057 | GUITAR 7 | 14 | 4 |
| 058 | DS GUITAR7 | 1 | 7 |
| 059 | BASS 7 | 5 | 4 |
| 060 | SYN BASS7 | 14 | 5 |
| 061 | GUITAR 8 | 12 | 7 |
| 062 | DS GUITAR8 | 4 | 5 |
| 063 | BASS 8 | 3 | 7 |
| 064 | SYN BASS8 | 2 | 6 |

**Bank C**

| No | Name | Alg | FB |
|---|---|---|---|
| 065 | BRASS 1 | 18 | 7 |
| 066 | WOODWIND 1 | 3 | 5 |
| 067 | STRING 1 | 2 | 7 |
| 068 | VOICE 1 | 5 | 0 |
| 069 | BRASS 2 | 5 | 7 |
| 070 | WOODWIND 2 | 23 | 5 |
| 071 | STRING 2 | 15 | 7 |
| 072 | VOICE 2 | 8 | 7 |
| 073 | BRASS 3 | 2 | 7 |
| 074 | WOODWIND 3 | 6 | 7 |
| 075 | STRING 3 | 2 | 4 |
| 076 | VOICE 3 | 7 | 7 |
| 077 | BRASS 4 | 15 | 6 |
| 078 | WOODWIND 4 | 3 | 4 |
| 079 | STRING 4 | 2 | 7 |
| 080 | VOICE 4 | 5 | 0 |
| 081 | BRASS 5 | 9 | 7 |
| 082 | WOODWIND 5 | 1 | 5 |
| 083 | STRING 5 | 2 | 7 |
| 084 | VOICE 5 | 1 | 4 |
| 085 | BRASS 6 | 18 | 7 |
| 086 | WOODWIND 6 | 5 | 7 |
| 087 | STRING 6 | 9 | 7 |
| 088 | VOICE 6 | 5 | 7 |
| 089 | BRASS 7 | 4 | 6 |
| 090 | WOODWIND 7 | 3 | 7 |
| 091 | STRING 7 | 2 | 7 |
| 092 | VOICE 7 | 27 | 6 |
| 093 | BRASS 8 | 18 | 7 |
| 094 | WOODWIND 8 | 31 | 6 |
| 095 | STRING 8 | 2 | 7 |
| 096 | VOICE 8 | 27 | 5 |

**Bank D**

| No | Name | Alg | FB |
|---|---|---|---|
| 097 | BOWOAN | 18 | 7 |
| 098 | BDWHOCARES | 17 | 7 |
| 099 | BLOCK | 18 | 7 |
| 100 | WAVES | 1 | 7 |
| 101 | FROGBELL | 2 | 7 |
| 102 | ELECT.GONG | 8 | 7 |
| 103 | TORIMTORA2 | 9 | 7 |
| 104 | MONO M | 3 | 0 |
| 105 | TIBET | 3 | 6 |
| 106 | LOG DRUM | 14 | 5 |
| 107 | COWBELL | 6 | 0 |
| 108 | MONO Z | 18 | 7 |
| 109 | FINGERCYM | 20 | 7 |
| 110 | TIMPANI | 16 | 7 |
| 111 | TAMBOURINE | 18 | 7 |
| 112 | DESCENT | 1 | 7 |
| 113 | CLANG BELL | 5 | 7 |
| 114 | STEEL DRUM | 15 | 5 |
| 115 | CONGA | 2 | 0 |
| 116 | SAW EM UP | 15 | 7 |
| 117 | BI   BEN | 6 | 0 |
| 118 | KALIMBA | 4 | 7 |
| 119 | GAMALONG | 12 | 5 |
| 120 | SAW EM UP2 | 15 | 7 |
| 121 | TUB BELLS | 5 | 7 |
| 122 | BRUSHES | 7 | 7 |
| 123 | TOM TOMS | 16 | 7 |
| 124 | SAW EM UP3 | 15 | 7 |
| 125 | ECHO | 6 | 7 |
| 126 | TIMBALI | 16 | 7 |
| 127 | PERCUSSION | 11 | 0 |
| 128 | WHAT IF | 1 | 0 |

Notes:
- The manual's example strings (`032 BRASS 1`, `PIANO 3`) do not match this order. They probably come from a pre-V13 bank; V13 "updated some factory tones to even out volume" [S3]. **Use the V15 order above.**
- The per-preset FX/ENV defaults for the factory presets are not in the VMEM. **[I]** Default them to all FX off, ENV off. V15 factory FX settings are unknown; check on hardware if possible.

---

## 10. Firmware history (official, from S3)

| Ver | Date | Changes |
|---|---|---|
| V09 | 2026-06-24 | ENV on/off switch; Rate change during SEQ recording; SEQ rests and note replacement |
| V13 | 2026-07-03 | BPM sync (ext clock) for ARP and SEQ; OP page memory; SEQ transpose; factory voices level-matched; **GLO Velocity 1–127**; MIDI Ch (was Note Ch) with ALL as default; **Program Change 0–127**; rates 1/1 and 1/2 added |
| V14 | 2026-07-06 | "Major update" desktop updater package (FM-1-NTFS Win/Mac). The version reviewed by Synth Anatomy |
| V15 | 2026-07-30 | Brighter base LED level; GLO bank reset (A–D, to the last import); **Glide** (MONO, Full Time/Fingered, 0–100 = 0–1 s); SEQ long notes, per-pattern Voice binding, Step length, Chain 1–16; EDIT Init Voice, Rename, Copy Voice, long-press OP mute; FX and ENV ranges 0–100; vel-0 = Note Off; FX CCs rescaled ("CC response table") |
| V16 | 2026-10-20 | Multitimbral; see section 11 |

There is no V15 "velocity-sensitive keyboard" feature. The "velocity" items are the GLO fixed velocity (V13) and vel-0 handling (V15).

---

## 11. V16 deltas (optional target) [C:S5, official forum and FM-1.txt]

- **8 "Voices" (parts).** Each part has preset, On/Off, MIDI Rx channel, Level, Pan, bend up/down, glide, and Fine Tune ±100 cents. **20-voice** polyphony shared dynamically across the parts.
- **PRESETS top entry:** selects FX or Voice1–8. With a Voice selected, K1–K4 = MIDI Ch / Level / Pan / On-Off. In SEQ it selects FX or Pattern1–16. The popup times out after 3 s.
- **SEQ:** 64 steps per pattern (16 patterns); 8-row × 8-column arrangement (row = Voice, cell = pattern or empty; length 1–8 columns; 4×4 visible window).
  - ALGORITHM selects the step while stopped or recording.
  - Ratchet ×1–×4 per step.
  - Start from the selected step.
  - Pattern changes are queued to the end of the cycle.
- **FX:** a global **stereo** chain with a library of **128 FX groups** (FX001–FX128). Each group stores order, on/off, params and a 10-character name. ALGORITHM picks the group on the FX page. Changing presets no longer changes FX.
- **GLOBE:** 5 main pages: Voices 1–4, Voices 5–8, performance/connectivity, display, data management. Each Voice Set has Basic / Pitch / Glide sub-pages. The firmware version is on the last page.
- **SAVE menu:** ALL / Globe / Preset / Pattern (unchanged items dimmed). Copy dialog shows source and destination. **Bank Export** as DX7 .syx.
- **MIDI:** CC70–93 FX map; CC7 master volume; CC11 expression; ARP accepts external notes; USB Loopback option; hold PLAY/STOP = Panic; key-LED control via notes 0–26 on the Effect Ch.
- **Display:** RGB colour editor (background, widgets, footer, waveform, text, page text, borders); Btn BL / Key BL dim-glow toggles.

---

## 12. Open-source and alternate firmware landscape (context, not stock behaviour)

- **"Open source"** = **FM1 Open** by M-VAVE (github.com/m-vave/fm1_open, current V14 branch, separate from stock V16).
  - It is an 8-track groovebox: DX7 FM, 303, 808, PSG, Pluck and Sampler engines; 64-step sequencer; 16 FX demos; 8 sample slots.
  - The app is GPLv3 with an SDK linking exception; the DSP engine is a binary SDK (`libfm1_engine.a`).
  - It bundles the official V15 recovery image (Apache-2.0) and is the source of the factory bank above [C:S7].
  - Its CC map (CC7, 10, 11, 91, 74 …) is documented at midi.guide/d/m-vave/fm1-community [S12]. It is **not** the stock map.
- **Official web "FM1 Workbench"** (open.m-vave.com/fm1-workbench) [C:S14]:
  - A Chrome/Edge Web-MIDI page that shows a virtual FM-1 front panel (knobs, LCD, keys, function buttons, 16-step grid). Simulator built from the C sources compiled to WASM.
  - Preset browser; DX7 library A–D read/export as .syx; projects (.fm1), track voices (.fm1t), samples (.fm1s).
  - Firmware update, including "restore official V15".
  - It targets FM1 Open, not stock.
- **Official desktop updater:** "FM-1-NTFS"/M-UPGRADE for Windows (.zip) and Mac (.dmg). Firmware files (`FM-1.fwsc`) are on m-vave.com/download.html [C:S6]. **There is no official iOS editor app** (none found) [I: absence].
- **Third-party tools:**
  - Browser librarian by Benny Sparra (fm1-dx7-patch-importer.ben-bfd.workers.dev) [S13].
  - DXcompanion.uk (beta FM-1 support).
  - fm1-editor.com.
  - Virtual FM-1, a VST/AU/standalone/iOS-buildable emulator by jbschooley [S8].
  - fm1-emu (runs firmwares in the browser).
- **Alternate firmwares:**
  - baud girl FM-1+VA (adds a VA engine, 64 steps, CC knob banks) [S9].
  - Felucca (hugelton), SLOOP (isod89), Melodee (keremimo), ChoralRoot, KARMA, GR!MM, fm1-dock.
  - Index: github.com/cicloid/awesome-fm-1 [S16].
  - These are good UX references, but not the stock spec.

---

## 13. Open questions (verify on hardware if possible)

1. Exact ARP/SEQ Rate list and its default value.
2. The ARP Octave, Rate and Mode display strings.
3. Whether MONO/POLY, Glide and Velocity are per preset or global (V15 puts Glide and Velocity in GLO, so they are probably global).
4. Factory FX/ENV settings per preset.
5. Filter cutoff mapping: panel 100 steps vs CC 0–107; panel Q 0–100 vs CC 0–10.
6. Whether a single-voice DX7 dump auto-saves.
7. Algorithm-diagram drawing style; oscilloscope trigger behaviour.
8. Aftertouch routing (the official guide just says "channel aftertouch").
9. Whether MIDI out also echoes Program Change or CCs. The manual says notes only.

---

## 14. Sources

| ID | Source | URL |
|---|---|---|
| S1 | Original multilingual User Manual (EU importer print) | https://m.media-amazon.com/images/I/A1WOydif9HL.pdf |
| S2 | Official "Detailed User Manual" (V15-era, revised 2026-08-10), linked from the m-vave.com product page | https://manualf.oss-cn-hongkong.aliyuncs.com/manual/MIDI-KEYBOARD/FM-1-manual.pdf |
| S3 | Official firmware release notes, V09–V16 | https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1.txt |
| S4 | Official MIDI implementation ("FM-1 MIDI EN.docx", the V15 CC guide) | https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1%20MIDI%20EN.docx |
| S5 | Official V16 release notes (M-VAVE forum topic 23) | https://forum.m-vave.com/topic/23 (API: https://forum.m-vave.com/bbs/api/forum/topics/23) |
| S6 | Official product and download pages | https://www.m-vave.com/product.html?id=fm-1 · https://www.m-vave.com/download.html |
| S7 | M-VAVE FM1 Open source (factory bank, SDK, panel wiring, MSFA attribution) | https://github.com/m-vave/fm1_open |
| S8 | Virtual FM-1 (hardware measurements, record layout) | https://github.com/jbschooley/Virtual-FM-1 (docs/HARDWARE-NOTES.md) |
| S9 | baud girl FM-1+VA manual (documents the inherited FX CC0–23 and the OP-mute bug) | https://baudgirl.com/work/FM-1+VA/manual |
| S10 | Synth Anatomy review (V14) | https://synthanatomy.com/2026/07/m-vave-fm-1-review-low-budget-pocket-fm-ynthesizer-with-iconic-sounds.html |
| S11 | MatrixSynth V15 and V16 posts | https://www.matrixsynth.com/2026/07/m-vave-fm-1-v15-firmware-update-new.html · https://www.matrixsynth.com/2026/10/m-vave-fm-1-official-v16-firmware.html |
| S12 | midi.guide, FM1 Open CC map | https://midi.guide/d/m-vave/fm1-community/ |
| S13 | Synth Anatomy, patch librarian | https://synthanatomy.com/2026/07/m-vave-fm-1-patch-librarian.html |
| S14 | Official FM1 Workbench | https://open.m-vave.com/fm1-workbench |
| S15 | Firmware reverse-engineering article (JieLi AC791N) | https://zeli.app/story/49994065 |
| S16 | Alternate firmware index; Synthtopia FM1 Open announcement | https://github.com/cicloid/awesome-fm-1 · https://synthtopia.com/content/2026/10/20/m-vave-officially-opens-fm-1-firmware-to-developers-with-new-workbench-sdk |

Also consulted:
- Elektronauts thread: https://www.elektronauts.com/t/m-vave-fm-1/252170 (page 1 is mostly pre-release speculation; page 5 covers editor tools and TRS SysEx delays).
- Sonic State reviews roundup: https://sonicstate.com/news/2026/07/10/m-vave-fm-1-reviews-/
- SynthHub's stock V15 CC chart (returned HTTP 401, so not read; search snippets agree with S4).

Not reached: bonedo, gearnews, thesynthsource, china-gadgets.de, YouTube transcripts. The primary sources above made them unnecessary for the functional spec.
