# FM-1 official firmwares: sequencer and rhythm/drum features

Scope: **M-VAVE official options only.** These are (A) stock firmware V16 and (B) FM1 Open, M-VAVE's open-source groovebox firmware (V14 on GitHub). Third-party firmwares are out of scope; the `fm1va_*` images in `images/firmware/` are not covered here.
Researched 2026-11-08.

**Tags**
- **[C]** Confirmed from an official source, quoted or read directly. For FM1 Open this means the source code itself.
- **[I]** Inferred: my reading or extrapolation, not stated by M-VAVE.
- `[S#]` Source number (see the Sources list at the end).

---

## 0. Quick answer

| Firmware | Sequencer features | Rhythm / drum features |
|---|---|---|
| **Stock V16** (2026-10-20, latest stock) | <ul><li>16 patterns × up to **64 steps**</li><li>**8-row × 8-column arrangement** (row = Voice/part, cell = pattern)</li><li>Per-step **ratchet ×1–×4**</li><li>Per-step Rate (since V09)</li><li>Start from the selected step</li><li>Queued pattern switch</li><li>Long notes, transpose, swing, gate</li></ul> | **None dedicated.** There is no drum engine or drum lanes. You get rhythm by putting FM percussion presets on one of the 8 multitimbral Voices. [C:S1,S2] [I: no drum mode is mentioned anywhere] |
| **FM1 Open V14** (2026-10-19, latest Open) | <ul><li>**8 tracks × 64 steps**, with per-track loop length 16/32/48/64</li><li>Per-step velocity, gate, **probability**, **chord**, **tie**, **parameter lock**, note</li><li>Swing, metronome, count-in</li><li>Step and live (quantized) recording</li><li>Copy/paste/repeat, undo</li><li>Per-track arpeggiator / **drum repeat**</li></ul> | <ul><li>**DRUM 808** engine: 11 synthesized voices plus KIT settings (DaisySP/Plaits-derived)</li><li>**SAMPLER**: 8 pads, about 19.5 s of shared memory, choke groups</li><li>Drum tracks use a per-pad **lane bitmask** per step</li><li>303 accent and slide come from velocity and ties</li></ul> |

No stock **V17** exists as of 2026-11-08:
- The official release-note file tops out at V16 (2026-10-21 header) [C:S2].
- The forum "Official Firmware Update Summary" covers V16 only [C:S1].

FM1 Open releases so far, all on GitHub [C:S4]:
- V12: 2026-10-16
- V13: 2026-10-17
- V14: 2026-10-19
- A fix commit on 2026-10-21, still labelled V14.

---

## A. Stock firmware V16 (official, closed source)

Sources:
- [S1] https://forum.m-vave.com/topic/23 (API: https://forum.m-vave.com/bbs/api/forum/topics/23)
- [S2] https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1.txt (GB18030-encoded; CN and EN text)
- [S3] matrixsynth V16 posts

The text is identical in S1 and S2. The release notes say "the user manual on the official website has been updated", but the download page only lists the firmware, the release-note txt and the MIDI docx. I found no V16 manual PDF [C:S5]. **Step-level UI details below therefore come only from the release notes.**

### A.1 Sequencer data model

| Item | V15 | V16 | Tag |
|---|---|---|---|
| Patterns | 16 | 16 (pool unchanged) | [C:S1 §2.1] |
| Steps per pattern | 16 | **up to 64** | [C:S1 §2.1] |
| Polyphony | 12 | **20 shared across 8 Voices** | [C:S1 §1.2] |
| Pattern → sound | Each pattern bound to a voice/preset (V15 "voice selection") | Pattern plays on the **row's Voice** in the arrangement. In SEQ, PRESETS chooses Pattern1–16, then the preset list "belongs to the selected Pattern". | [C:S1 §2.2, §4.2] |
| Chain | V15 "Chain 1–16" consecutive patterns | **Replaced** by the arrangement | [C:S1 §2.2] |
| Arrangement | – | **8 rows (Voice1–8) × 8 columns**. Each cell holds a pattern reference or is empty. Length is 1–8 columns. Several cells may reference the same pattern (by reference, so edits propagate). All rows play simultaneously. | [C:S1 §2.2–2.4] |
| Per-step data | note(s)/chord, long-note end, **Rate** (V09: rate changes during recording are stored per step) | Plus **Ratchet ×1/×2/×3/×4** | [C:S1 §2.8, §2.11; S2 V09] |
| Transpose | V13 "sequencer transpose" | kept | [C:S2 V13] |
| Swing, gate, tempo | Page 3 / page 2 in V15 | Presumably kept; not mentioned | [I] |

**Ratchet semantics** [C:S1 §2.8]:
- Set it while stopped or while recording.
- It applies only to steps with a note-on.
- It retriggers the step N times **within the step's duration**: no extra steps, and the total duration is unchanged.
- Empty steps and note-off-only steps do not retrigger.

**Long notes** [C:S2 V15, S1 §2.7]:
- Hold the note.
- Turn the step selector to the end step, then release.
- In V16 the step selector is **ALGORITHM** (in V15 it was SELECT).
- Existing notes are not overwritten.

### A.2 Transport and recording rules (V16) [C:S1]

**Single-pattern playback**
- If you select another pattern, the switch happens at the **end of the current cycle** (§2.5).
- **Start from the selected step:**
  1. While stopped, select a step with ALGORITHM.
  2. Press PLAY/STOP.
  3. Playback starts at that step and wraps to step 1 after the last step.
- This applies only to local single-pattern playback. Arrangement playback and external MIDI follow their own start rules (§2.10).

**Arrangement playback**
- The edit/browse position is independent of the playback position (§2.5).

**Recording**
- Press REC on a **non-empty arrangement cell**. This records into that cell's pattern, monitored with that row's Voice.
- Recording always starts at step 1. An empty cell does not enter recording (§2.6).

**Step selection**
- ALGORITHM selects the step while stopped or recording. It is locked during playback.
- SELECT pages through the parameter pages (§2.7).

**Rate display**
- When viewing the playing pattern, the Rate shown is the rate stored on the current playback step (§2.11).

**Panic**
- Hold PLAY/STOP to stop SEQ/ARP and clear stuck notes (§6.5).

### A.3 Screens and controls (V16)

**64-step grid** [C:S1 §2.9]
- "Reorganized 64-step grid (dot matrix 点阵), arrangement cells and K1–K4 parameter layout."
- The selected edit cell gets an **outline**.

**Arrangement view** [C:S1 §2.3]
- Shows **4 Voice rows × 4 columns** at a time and auto-scrolls to rows 5–8 or columns 5–8.
- Disabled Voices and cells beyond the arrangement length are **dimmed**.

**Arrangement parameter page 2** [C:S1 §2.12]
- Has a **Voice On/Off** for the edited row: K4 right turns it on, K4 left turns it off.
- This is synced with GLOBE → Voice Set and saved via SAVE → Globe/ALL.
- Turning a Voice off keeps its pattern references.

**PRESETS popup in SEQ** [C:S1 §4.2–4.3]
- Top entries: FX and Pattern1–16.
- Closes after about 3 s idle.

**SAVE** [C:S1 §5.1–5.2]
- Has a **Pattern** category. Success shows "Pattern Saved"; "More Unsaved" means other edits are still pending.

**External key LEDs** [C:S1 §6.6]
- Notes 0–26 on the Effect Ch light the 27 key LEDs. Relevant if you want to drive a step display from outside.

**Screenshot** (`images/firmware/official_v16_natlife_video_YG_VAYJFlB8.jpg`; thumbnail of the NatLife V16 demo, [S3]):
- The LCD shows a dense **dot-matrix grid**, roughly 16 columns × several rows of small dots, which reads as a 64-step grid.
- A title strip shows a preset name ("PLK Cosmic…").
- Several white-key LEDs are lit, as in the V15 step display. The **SEQ** button is lit green.
- Photo resolution is too low to read the K1–K4 labels.
- **[I]** Layout guess: 64 steps as 4 rows × 16 dots with the playhead and selection outline. Not verified.

**Screenshot 2** (`images/firmware/official_v16_natlife_video2_g0MQwvhUXPU.jpg`):
- V16 on a white unit. The title reads "…Monstro".
- Below it is a row of dot indicators and a K1–K4 parameter row (illegible).
- HOME and SEQ are lit, and several white-key LEDs are on.

**[I] Not found in official text:**
- How the 64 steps map to the 16 white keys (paging with OCT? per-quarter?).
- The full K1–K4 parameter list on each SEQ page in V16.
- Treat these as unknown. The V15 page table is in FUNCTION_SPEC §6.1.

### A.4 Rhythm / drums in V16

- No drum engine, drum lanes, per-instrument mute, accent or probability is listed [C:S1, absence].
- **[I]** In practice, rhythm means an FM percussion preset on a Voice row, recorded as notes in a 64-step pattern, plus ratchets for rolls and hats.

### A.5 Swift notes for V16 parity

```swift
struct V16Step {
    var notes: [UInt8]        // chord allowed; long notes need an end step
    var velocity: UInt8
    var rate: NoteRate        // per-step (V09+)
    var ratchet: UInt8        // 1...4
    var tieUntil: UInt8?      // long note end step (V15+)
}
struct V16Pattern { var steps: [V16Step] /* count 1...64 */; var length: Int }
struct V16Song {
    var patterns: [V16Pattern]             // 16
    var cells: [[Int?]]                    // [8 voices][8 columns], pattern index or nil
    var length: Int                        // 1...8 columns
    var voiceOn: [Bool]                    // 8, mirrors GLOBE Voice Set
}
```

- **Ratchet timing:** for a step of duration `d` with ratchet `r`, trigger at `d*k/r` for k = 0..<r. Gate per hit is `gate*d/r` [I].
- **Pattern switching:** model a `pendingPattern` that is applied at the cycle wrap.
- **Arrangement:**
  - Each row advances columns when the row's pattern finishes.
  - **[I] Ambiguous:** if patterns in one column have different lengths, M-VAVE does not say whether a column lasts as long as the longest pattern or as a fixed bar. Pick "column = longest pattern in the column" and flag it as unverified.
- **Voice allocation:** a 20-voice pool shared across 8 parts, with oldest-note stealing [I].

---

## B. FM1 Open (official open-source groovebox), V14

Sources:
- [S4] github.com/m-vave/fm1_open, read as text only, including:
  - `README.md`
  - `app/instrument.h`
  - `app/screen.c`
  - `web/engine/sequencer.c`
  - `web/engine/sound.c`
  - `web/engine/edit.c`
  - `third_party/synth/drum808.c`, `bass303.c`, `pluck.c`
  - `web/synth/voices.c`, `sampledrum.c`, `sample_metadata.inc`
- [S6] open.m-vave.com/fm1-workbench: the built-in manual (Chinese text; translated here)
- [S7] Synthtopia announcement
- [S8] forum topic 4 (English announcement)

**What the firmware is**
- Version string `FM1_RELEASE_VERSION "V14"`; update product `FM-1_8000014` [C:S4 app/version.h].
- The device DSP engine is a binary SDK (`libfm1_engine.a`).
- `web/engine/*.c` is the browser simulator built from C. I treat it as the reference implementation of the same `instrument.h` API [I: same API and same file comments].
- `screen.c` is the real device UI.

### B.1 Structure and limits [C:S4 instrument.h]

| Constant | Value |
|---|---|
| Tracks | 8 (`GROOVE_TRACKS`) |
| Steps | 64 per track (`GROOVE_STEPS`). Loop length per track is 16/32/48/64. A length change during play applies at that track's next loop start. Shortening keeps hidden cells. |
| Sources (engines) | DX7, 303, 808, PSG, PLUCK, SAMPLE (one per track; any mix) |
| Drum pads | 808: 11 (`GROOVE_DRUMS`). Sampler: 8 pads. Max 16 lane bits. |
| Chords | 16 chord definitions, **shared by the whole project** |
| Parameter locks | **16 per project** (one per track+step; track 255 = unused) |
| Projects | 16 user slots plus 16 read-only factory projects. Project v4 is 4064 bytes, so the whole 8-track project fits one 4 KiB flash sector. |
| Tempo | 30–300 BPM internal; tap tempo; MIDI clock in (24 PPQN) |
| Step resolution | **Fixed 1/16 note** (period = 60/(BPM·4)). Live recording quantizes to the nearest 1/16. |
| MIDI in | Track 1–7 on ch 1–7; track 8 on **ch 10**. Remappable per track. |

**Track roles** (SEQ page 8/8):
- `NORMAL`: sequenced.
- `PLAY`: live only; keeps its sound and held notes across project changes; not recorded.
- `OFF`.

### B.2 Step cell format (exact) [C:S4 instrument.h, sequencer.c]

```c
struct groove_step { uint8_t note, velocity; uint16_t drums; };   // 4 bytes
```

**Melodic tracks** (DX7, 303, PSG, PLUCK). Bit fields of `drums`:

| Bits | Field | Range / meaning |
|---|---|---|
| 0–4 | chord id | 0 = single note; 1–16 = project chord table entry |
| 5–8 | gate | 0 = default 50%; 1–14 = g/16 of the step; 15 = full step |
| 9–11 | probability | 0 = always; 1–7 = p/8 |
| 12 | tie | Hold into the next step; common notes are not retriggered |
| 13 | alt tuning | Use the track's alternate microtuning table |
| 14–15 | reserved | – |

- `velocity` 0 means an empty step (a rest; releases unless the previous step is tied).
- `note` 0–127.

**Drum tracks** (808, SAMPLER):
- `drums` = **bitmask of pads hit on this step** (bit d = pad d).
- `velocity` = one velocity shared by all pads on the step (0 means 100).
- `note` high nibble = probability (0–7); low nibble reserved (must be 0).
- There is no gate, chord or tie: drum gates are fixed at half a step.

**Chord table**
- Each entry is `[count, offsets…]`: positive semitone offsets from the root, ascending, max 8 notes.
- Defaults (12 of 16):
  - MAJOR {4,7}, MINOR {3,7}, MAJ7 {4,7,11}, MIN7 {3,7,10}
  - DOM7 {4,7,10}, SUS2 {2,7}, SUS4 {5,7}, DIM {3,6}
  - AUG {4,8}, FIFTH {7}, OCTAVE {12}, ADD9 {4,7,14}
- When a chord is played in during recording, the firmware matches an existing entry or allocates a free one ("CUSTOM").
- Error "CHORD OR LOCK FULL" when all 16 entries are used.

**Parameter locks**
- Each lock is `{track, step, parameter, value 0–127}`. The value is scaled to the parameter's range.
- At each step: restore the previous lock, then apply the locks for this step. **Locks last one step.**
- Lockable parameters:

| Engine | Lockable parameters |
|---|---|
| DX7 | 145 (any operator parameter or global: "OP3 RATE 2", "ALGORITHM", "FEEDBACK", LFO …) |
| 303 | 12 |
| PSG / PLUCK | 4 |
| SAMPLER | 48 (8 pads × 6) |
| 808 | **1: track VOLUME only** |

- A MIDI CC that controls the same parameter overrides the lock [C:S6].

**Probability** uses a per-sequencer xorshift RNG:
- `if p && (rand & 7) >= p` → skip the step and release the track.

**Swing** (0–50%):
- Alternating step periods: even steps are `(100+swing)%` long, odd steps `(100−swing)%`.
- Under MIDI clock, steps are 6±shift pulses.

**Metronome:** OFF / REC (only while recording) / ON. A click on every 4th step.

**Count-in:** 1 bar (16 steps) before recording when playback starts with REC armed.

### B.3 Recording and editing [C:S4 screen.c, edit.c; S6 §03]

**Step recording** (REC while stopped, header shows `STEP`):
- Play keys; all notes held together go into one step.
- The cursor **advances when all keys are released**. This works for melodic, 808 and Sampler tracks.

**Live recording** (REC while playing, header `REC`, or `CNT 4…1` during count-in):
- Notes from the panel or MIDI are written to the nearest 1/16 with velocity.
- `record_position` uses the next step if the note lands in the second half of a step.

**Grid editing** (SEQ page 1/8 BASIC, not recording):
- The 16 **white keys** toggle steps of the current 16-step page.
- New melodic steps use the "selected note" (set with K3), velocity 100.
- On a drum track, the white keys toggle the **currently selected pad's** lane; K3 selects the pad.

**Copy menu:** hold SEQ for 0.6 s, or press SEQ+EDIT. Items:
- STEP DETAILS, RHYTHM/RECORD
- COPY / PASTE / CLEAR for STEP, PAGE (16) or TRACK
- **REPEAT TO 32/48/64**: duplicates the loop and its locks
- UNDO/REDO (single-level swap snapshot), COPY/PASTE TIMBRE
- DX7 PATCH NAME, BLUETOOTH/CLOCK, STOP ALL/REWIND
- SAVE executes; a second SAVE confirms destructive actions.

**Shortcuts**
- HOME+SAVE = undo/redo
- HOME+PLAY = emergency stop and rewind
- HOME + tap SEQ = tap tempo
- EDIT+REC = DX7 rename

### B.4 SEQ pages (ALGORITHM pages through 8 pages) [C:S4 screen.c `seq_pages[]`, S6]

Encoder roles everywhere:
- **SELECT** = track
- **PRESETS** = step cursor
- **OCT−/OCT+** = previous/next 16-step page; their LEDs are lit when that page exists
- **ALGORITHM** = page

| Page | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| 1/8 BASIC | LEVEL (track vol) | STEP (cursor; shows PLAY while following) | NOTE (melodic; edits an existing step's pitch) / DRUM or SLOT # (drums) | BPM |
| 2/8 STEP DETAILS | VELOCITY 0–127 | GATE % (50 default … 100) | PROB % (12.5 steps) | CHORD (SINGLE/MAJOR…/CUSTOM) |
| 3/8 RHYTHM/REC | SWING 0–50% | CLICK OFF/REC/ON | COUNT IN OFF/1 BAR | LENGTH 16/32/48/64 |
| 4/8 LOCKS | TIE ON/OFF | LOCK (parameter name, OFF) | VALUE 0–127 | NOTE |
| 5/8 SYNC/LOOP | CLOCK INT/MIDI | BPM (or MIDI BPM/WAIT/LOST) | LENGTH | CLK IN AUTO/USB/BLE/DIN |
| 6/8 MIDI TRACK | SEQ/ARP LOCAL/BOTH/MIDI | OUT CH | OUT PORT | KEY OUT |
| 7/8 MIDI ROUTING | LOCAL | CLK OUT | THRU IN | THRU OUT |
| 8/8 TRACK ROLE | ROLE NORMAL/PLAY/OFF | IN CH | – | – |

- On pages 2 and 4, white keys **select** the cursor step instead of toggling it.
- On drum tracks, GATE, CHORD, TIE and NOTE show `--`.

### B.5 Panel and LED mapping [C:S4 screen.c]

**Buttons** (enum order): OCT−, OCT+, FX, SCL, ENV, LFO, EDIT, GLO, HOME, SAVE, ARP, SEQ, PLAY, REC.

**Encoders**: [0] SELECT, [1] ALGORITHM, [2–5] K1–K4, [6] PRESETS.

**Step keys**
- `white_keys[16] = {0,2,4,6,7,9,11,12,14,16,18,19,21,23,24,26}`: indices into the 27-key bed.
- The bed starts on F (key 0 = MIDI 53 at octave 0).
- **Step i of the visible page = white key i.**

**Key LEDs in SEQ**
- Lit = active step in the current page. On a drum track this is the selected pad's lane.
- The **playhead is shown by XOR-toggling** its key's LED, so it blinks off on lit steps and on on empty ones.

**Button LEDs**
- SEQ lit on step/action pages; REC lit while recording; PLAY lit while playing; ARP lit when the track's arp is on.
- OCT−/OCT+ lit when an earlier/later page exists.

**Mixer** (tap GLO):
- White keys 1–8 toggle mute of tracks 1–8; white keys 9–16 toggle solo. Their LEDs show the state.
- K1–K4 set the volumes of the current group of 4 tracks.

**Long-press threshold** = 600 ms, with a progress bar at y = 27 under the header.

### B.6 Screen layouts (240×240 RGB565 LCD) [C:S4 screen.c]

**Palette**

| Role | Colour |
|---|---|
| BACK | #000000 |
| PANEL | #181C18 |
| TEXT | #EEEAEE |
| ACCENT | #00FFFF |
| DIM | #737173 |
| GREEN (playhead) | #00FF00 |
| AMBER (pending/record) | #FFA500 |

Track colours T1–T8: #3991FF, #00F6FF, #4AD673, #00DAA4, #AC91FF, #EEA1C5, #FFE231, #FF7529.

**Header** (y 0–29; on every music page):
- BPM, large, at (8,8), with a "BPM / USB / BLE / DIN / EXT / WAIT / LOST" label.
- PLAY / PAUSE / STOP.
- Play step `NN / len`.
- 4 small page bars (green = page being played).
- `FOLLOW` (green) or `EDIT` (amber).
- `*` if the project is dirty.
- Right-hand mode chip:
  - Amber chip: `STEP`, `REC` or `CNT n`.
  - Otherwise: `ARP` or `LIVE`.

**HOME overview**
- Project name, "OPEN V14", PAGE a–b.
- **8 rows of 18 px**, each with:
  - A coloured track-number chip with a MIDI activity dot.
  - The sound name (DX7 patch name / 303 SAW / 808 KIT / PSG YM / PLUCK / SAMPLER) and a status line (MUTE / SOLO / EDITED / PLAY / OFF).
  - **16 mini step cells** (6×11 px at x = 80 + 8i), filled with the track colour when active.
  - A green cap on the playhead cell and a white cell for the cursor.
  - A level meter at x = 216 and a volume number.

**SEQ steps page**
- Title "T1 KICK" (drums: the selected pad name) or "DX7 / 303 / PSG / PLUCK STEPS".
- `LEN 64`, or `NEXT nn` in amber when a length change is pending.
- 4 page tabs "1-16 | 17-32 | 33-48 | 49-64": current tab filled with the track colour, out-of-length tabs blank.
- **4×4 tile grid** of 53×25 px tiles from y = 72:
  - Step number.
  - Note name, `HIT` (drums), or `-`.
  - Active tile filled with the track colour.
  - Cursor = white outline; playhead = 3 px green bar on top.

**Footer**
- Strip at y = 186 with the page name ("1/8 BASIC") and "ALGO PAGE". On the LOCKS page it shows the locked parameter name instead.
- **4 knob slots** (x = 6 + 59·col, y = 195): colour bar, label, value (large if 4 characters or fewer).
- Hint line at y = 231 (e.g. "PRESETS STEP  OCT PAGE  HOLD SEQ MORE").

No device photos of the FM1 Open screens were found. The workbench renders these screens live in-browser (WASM), but it is JS-only and I did not run it.

### B.7 DRUM 808 kit [C:S4 drum808.c, sound.c]

**Synthesis**
- C port of **DaisySP / Plaits analog drum models** (MIT; Electrosmith / Émilie Gillet), plus M-VAVE additions.
- Kick: pulse-excited resonant SVF with FM "attack" and a diode/tone path.
- Snare: two-mode shell plus snappy filtered noise.
- Toms/congas: sine with pitch sweep and harmonics.
- Rim/clave: two sines plus a noise click.
- Clap: 3 bursts 10 ms apart, then a noise tail through BPF.
- Cowbell: two squares (540/810 Hz × tune) through BPF.
- Hats/cymbal: 6 square oscillators at metallic ratios (207/307/370/524/544/807 Hz) through BPF/HPF.
- **Choke:** KIT Choke OFF / CH>OH / BOTH.
- Per-voice drive: 7 modes (DIODE, CLIP, SAT, BFZ, PDIST, FOLD, CRUSH).
- Per-voice pan and reverb/delay sends. Polyphony is limited to 1–11 sounding parts (oldest tails retire first).

**Parts and key mapping**

| Pad | Name / label | MIDI note (also accepts) | Alternate sound | Parameters |
|---|---|---|---|---|
| 0 | KICK BD | 36 (35) | – | Level, Tone, Decay, Tune, Attack, Drive, Dist, Pan |
| 1 | SNARE SD | 38 (40) | – | Level, Tone, Snappy, Tune, Decay, Drive, Dist, Rev, Dly, Pan |
| 2 | LOW TOM LT | 41 (43) | CONGA (low) | Level, Tune, Decay, Sound, Drive, Dist, Rev, Dly, Pan |
| 3 | MID TOM MT | 45 (47) | CONGA (mid) | same as LT |
| 4 | HIGH TOM HT | 48 (50) | CONGA (high) | same as LT |
| 5 | RIM | 37 | CLAVE | same as LT |
| 6 | CLAP | 39 | MARACAS | Level, Tune, Decay, Attack, Sound, Drive, Dist, Rev, Dly, Pan |
| 7 | COWBELL COW | 56 | – | Level, Tune, Decay, Drive, Dist, Rev, Dly, Pan |
| 8 | CYMBAL CYM | 49 (51) | – | Level, Decay, Tune, Drive, Dist, Rev, Dly, Pan |
| 9 | OPEN HAT OH | 46 | – | same as CYM |
| 10 | CLOSED HAT CH | 42 (44) | – | Level, Tune, Decay, Drive, Dist, Rev, Dly, Pan |
| KIT | KIT | – | – | Level (def 100), Accent (def 127: velocity sensitivity), Choke |

All parameters are 0–127 and default to 64 unless noted in the source.

**Keyboard on an 808 track**
- `groove_key_note(key) = drum_notes[key % 11]`. Keys 0–10 (F up to D#, chromatic, white and black) play BD…CH, and the mapping **repeats every 11 keys** [C:S4 sound.c].
- **[I]** For an iPad UI, a 4×3 pad grid is the cleaner choice.

**Velocity:** `accent = 0.5·(1−Accent) + velocity·Accent`. Accent 0 means velocity is ignored.

### B.8 SAMPLER (8 pads) [C:S4 sampledrum.h, sample_metadata.inc; S6 §07]

**Pad mapping**
- Pads map to MIDI notes {36, 38, 37, 41, 47, 48, 42, 46}.
- They play from the first 8 white keys.

**Parameters per pad** (6, all lockable):
- Level, Tune ±24 st, Length (1/128 steps)
- Choke group 0–4
- Variation 0–3: a 4-hit cycle of pitch/gain/start changes, for round-robin feel
- Vel LPF: softer hits sound darker

**Memory**
- One shared bank of 466,944 bytes, **about 19.55 s**, SEA codec at 228 bytes per 320 frames.
- 24 voices.
- WAV import is only through the workbench.

### B.9 Other engines' sequencer interactions [C:S4]

**303** (Open303 port):
- Parameters: Cutoff, Reso, EnvMod, Decay | Accent, Wave Saw/Sqr, Tune, Volume | Drive, DrvType Off/Soft/RAT, Slide, AccDec.
- **Accent = step velocity ≥ 100.**
- **Slide** happens in MONO mode when a new note starts while another is still held. In the sequencer that means a **tied step, or a gate of 100% that overlaps the next note** [C:voices.c `slide = b->count != 0`] [I: a gate of exactly one step overlapping depends on note-off ordering].
- POLY mode = 4 voices, no slide.

**PSG:**
- Modes YM / AY / NOISE / MIX; 8 voices (emu2149).
- Useful for chip drums [I].

**Pluck:** Karplus-Strong string with DECAY, BRIGHT, TUNE, RELEASE.

### B.10 Arpeggiator / drum repeat (per track) [C:S4 screen.c, sound.c; S6]

**Controls**
- Tap ARP = on/off; hold ARP = settings.
- Page 1: RATE 1/4, 1/8, 1/16, 1/32 (24 PPQN: 24, 12, 6, 3 ticks); DIRECTION UP / DOWN / UP-DN / RANDOM; RANGE 1–4 octaves; GATE 25/50/75/100%.
- Page 2: SWING 0–50%; HOLD (latch).

**On 808/Sampler tracks** it acts as **drum repeat**:
- Holding pads retriggers them at the rate.
- RANGE and GATE are disabled.

**Clock and storage**
- Runs from the internal tempo even while stopped.
- Saved per project.

### B.11 Swift implementation notes (FM1 Open-style rhythm)

```swift
enum Engine { case dx7, bass303, drum808, psg, pluck, sampler }
struct Step {                         // mirror of groove_step; 4 bytes
    var note: UInt8 = 60              // drums: probability in high nibble
    var velocity: UInt8 = 0           // 0 = empty (melodic)
    var bits: UInt16 = 0              // melodic: chord|gate|prob|tie|alt ; drums: pad mask
}
struct Track { var engine: Engine; var length: Int /*16,32,48,64*/; var pendingLength: Int?
               var steps = [Step](repeating: .init(), count: 64); var role: Role }
struct PLock { var track: Int; var step: Int; var param: Int; var value: UInt8 }   // max 16
struct Project { var tracks: [Track]; var chords: [[UInt8]] /*16*/; var locks: [PLock]
                 var tempo: Int; var swing: Int /*0...50*/; var metronome: Int; var countIn: Bool }
```

**Clock**
- Use one 1/16 tick shared by all tracks. Each track keeps `current = tick % length`, and `length` is re-read only when the track wraps to step 0. This gives polymeter.
- Run the clock on the audio thread, using sample-accurate block phase like `groove_sequence_render`: `phase += tempo*4*frames` and step when `phase >= 60*sr*(100±swing)/100`.

**Per step, per track**
1. Restore the previous lock.
2. Apply this step's locks.
3. Roll probability.
4. Drums: hit every pad bit, with velocity (0 → 100).
5. Melodic: build chord notes, keep notes shared with a tied previous step, and release the others.
6. Schedule note-off at `stepPeriod*gate/16`. Ties suppress the note-off.

**Ratchet**
- FM1 Open has **no ratchet**; V16 does. If you add ratchet to an Open-style model, there is room in the drum cell's unused low nibble of `note` and in the 2 reserved melodic bits (14–15, values 0–3 → ×1–×4) [I].

**Panel mapping on iPad** [I]
- 16 white-key buttons = steps.
- OCT± = page.
- PRESETS = cursor; K3 = pad/note; ALGORITHM = page selector.
- The real panel lacks dedicated pads, so the per-pad lane model (one pad edited at a time, as in a TR-style workflow) is what the hardware uses.

**Scope advice** [I]
- The cheapest addition with the biggest payoff for a stock-faithful app is **V16-style 64 steps + ratchet + 8×8 arrangement**, because it stays within stock behaviour.
- A drum engine is an FM1 Open feature. Add it as an opt-in "groovebox mode" using the 808 table above. DaisySP is MIT, so it is reusable with attribution; check THIRD_PARTY.md first.

---

## C. Images downloaded (`research/images/firmware/`, prefix `official_`)

| File | Content | Firmware |
|---|---|---|
| `official_v16_natlife_video_YG_VAYJFlB8.jpg` | YouTube thumbnail of the NatLife "V16 official firmware" demo [S3]. White FM-1 in warm light. LCD shows a dense dot-matrix (64-step) grid under a "PLK Cosmic…" title. SEQ button green, several white-key LEDs lit. | Stock V16 |
| `official_v16_natlife_video2_g0MQwvhUXPU.jpg` | Thumbnail of "Do you really need custom firmware anymore?" (V16) [S3]. LCD shows a preset title ("…Monstro"), a dotted indicator row and a K1–K4 parameter row. HOME and SEQ lit. | Stock V16 |
| `official_open_synthtopia_fm1.jpg` | Header image of the Synthtopia FM1 Open article [S7]. It is actually a **stock V15 FX page** render ("001 PIANO 1", Filter / Reverb / Delay / Distortion / Chorus / Phaser tiles, "Type: Low Pass"), **not** an FM1 Open screen. It is useful as a clean panel and legend reference. | Stock V15 (illustration) |

No official screenshots of the V16 SEQ or arrangement pages, or of any FM1 Open screen, were found. The FM1 Open layouts in B.6 are reconstructed from `screen.c` drawing coordinates [C].

---

## Sources

- **S1:** M-VAVE forum, "M-VAVE FM-1 Official Firmware Update Summary".
  - https://forum.m-vave.com/topic/23
  - API: https://forum.m-vave.com/bbs/api/forum/topics/23
- **S2:** Official release notes (V09 → V16): https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1.txt
- **S3:** matrixsynth posts embedding the NatLife Sounds videos (YouTube YG_VAYJFlB8 and g0MQwvhUXPU):
  - https://www.matrixsynth.com/2026/10/m-vave-fm-1-official-v16-firmware.html
  - https://www.matrixsynth.com/2026/10/m-vave-fm-1-do-yoou-really-need-custom.html
- **S4:** https://github.com/m-vave/fm1_open (main branch, commits through 2026-10-21; release tag V14)
- **S5:** https://www.m-vave.com/download (firmware `FM-1.fwsc`, release-note txt, MIDI docx; no V16 manual link found)
- **S6:** https://open.m-vave.com/fm1-workbench (FM1 Workbench; built-in 10-chapter manual, Chinese UI text)
- **S7:** https://synthtopia.com/content/2026/10/20/m-vave-officially-opens-fm-1-firmware-to-developers-with-new-workbench-sdk
- **S8:** https://forum.m-vave.com/bbs/api/forum/topics/4 ("FM1 Open: Eight-Track Synthesis and Sampling…")
