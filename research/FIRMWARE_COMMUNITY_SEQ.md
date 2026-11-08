# FM-1 community firmwares: sequencer and rhythm features

Scope: third-party and community firmwares for the M-VAVE FM-1. M-VAVE's own V16 and FM1 Open are covered elsewhere. The goal is to decide which sequencer and drum features the iPad recreation (stock V15, see `FUNCTION_SPEC.md` sections 6 and 12) could adopt as optional extras.

Compiled 2026-11-08. Method:
- Every firmware in the index [cicloid/awesome-fm-1](https://github.com/cicloid/awesome-fm-1) was reviewed: about 230 entries, of which about 190 are synth or music firmwares.
- The [fm1-editor.com firmware directory](https://fm1-editor.com/firmware/) was cross-checked for extras.
- Other sources: Sonic State, Synth Anatomy and the [Elektronauts thread](https://www.elektronauts.com/t/m-vave-fm-1/252170).
- About 90 READMEs were read as text. Where a README was thin, the manual, wiki or site was read as text too.
- No code was downloaded or run.
- Screenshots were saved to `research/images/firmware/` (65 files; section 6 lists them).

Tags:
- **[C]** means confirmed: the project's own README, manual, wiki or site states it.
- **[I]** means inferred by us, or the sources conflict.
- Most firmwares are 2026 betas and change weekly. Versions are as of 2026-11-08.

Panel words used below: **white keys** are the 16 white keys (F3 to G5 at octave 0). **Black keys** are the 11 black keys, B1 to B11 from left to right. **K1 to K4** are the four knob encoders. Encoder and button names follow `FUNCTION_SPEC.md` section 2.

---

## 1. Key takeaways

1. **The community has settled on a common panel grammar for sequencing on the FM-1.** Felucca, SLOOP, Skiff, Hortator, KARMA, Tonic, SEQ-4, X0X and others use nearly the same mapping [C]:
   - **The 16 white keys are steps**, and OCT− and OCT+ page through 64 steps.
   - **The black keys select the drum lane or track**, and in some firmwares the page.
   - **Hold a step and turn K1 to K4** to edit that step's attributes (note, velocity, ratchet, nudge, chance) or to set parameter locks.
   - **Hold a button for a "layer"** that temporarily remaps keys and knobs:
     - Hold GLO: keys 1–4 mute, keys 5–8 solo, key 9 is fill while held, key 10 is fill on the next bar, the last key is tap tempo.
     - Hold SAVE: song sections A–D.
     - Hold FX: punch-in effects on the white keys.
     - **Double-tap** a button to latch its layer.
   - This maps cleanly onto an iPad version of the FM-1 panel without inventing new hardware. It is the strongest single recommendation.
2. **Common feature set**, now a baseline in about 30 firmwares [C]:
   - 4–8 tracks × 64 steps, with a per-track LENGTH and DIV (polymeter)
   - chords of up to 4 notes per step
   - per-step chance, Elektron-style trig conditions (A:B, FILL/!FILL, PRE, NEI, 1ST) and ratchet ×2–×4
   - micro-timing nudge in 1/64ths, p-locks and recorded knob motion
   - song sections A–D, or a section/scene list
   - an 8-lane synthesised drum engine on the GM key map with several kits
   - EUCLID and RANDOM in a "SEQ TOOLS" menu
3. **Best references for adoption**, in order:
   - **Felucca / SLOOP**: the canonical baseline grammar.
   - **Skiff**: the most complete and coherent Elektron-style sequencer.
   - **KARMA**: generators plus a beautifully readable 4-track UI, with a Grids/Euclid drum generator.
   - **JIANT FM / DRUM-X**: the deepest, but complex.
   - **Hortator**: the best pure drum machine.
   - **Tonic**: Digitone-style, with the best Euclid-on-a-kit.
   - **X0X**: a ReBirth model with probability on the SELECT wheel.
   - **Ravel**: experimental: graph sequencer, per-lane polymeter inside a kit, ratchet curves.
   - **FM-1+VA**: the closest to stock V15. It extends the stock 16 × 16 sequencer to 16 × 64 with ratchet, chance, locks and a Flow view, so it is the most natural "V15 Plus" mode for our app.
4. **Drum UX ideas that are unusual and worth stealing:**
   - JIANT's octave-as-articulation: OCT +3 = ratchet ×2, +2 = repeat every step … −2 = ghost, −3 = flam.
   - Hortator's per-track REPEAT STEP pads.
   - PERF-1's Density knob, which thins hits by metric weight.
   - BB1's EVOLVE-and-return with per-attribute masks.
   - Jangada's "pick a kit, get its genre beat and fill".
   - Tonic's Euclid STYLE presets (tresillo, son clave, bossa).
   - Ravel's per-lane length and rate inside one kit.
   - Mutable Grids X/Y map generators, in KARMA, Araminta, X0X-RMX, Hortator, Optimist and SEQ-4.
5. **Generative and self-playing** firmwares are a separate family:
   - AMB-1 → HYP-1 → PERF-1 / DUB-1 / IND-1, plus Tuna, Makohai, Berlinan and MAKU.
   - Useful ideas: coprime loop lengths, "freeze the generator into editable steps", seeded and shareable randomness, and bar-quantised pending actions shown by blinking keys.

---

## 2. Comparison table (sequencer and rhythm firmwares)

Legend:
- Y = yes [C]. – = not mentioned or absent. (i) = inferred.
- Len/trk = independent length per track (polymeter).
- Cond = trig conditions (A:B, FILL…).
- Ratch = ratchet or retrig.
- Lock = parameter locks.
- Motion = recorded knob motion.
- Micro = micro-timing or nudge.
- Gen = generative or random part writers beyond simple RANDOM.
- Take = after-the-fact loop capture or free-tempo looping.
- Base: F = Felucca, S = SLOOP, D = Dinghy, fb = fm1-base, A = AMB-1, X = X0X, own = written from scratch.

| Firmware | Base | Tracks | Steps | Len/trk | Song / chain | Chance | Cond | Ratch | Lock | Motion | Micro | Euclid | Gen | Take | Drum engine / kits | Swing / groove |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **FM-1+VA** (closed) | stock V15 | 1 pattern (4 lanes on 8-bit) | 64 | – | Chain + Repeats | Y | – | ×2–4 | Y (4/step) | – | – | – | – | – | 8-bit: 12 drums + choke | Swing 50–75 |
| **Groove OS** (paid, closed) | stock V15 | 8 | Y | Y | chains | ? | Y | ? | Y | Y | – | – | DICE | Y | KIT track, 16 pads | – |
| **Felucca** | own | 4 | 64 | Y | Song 16 sections × slot A–D | Y | Y | ×2–4 | Y | Y (128 list) | 1/16 | tool | RANDOM, COOK | – | DRUM 8 lanes, 9 kits; SLICE | Y |
| **SLOOP** | F | 3 + drums | 64 | Y | A–D + chain, song rec | – | FILL only | ×1–4 | Y (24/trk) | Y | 1/64 | – | – | Y (free tempo) | 16 sounds, 37 kits, SYN, USR | MPC 0–100 |
| **Skiff** | F | 6 | 64 | Y | 64-pattern pool, per-track entry lists A–P, 16 scenes | Y | 12 | ×1–4, flam | Y | Y (64) | 1/64 | tool | RANDOM, COOK | TAKE | DRUM 9 kits + DRUM-X 8, SLICE | Y |
| **KARMA** | S / F | 3 + drums | 64 | Y (LEN) | sections A–D, arranger | Y | FILL/NO FILL | Y | Y | Y (REC) | – | DRUM GEN | GEN, ACID GEN, Grids | Y (free/tempo loop) | HEX (LXR-02), 5 + 4 user kits, 808/909 | arp swing |
| **JIANT FM** | F + S | 6 + DRUM-X | 64 | Y | 8 songs × 4 sections, timeline with per-row variations | Y | Y | ×1–8 shapes | Y | Y | ±32/64 | page | GEN 43 genres, MUTATE, playheads | Y | DRUM-X 8 voices, A/B morph, 9 kits | per track |
| **Araminta** | F + JIANT | 4 | 64 | Y | 16 sections | Y | Y | ×2–4 | Y | Y (list) | 1/16 | tool | Grids, COOK | free take | DRUM-X, Felucca DRUMS, CR-78 | Y |
| **Hortator** | F | 8 | 64 | Y | Song 16 rows, 4 slots × 8 variations | PROB | FILL/!FILL | Y | Y | Y (1024) | ±50/100 | Grids | Grids | REC ALL | 808/909/Plaits + samples, 151 presets | per track |
| **MNM-1 (galfaroth)** | Hortator | 6 | 64 | Y | SONG | Y | A:B | Y | Y (240) | Y | – | – | – | – | DKICK/DSNAR/DHAT/DCYMB | swing masks |
| **MONO2K** | own (F loader) | 6 | 64 | Y + speed | 4 × 16 patterns | Y | Y (1ST/PRE/FILL) | ×1–4 | Y + trigless | – | – | – | Grids lanes | – | LXR-style KICK/SNAR/HATS/CYMB | Y |
| **Tonic** | fb | 4 | 64 | Y + speed | chains, song 32 rows | Y | Y (full Digitone) | retrig 1/1–1/80 + fade | Y + sound locks | – | ±23/384 | Y (STYLEs, per pad) | – | – | DRUM 8 pads, 31 models | Y |
| **LOOM-8** | fb | 8 | 64 | Y (scale) | 32 scenes, song | Y | A:B | tricks | Y | – | nudge | – | WEAVE, conductor | – | 11-sound kit, 11 + 8 kits, slicer | 11 groove types |
| **FIZZ** | ChoralRoot | 8 (or 6, i) | 128 | per page | not built yet | Y | Y | ×1–8 ramp | Y | – | ±23/24 | tool | RANDOM, GRIDS, HUMANIZE | Y | – (GRIDS writes drums) | – |
| **Ravel** | F / X | 8 | 64 | Y + rate | 16 scenes (glide), 32-row arrangement, density arcs | Y | Y | ×1–8 curve/move | Y (2/step) | Y | 1/24 | Y | GRAPH 2 heads, LFO clocks | TAKE | PERC 33 MD-style machines, 6-lane kits with own length | swing + clock bend |
| **Jangada** | F | 4 | 64 | Y | – | Y | FILL/NO FILL | ×1–4 | Y (12) | – | 1/64 | VIVO PULS | VIVO (cellular automata, seed) | – | 42 kits, **49 genre beats + fills** | Y |
| **Melodee** | F | 4 + 4 MIDI | 64 | Y | 64 sections, jam-to-song | Y | – | – | – | Y (64) | unquantised | – | AUTO harmoniser | Capture | 808/909/SID/CR78/FM kits | per song |
| **Argo (Felucca 8 Patterns)** | F | 4 | 64 | Y | per-track chain of 8 sequences | Y | Y | Y | Y | Y | Y | tool | GEN arp (DENS/EVOLVE) | – | SH-TONE, DRUM-X | Y |
| **Loom FM-1** | F | 4 + D | 64 (4×4 / 8×8) | Y | 16 sections | Y | Y | ×2–4 | Y | Y | Y | arp gating | chord-progression gen | – | DRUM track, choke, ANLG/FM kits | swing + humanize |
| **DIRGE** | F | 4 | 64 | Y | chain | Y | Y | Y | Y | Y | Y | tool | – | TAKE | Felucca DRUM (i) | Y |
| **Mini-Tone** | F | 6 | 64 | Y | 16 sections | Y | FILL | per note | Y | Y | 1/64 | A op B (AND/OR/XOR) | STOCHASTIC (seed, reroll) | – | DRUM, FMDRUM, TR808 | Y |
| **Caravel** | F | 4 | 64 | Y | Felucca songs | Y | Y | Y | Y | Y | Y | Y | – | – | DRUM + DRUM-X | Y |
| **FM1 Move** | S | 8 | 64 | Y | 6 clips/track + scenes | – | FILL | – | Y | – | Y | – | – | – | multiple kits | **8 groove templates**, quantize strength |
| **ORBIT** | S | 3 + drums | 64 | Y | A–D, chain of 8, **Event Tape** | – | FILL | Y | Y (24) | Y | 1/64 | – | – | Y | SYN1–4, 16 voices | Y |
| **MC-1** | own (ORBIT HAL) | 3 + 16-lane drums | 16 | – | 64 patterns, 128-entry song | – | – | – | – | Y (384) | – | – | – | – | 8 kits | Y |
| **zp12** | S | 32 pads, 8 ch | 1–32 bars | – | 16 loops, 4 songs | – | – | – | rec. knob locks | – | quant | – | – | overdub | SP-12 sampler, choke by position | Y |
| **Optimist** | S | 4 | 64 | Y | 16 pat/trk, scenes A–P | Y | Y | ×1–4 | Y | Y | 1/64 | gen | RANDOM/PULSE/GRIDS, REPLACE/ADD/MASK | – | 39 kits, X0X 808/909 | 50–75 |
| **SPIRALFM1 / MYCELIUM** | S | 3 + drums | 64 | Y | 240-bar factory songs | per track | FILL | Y | Y | Y | Y | – | – | Y | 40 psy kits | genre grooves |
| **NoteSorcery** (host only) | S | 8 (2 drum) | 64 | Y | song | fill chance | Y | Y | Y | – | Y | – | TB-3PO | – | 808/909 CM, MD kits | Y |
| **X0X** | F | 5 parts | 64 | Y | 32 patterns, 192-bar song | Y (5–100) | A:B | break only | Y (160) | Y | – | – | TB-3PO seed | – | 909 (11), 808 (11), break slicer | 50–75 |
| **X0X-RMX** | X | 5 | 64 | Y | Banks A–P × 16 per part, Remix | Y | Y | – | Y | Y | – | Grids EUCLID | Grids MAP, TB-3PO | – | 909/808/break | Y |
| **MORPHEUS** | X/F | 8 | 32 | Y + res | 16 pat/trk | – | – | – | CURVE lane | – | – | – | Randomize | – | 808/909 12-lane matrix + ACC | 0–75 |
| **TRIBE** | X | 10 | 16/32/64 | Y | 64 clips/trk, follow modes | Y | – | – | – | – | – | – | – | Capture 32 notes | KICK/909/808 voices any track | per clip |
| **BB1** | F | KIT A, KIT B, acid | 16 × banks | – | sections, song arranger | – | – | ×1–4 | – | – | – | Y | EVOLVE, RANDOM | keep/discard take | 808 + 7 sampled vintage machines, 539 rhythms | per kit |
| **FOMAJAM** | foma | 9 | 16 | – | 40 patterns | – | – | ×1–8 | – | – | – | – | – | – | 808/909/SDS-V/CR-78 + 9 ROM machines | Y |
| **UNIBOX** | FOMAJAM | 9 | 16 | – | 16 patterns, chain | – | – | ×1–8 | – | – | – | – | – | free take, tempo detect | as FOMAJAM + sampler | Y |
| **DREADNOUGHT** | X | 8 | 64 | Y (bars) | song 64 rows | Y | full Digitakt | retrig + fade | – | – | – | – | – | – | break chopper, 16-pad sampler | Y |
| **CHOPPAH** | fb | break + 3 lanes | 32 / 16 | – | 16 patterns | – | – | ×1–4 | – | – | – | Y (FILL + ROTATE) | break generator | – | 8 classic breaks, gabber kick | Y |
| **BEETLE / BEETLE BLUE** | F/ETCH | 6 lanes | 16 | BLUE: per lane | song 64 positions, per-channel source | Y | – | Y | – | – | Y | – | – | – | 14 PCM + MONOLITH + user kits | Y |
| **KAWA / K-WASUB** | D | 6 / 8 | 16–64 | – | chain × N | Y | Y | tables | Y | Y | – | MAGIC | MAGIC | – | 8 kits, breaks | GROOVE tables |
| **Bigorna** | F/S | 6 (+4 subtracks) | 16 | Y + clock | 16 patterns | Y | Y (Digitone II) | ×2–8 | Y | – | – | phrase shapes | PHRASE by role, MUTATE | looper | 3-op FM drum, 29 families | per track |
| **BBL JAM BOX** | F | 6 | 16 | – | – | Y | Y | beat repeat | Y | – | – | – | – | – | 4-op FM, 808, sampler | – |
| **PERF-1** | HYP-1 | 5 parts, 6 drum lanes | 16 | Y (lane) | phrase chains, auto-DJ | Y | Y | x2–6, flam, swell | – | – | Push | Y (per lane) | Density, drift, acid gen | – | 14 kits | Feel, humanize |
| **HYP-1 / DUB-1 / IND-1** | A | 6 / 5 drum lanes | 16 | – | pieces, 8-bar arrangement | DUB: Y | – | – | – | – | – | Y | drift, mutate | – | 8 kits | Y |
| **AMB-1** | fb | gen | – | coprime loops | – | – | – | – | – | – | – | 3 rings (16/12/7) | Y | – | 3 drums | 50–75 |
| **SEQ-4** (MIDI only) | LCD-4 | 4 × (8 drum tracks) | 128 | Y | 10 songs × 4 lanes × 15 | Y | Y | ×1–5 | CC lanes | – | ±45% | Y | Grids, Stochastic | Capture 256 | (MIDI) | Y |
| **DriftSeq** (emu only) | own | 16 | 64 | loop window | chain 64 | Y | 11 | – | – | – | – | Y (non-destructive) | seed | – | (GM monitor) | Y |
| **fm1-t1** (WIP) | F | 6 × 6 cycles | 64 | Y | 6 × 6 patterns | Y | – | ×1–16 pace | Y (11) | – | – | Y | Torso-style | – | – | G0–G15 templates |
| **LCD-4** | IND-1 | 4 | 16 | – | 16 patterns, chain 64 | – | – | Y | Y (2) | – | – | – | – | – | 4 kits × 11 | Y |
| **OberVave** | S-style | 4 | 256 | Y | 8 patterns, clip launch | Y | – | ×1–4 | – | Y (4 knobs) | Y | – | – | – | – | Y |
| **Ketch / MOONDAW / MASIF** | F/D | 4 / 8 / 4 | tracker | – | song → chain → phrase | cmd | – | RET cmd | cmds | – | DLY cmd | – | – | – | Felucca DRUM 10 kits (MOONDAW) | cmd |
| **Polly / HERA** | fb / D | 8 GM parts / 1 | 16 bars / 64 | – | 4 songs × 32 sections / 64 patterns | – | – | – | – | – | – | – | style arranger | groove rec | GM kit (Polly) | Y |
| **ChoralRoot** | F | looper 10 slots | 1–16 bars | Y | – | Y | Y | ×2–4 | – | – | quant | – | – | 5 rec modes | – | – |

---

## 3. Per-firmware sections, most relevant first

### 3.1 FM-1+VA (Baud Girl), the closest to stock V15
- **Author and links:** Madeline / Baud Girl. Site <https://baudgirl.com/work/FM-1+VA>, manual <https://baudgirl.com/work/FM-1+VA/manual>.
- **Version:** FM-1_102, manual dated 2026-10-19. Earlier versions mentioned are 83, 94, 96, 98 and 101 [C].
- **Licence:** closed source and free. The author has said the source will be released [C, per awesome-fm-1].
- **Base:** the stock firmware, keeping the FM engine. Adds a VA engine (Sine/Saw/Tri/Square with Super/Detune/Drift) and an "8-bit" engine [C].
- **What it changes:** a cleaner menu, eleven knob banks (Preset, seven FX, Global, Mixer, MIDI CC; hold HOME + turn SELECT), and four assignable knobs per preset [C].

**Sequencer** [C, manual sections 9.x]:
- 16 patterns of up to 64 steps, with up to 9 notes per step. A chord goes in whole.
- Two views, set by Sequencer View in GLOBE:
  - **Lane**: 16 steps per page, one lane per part. FM and VA presets have Notes + Locks; 8-bit presets have Lead, Bass, SFX, Drums + Locks. ALGORITHM turns pages.
  - **Flow**: all 64 steps as an 8 × 8 dot grid.
- **Step settings:**
  - Chance: Always, then 95…5.
  - Ratchet: Off, 2, 3, 4.
  - Accent: velocity 127.
  - Tie & Slide: overlapping notes slide on mono presets with glide.
  - Gate: Pattern, or 5–100.
- **Locks:** hold SEL and turn K1–K4 while step recording. Up to 4 locks per step. A lock applies from its step's start, and the next step without that lock returns to the preset value. Preset knobs and FX amounts can be locked; FX type and global settings cannot. On FM a lock applies to notes starting on that step; on VA, 8-bit and FX it applies immediately.
- **Pattern settings:**
  - Steps 1–64
  - Timing: Rate 1/1–1/32T, Swing 50–75, Gate 5–100
  - Transpose: applies to all 16 patterns
  - Chain: next pattern, or repeat
  - Repeats: 1, 2, 3, 4, 6, 8, 12, 16
  - Preset per pattern, or Off
  - Copy and Paste
  - Time Multiplier: Stretch 2×, 2× in place, Squeeze ½×, ½× in place
  - Copy Repeater: duplicates to fill up to 64
  - Clear
- **Recording:**
  - Step recording: REC, then play. Notes add and never replace; playing the same note again removes it.
  - Real-time recording: PLAY, then REC. Notes land on the nearest step with velocity. Hold SEL + a key to erase that note over one pass.
  - On Flow, hold SEL + ALGORITHM to move a step and SEL + SELECT to copy it.
- **Patterns and MIDI:** hold SEL + turn PRESETS to pick the next pattern; while playing it is queued, shown as "1 > 2". Hold PLAY 1 s to switch the Sequencer on or off. MIDI clock out has three modes (Off/Always/Playing). Seq output is Int, Ext or both, with a seq channel.

**Drums** [C]:
- 8-bit presets have 12 drums on F0–E1 (octave −3). Each has Wave, Pitch, Sweep, Decay, Level, Snap and Choke group A/B/C.
- 12 SFX sit on F1–E2.
- A Drum Decay macro and a Drums Level on the Mixer bank.

**Screens** (240 × 240, matching the hardware TFT):
- `fm1va_SEQ.pattern.8bit.png`: the Lane view with Lead/Bass/SFX/Drums/Locks lanes as pink bars, beat columns 1/5/9/13 brighter, and a white outline cursor column.
- `fm1va_SEQ.flow.play.png`: the Flow 8 × 8 dot grid. Filled dots hold notes and outlined dots are empty. Bars join tied notes, wavy lines mark slides, split dots mark ratchets, and a white dot marks a lock.
- `fm1va_SEQ.step.png`: "Step 1 Settings", listing notes with velocity bars, Length 1/16, Ratchet Off and Gate Pattern.
- `fm1va_SEQ.lane.drums.png`: a drum lane opened with rows F0…E1 and pink hits; ratchets show as split cells.
- Also saved: `fm1va_SEQ.pattern.png`, `fm1va_SEQ.pattern.64.png`, `fm1va_SEQ.flow.png`, `fm1va_SEQ.lane.locks.png`, `fm1va_SEQ.step.locks.png`, `fm1va_SEQ.timing.png`, `fm1va_SEQ.chain.png`, `fm1va_EDIT.8bit.drums.png`.

**Why it matters:** it keeps the stock look and V15 workflow (PLAY, REC, SEL, SELECT for steps) and extends them. It is the least disruptive "advanced sequencer" option for the app. Virtual-FM-1 (section 4) already reproduces this sequencer in software [C].

### 3.2 Felucca (Hügelton), the base platform
- **Author and links:** Leo Kuroshita / Hügelton Instruments. <https://github.com/hugelton/Felucca>, wiki manual, web installer and editor.
- **Version:** 1.8.1 stable, 1.8.2-beta for the new flash chip. Active development has ended; it now gets maintenance only [C].
- **Licence:** GPL-3.0-only (engines MIT, bsp MPL-2.0) [C].
- **What it is:** 4 tracks sharing 8 voices, 13 engines (6-op FM, VA, PD, chiptune, sampler, granular, physical modelling, organ, DRUM, SLICE…) [C].

**Sequencer** [C]:
- 64 steps per track, with LEN per track. DIV runs from 4 bars to 1/32, with SWING and GATE.
- Four project slots A–D.
- SONG: up to 16 sections, each giving a slot or rest per track plus repeats, drawn as a timeline.
- **Per step:** CHANCE, RATCH ×2–4, trig conditions (n:m, FILL), VEL, NUDGE in 1/16 step, chords, ties, accent, slide.
- **Locks and motion:** hold a step + K1–4 = p-lock. All automation sits in one editable list of 128 records.
- **Recording:** live loop with overdub, per-track QUANTIZE on/off, step recording.
- **SEQ TOOLS** (hold SEQ): CLEAR, REVERSE, SHIFT, RANDOM, COOK (small mutation per press), EUCLID (HITS/STEPS/ROT), DOUBLE, HALF. Each tool is one undo.
- 14 arp modes.

**Drums** [C]:
- DRUM engine: 8 lanes on the GM map.
- Kits: STD; VA kits 80/10/66/55/77, hinting at the 808/101/606/505/707; DEEP, TIGHT, PERC.
- On a DRUM track, SEQ TOOLS adds BEAT and per-lane tools.
- The SLICE engine has a break built in.

**Panel** [C]:
- Drum grid: white keys = steps, black keys = lanes.
- EDIT held on a DRUM track: black keys mute lanes.
- SEQ tap cycles STEP → DETAIL → AUTOMATION; SEQ held = TOOLS.
- GLO held = mutes, solos, levels, TAP, FILL.
- SAVE held = undo. OCT+ = confirm. Double-tap a button to latch its layer.

**Screens:** `felucca_controls.jpg` shows the FM-1 panel with Felucca labels. Virtual-FM-1 can run Felucca 1.6.1 from source with its own screen [C].

### 3.3 SLOOP (isod89 / 3dSam), the live-groovebox grammar
- **Links:** <https://github.com/isod89/sloop-fm1>.
- **Version:** 2.8. **Licence:** GPL-3.0. **Base:** Felucca [C].
- **What it is:** a live 4-track groovebox: 3 synths + a drum machine, 12 engines, 37 kits [C].

**Sequencer** [C]:
- 64 steps per track with LENGTH and DIV (1/32 to 2 bars).
- Chords of up to 4 notes, ties and slide. MPC-style swing 0–100.
- Velocity and ratchet ×1–4 per step. Micro-timing in 1/64ths (±½ step).
- 24 p-locks per track. Fill conditions FILL ONLY / NO FILL.
- Song sections A–D, quick chain, song recording.
- **Free-tempo REC:** the length of the first loop sets the BPM; then overdub.
- Note repeat (hold ARP) records as ratchets.

**Drums** [C]:
- 16 sounds on the white keys.
- 37 kits (an acoustic kit in 5 treatments + 32 synthesised), plus USR1–4 sample kits and SYN1–4 drum-synth kits.
- Hit levels GHOST/SOFT/NORM/HARD.

**Panel**, where every button is a held layer [C]:
- Hold SEQ: white keys = 16 steps; K1 sound/note, K2 DIV, K3 SWING, K4 LENGTH.
- Hold a step:
  - K1 note, K2 velocity, K3 ratchet, K4 nudge
  - PRESETS = lock value, ALGORITHM = lock parameter
  - OCT+ = fill condition, or the per-step sheet (RATCHET/SLIDE, NUDGE, FILL, MOVE, COPY, DELETE)
- Drum grid:
  - The keys are the steps of the selected sound.
  - **A black key doubles the white key to its left, for two-finger rolls.**
  - Hold OCT− / OCT+ for ghost / hard hits.
- Hold GLO: keys 1–4 mute, 5–8 solo, 9 fill held, 10 fill on the next bar, 16 tap.
- Hold SAVE: keys 1–4 queue sections A–D, keys 5–8 save them.
- Keys 1/5/9/13 glow to show the beat grid.

**Screens:** `sloop_screens.png` shows nine screens:
- DRUMS GRID: 16 lanes, the keys are the steps.
- DRUMS KIT: a 4 × 4 sound-name grid (KICK, KICK2, SNARE, CLAP, HAT, OPEN, PEDAL, RIM…).
- SEQ LAYER: a 4 × 4 step grid with notes (G2/G3) and K1–4 = NOTE / VEL / RATCHET / NUDGE.
- GLO LAYER: MUTE 1–4 / SOLO 1–4 / FILL / BAR / TAP.
- SAVE LAYER: sections A–D, SAVE A–D, LOOP/REC/CHAIN.
- Also PHYS, FM6, SEL key layer and the visualiser.
- Every screen uses four coloured knob widgets (blue, green, yellow, orange) matching K1–K4.

Forks with the same grammar:
- ORBIT, sloopDX, zp12, SPIRALFM1, MYCELIUM, FM1 Quest, winampFM, NoteSorcery, Optimist, FM1 Move, RED MASS VAMPIRE OS and PHREAK [C].
- KARMA credits SLOOP [C].

### 3.4 Skiff (illuminus5)
- **Links:** <https://github.com/illuminus5/skiff>, site <https://illuminus5.github.io/skiff/>.
- **Version:** v2.2, mature. **Licence:** GPL-3.0-only. **Base:** Felucca 1.1.5. Also runs on the SMK-37 Pro [C].
- **What it is:** a 6-track groovebox with 14 engines and 148 sounds [C].

**Sequencer** [C]:
- 6 × 64 steps, LENGTH 1–64 per track.
- DIV 1/1–1/32, plus triplets and 2 or 4 bars per step.
- Chords of up to 4 notes. Each note has its own length (1–99% of a step, or 1–128 steps), and notes may overlap.
- **Per step:** velocity, accent, slide, chance 1–100%, 12 trig conditions (FILL, !FILL, 1:2…4:4), ratchet ×1–4 or FLAM, nudge −32…+31 64ths.
- Direction FWD/RVRS/PING/RAND.
- P-locks plus 64 motion records, listed together on SEQ › AUTOMATION.
- **Recording:** live overdub. **FEEL** keeps your timing. Count-in. **TAKE** keeps the last loop you played after the fact.
- 8 levels of undo.
- **Patterns and song:**
  - A pattern pool of 64 shared across projects.
  - Each track has its own entry list A–P with REPS, CHAIN and REST.
  - SONG plays the entries looped or ONCE, and an entry can switch the track's sound.
  - 16 scenes.
- SEQ TOOLS: clear, reverse, shift, RANDOM, COOK, EUCLID, double, half.
- 14 arp modes and 16 scales.

**Drums** [C]:
- DRUM: 8 GM lanes, 9 kits, USR1–3 sample kits.
- DRUM-X: 8 synthesised voices, each with A/B patches and MORPH, and 8 kits.
- SLICE for breaks, a 16-pattern slicer, DUCK sidechain.

**Panel** [C]:
- White keys = steps, black keys = lanes.
- Hold a step + K1–K4 = lock.
- PRESETS = step cursor; SHIFT + PRESETS = range; SHIFT + OCT∓ = copy/paste.
- **Hold ARP = PERFORM:** white keys launch entries; black keys stage mutes with quantise LOOP/BAR/BEAT/NOW; K1–4 are throws.
- Hold FX = 14 punch effects.
- Black keys F#3–F#4 mute the 6 tracks in every layer.
- **Hold HOME = SHIFT, plus an on-screen map of every control.**

**Screens:**
- `skiff_step_tiles.png`: the FEEL page. A header shows "1.3 · 124 BPM · FEEL 5". Four parameter boxes read CHANCE 100% / RATCHET X1 / NUDGE 0 / TYPE. Below, 16 tiles numbered 1–16: orange tiles hold the chance value (100, 75, 50), and a small corner square marks a condition.
- `skiff_drum.png`: the drum grid.
- `skiff_song.png`: the SONG page with per-track entry lists.

The LAX-32 and MIAOU firmwares copy Skiff's 6 × 64 sequencer [C].

### 3.5 KARMA (Ariel Muchnik / eatyourgreensstudio)
- **Links:** site <https://eatyourgreensstudio-dotcom.github.io/karma-fm1/>, cheat sheet `emu/cheatsheet.html`. The repo is presumably github.com/eatyourgreensstudio-dotcom/karma-fm1 [I, from the issues link]. Press: [Sonic State 2026-11-02](https://sonicstate.com/news/2026/11/02/karma-turns-m-vave-fm-1into-a-groovebox/).
- **Version:** 3.0.4, hardware-tested. **Licence:** GPL-3.0-only [C].
- **Credits:** SLOOP, Felucca, X0X, FM-106, Melodee, JIANT FM, Mutable Instruments, and Erica Synths' LXR-02 [C].
- **What it is:** a four-track groove machine:
  - T1 = ACID (303) or JUNO (106)
  - T2 = ELEMENTS (physical modelling)
  - T3 = PLAITS (24 models)
  - DRUM = HEX (LXR-02 voices)
  - The FM-1 shows up as a class-compliant 6-channel USB audio stems device [C].

**Sequencer** [C]:
- 64 steps per track, chords of up to 4 notes, accent and slide FLAG per step.
- Per step: chance, plus NORMAL / FILL ONLY / NO FILL / CHANCE conditions (hold SEQ + step keys + OCT+).
- PLAY page: direction FWD/REV/PEND/RAND/WALK, CHANCE (how often "?" steps play), JUMP (random octave up), STRIDE 1–7.
- Song sections A–D. Hold SAVE: keys 1–4 play A–D, keys 5–8 store the loop into A–D.
- **REC:** free or tempo loop of 1, 2 or 4 bars, with count-in. Hold REC to clear a track, with a filling ring as confirmation.
- Undo/redo is EDIT + OCT− / OCT+ and also covers the generators.

**Generators** [C]:
- **GEN** writes a part per role from one HARMONY:
  - KEY, MODE (MIN/DOR/PHRY/MAJ/MIX), PROG (DRONE i, SWAY i–bVII, DEEP i–iv, EPIC, POP, MOOD), BARS 1/2/4.
  - Roles: T1 = bass (one acid rhythm on the root), T2 = long chord line, T3 = lead motif on chord tones.
  - DRIFT sets how much the part varies. DENS, RANGE, OCT, ACC and SLIDE shape it.
- **ACID GEN:** TB-3PO with DENS/ACC/SLIDE/SEED/SCALE/OCT/ROOT/VARY.
- **DRUM GEN:**
  - MODE MAP (Mutable Grids: MAP X / MAP Y over 25 grooves, CHAOS) or EUCL (KICK/SNARE/HATS density, ROT).
  - Writes only the KICK, SNARE and HAT lanes; the other lanes stay yours.

**Drums** [C]:
- HEX models DRUM, SNARE, CLAP, CYM, HAT, with osc, AEG, mod, click transient, filter and distortion pages.
- Kits: HEX BOOM, ACID, METAL, GLITCH, ROOM, then 808, 909…, plus MY HEX 1–4. The first edit copies the kit into a user slot.
- Hold OCT− / OCT+ while playing for ghost / hard hits.

**Panel** [C]:
- Tap a button = its pages; hold it = its tool layer on the keys.
- SEQ: white keys = steps 1–16 of the page; black keys 1–4 = pages.
- Drum GRID: K1 picks the sound; the white keys switch its 16 steps.
- Hold FX: punch-in effect per white key.
- Hold EDIT + touch a key: erase that sound or note.
- Hold ARP + a key: note repeat, with K1 = rate.
- Hold SEL + any key: the song key.
- Hold GLO = mixer: K1–4 = levels; keys 1–4 mute, 5–8 solo, 9 fill held, 10 fill next bar, last key tap tempo.
- ALGORITHM = track (1, 2, 3, DRUM); PRESETS = sounds; SELECT = page.

**Screens** (720 × 720 renders of the 240 × 240 TFT):
- `karma_steps.png`: the ACID STEP page. Header "ACID STEP · 120 · ▶ · battery". A 2 × 8 grid of step cells shows note names (C2, C3, D#2, G2, A#2…):
  - blue = note, white outline = cursor
  - "?" = chance step, a top bar = accent, an arrow = slide, "+2" = chord, a joined bar = tie
  - Below: STEP 6/16, NOTE G2, LEN, FLAG.
  - The bottom row shows track tabs 1 / 2 / 3 / DRUM in their track colours.
- `karma_drums.png`: an animated pixel drummer, a 16-step strip in orange with accents, a mini 16 × 8 pattern overview top-right, and the knobs SOUND HAT / STEP 7 / HIT ON / LEVEL SOFT.
- `karma_drumgen.png`: DRUM GEN in MAP mode. KICK/SNARE/HATS lanes with bars, then MODE MAP / MAP X 20 / MAP Y 90 / CHAOS 0%.
- Also saved: `karma_gen.png` (the GEN page) and `karma_home.png` (tape reels and the four song lanes).

### 3.6 JIANT FM (juanjiant-bit), with DRUM-X
- **Links:** <https://github.com/juanjiant-bit/JIANT>.
- **Version:** V10.60 public, V10.61 beta. **Licence:** GPL-3.0-only. **Base:** Felucca 1.1.5.1, with the song system from SLOOP [C].

**Sequencer** [C]:
- 6 tracks × 64 steps with LEN/DIV/SWING/GATE each. A piano roll on every SEQ page.
- Locks and knob automation, with an AUTO LIST.
- MICRO ±32/64 per step. REC Q sets how much recording snaps to the grid.
- **Step components**, 2 per step: CHANCE, RATCH ×1–8 (FLAT/FADE/RISE), ARP, WALK, PULSE, OCT, RAND, BEND, JUMP, REV, TRIG, FILL, KILL…
- TRIG conditions 1:2…4:4, 1:8, FIRST, !1ST.
- **PLAYHEADS:** extra heads with RATE, DIR and INTERVAL.
- STRETCH ×/÷2–8, ROTATE ±32.
- **EUCLID** page: HITS, STEPS 2–64, ROT. On drums, LANE ALL + DENSITY writes the whole kit.
- **MODES** for drums: ACCENT, GHOST, RATCHET, VARY (form A A' A'' B).
- **MUTATE:** EVERY n bars, AMOUNT, ORBIT/DRIFT/PULSE.
- **GEN** song generator: 43 genres, with seed, energy and form.
- 8 songs × 4 sections. The **TIMELINE** lets a row borrow a track from another section with a variation: MUTE, THIN, FILL, HALF, REV, SHIFT, OCT±, VAR1–4.

**DRUM-X** [C]:
- An 8-voice Microtonic-style kit (BD SD CP CH OH TM RS CB).
- Each voice has A/B sides with MORPH, FOLD, FM, PM types, LAYER and an ACOUST blend.
- X-MOD: a tempo-synced LFO on MORPH plus per-hit random. 9 kits. EDIT + SELECT rolls a kit.
- DRUM-X has been adopted by Araminta, Skiff, Caravel and Argo [C].

**Panel** [C]:
- The kit repeats in every octave (C = kick, D = snare, F# = CH).
- **The OCT setting is an articulation mode:** +3 ratchet ×2, +2 repeat every step, +1 every other step, 0 normal, −1 SHORT, −2 GHOST, −3 FLAM. All of it is recorded as played.
- Drum grid:
  - White keys = 16 steps.
  - Black 1–8 = lane. Black 9 held = accent entry. Black 10/11 = page.
  - K1 STEP, K2 LANE, K3 HIT (cycles --/ON/×2/×4/×8/SHORT/GHOST/FLAM), K4 ACC.
- Hold GLO: black 1–6 mute T1–T6, 7–10 mute drum groups; white keys solo.
- A held button + SELECT = that section's dice, with a BEFORE/NOW keep-or-cancel.

**Screen:** `jiant_cheatsheet_controls.png` is the key map of every layer, including SEQ and REC.

Derived firmwares:
- Braindancer (fork of JIANT)
- Rhythmer (six-track groovebox based on JIANT, per fm1-editor.com)
- Araminta (borrows DRUM-X and punch-ins)
- KARMA (credits it)

### 3.7 Hortator (DEADACTIVE)
- **Links:** <https://github.com/DeadActive/hortator>, plays in the browser at <https://deadactive.github.io/hortator/>.
- **Version:** 1.0.1. **Licence:** GPL-3.0-only. **Base:** Felucca [C].
- **What it is:** an 8-track drum machine [C]. Search results say 45 drum engines, 21 of them after the Elektron Machinedrum (13 TRX + 8 EFM) [C, from a search summary].

**Sequencer** [C]:
- 8 × 64 steps with LEN, DIV and swing per track.
- Per step: accent, PROB (which continues past 8/8 into FILL / !FILL), RATCH, NUDGE ±50/100, and a pitch on every step.
- An ACID 303 voice on up to 2 tracks.
- MOTION and p-locks share 1024 events.
- QUANT 1/16, 1/8, 1/32 or OFF; OFF stores timing as nudge.
- REC ALL for finger-drumming the whole kit.
- SONG of 16 rows. 4 project slots × 8 variations, cued live at the pattern end.
- **Grids** generator (map, chaos, euclid). Any track can follow one of its 3 channels.
- Step tools: copy/paste, MERGE, FILL, DUPLICATE.

**Drums** [C]:
- 808/909 voices, Plaits drum ports and samples. 151 factory presets and 96 user slots.
- CHOKE. A streams sidechain compressor; GHOST keeps the pump while the key track is muted.
- A RESON resonator with key follow.

**Panel** [C]:
- White keys = steps.
- Hold a step: K1 PROB, K2 RATCH, K3 ACCENT, K4 NUDGE.
- ENV toggles a sticky STEPS mode in which the keys stay steps on every page, so a held step + any knob = lock.
- Hold SEQ = TOOLS on the black keys.
- Hold GLO = MUTE: white keys mute, black keys solo, with NOW/NEXT BAR.
- **Hold FX = PERFORM:** black keys = buffer FX; white F3–F4 = per-track REPEAT STEP; D5–G5 = repeat rate.
- Black 1–8 = cue variations. Hold REC = momentary FILL. ARP = Grids.

Forks: MNM-1 (galfaroth) and Nauclerus ("Hortator-based groovebox with acid voices", per fm1-editor.com) [C].

### 3.8 Tonic (RahelPuest)
- **Links:** <https://github.com/RahelPuest/tonic-fm1>.
- **Version:** v0.12.1. **Licence:** MPL-2.0. **Base:** fm1-base + felucca-bsp. A close Digitone model [C].

**Sequencer** [C]:
- 4 × 64 steps, each track with a length (2–64) and speed (1/8×–2×, including 3/4×). Master length and change length.
- Note trigs (chords up to 4 notes) and lock trigs. P-locks and sound locks.
- Conditions: %, FILL, PRE, NEI, 1ST and their negations; A:B 1:2–8:8.
- Micro-timing ±23/384.
- Retrig with rate 1/1–1/80 and a velocity fade, all lockable.
- 22 chord types with inversions and strum.
- Euclid generator: LEN/HITS/ROT, named **STYLEs** (tresillo, son clave, bossa…), accents, ghosts, PROB, note walks, and **per-pad hits on kits**.
- Chains (HOME held + pattern keys). Song of 32 rows. Undo.

**Drums** [C]: one track with 8 synthesised pads from 31 models (808/909/FM kicks, 606 snare, hats, conga, zap…). Per pad: tune, decay, tone, level, pan + 2 model controls. Hat choke and a duck source.

**Panel** [C]:
- White keys = trigs; on a kit, the pads.
- Black 1–4 = pages (+ a white key = track length). Black 5 = LOCK trig. Black 6/7 = micro-timing on a held step. Black 8 + white = pick a pad. Black 9/10/11 = COPY/PASTE/CLEAR.
- **HOME held = performance layer:** white keys = patterns; black 1–4 mutes, 5 fill held, 6 fill next, 8 tap, 9/10 temporary save/reload, 11 restart.
- HOME + SCL + white keys = loop rolls, halftime, tape stop.

**Screens:**
- `tonic_euclid_kit.png`: "T2 808 KIT 6/7". Tabs EUC / ACC / KIT 1–4 / KIT 5–8. Hit counts 4/2/0/8 for 1 BD, 2 SD, 3 CP, 4 CH, drawn as orange dot lanes. Footer: PAGE, track chips T1–T4, BPM 120.0, "TURNS WRITE · SCL+HOME: UNDO", swing 50%.
- `tonic_screens.png`: home, kit, piano roll, Euclid on a kit, chords.

### 3.9 X0X (Charles Vestal) and X0X-RMX
- **Links:** <https://github.com/charlesvestal/fm1-x0x>, manual <https://charlesvestal.github.io/fm1-x0x/manual/>, browser emulator.
- **Status:** beta. **Licence:** GPL-3.0-only. **Base:** Felucca [C].
- **What it is:** a ReBirth-style machine: 909 + 808 + two 303s with TB-3PO + a break slicer, all running at once [C]. Elektronauts users single it out for its drum and bass emulations [C].

**Sequencer** [C]:
- 5 parts, each with its own LENGTH (≤64) and RATE.
- 32 patterns in two banks; changes queue to the bar. Hold two white keys on HOME to chain that range.
- SONG: up to 192 bars with per-bar part mutes and REPEAT ×1–8, recordable live.
- **Probability on the SELECT wheel:** hold a step and turn SELECT, from 100% down to 5%, then continuing into the 1:4, 2:4… condition cycles.
- P-locks on EDIT (160 in total). Knob motion: REC + PLAY, values glide between steps.
- Global swing 50–75.
- TB-3PO generate/mutate is seeded: DENS, ACCENT, SLIDE, OCTS, scale, auto-mutate every N bars.
- Undo/redo. No ratchets except the break's RETRIG.

**Drums** [C]: the 909 has 11 voices (BD SD LT MT HT RS CP CH OH CR RD); the 808 has 11 slots with an alternate voice each. Accent via ENV + step. The break slicer has 8 slices and a generator (COMPLEXITY/ANCHOR/ROLL/FILL/RETRIG).

**Panel** [C]:
- White keys = 16 steps, OCT± = pages. Black keys = drum track (on BREAK: slices + reverse/half/stutter; on HOME: mutes).
- ALGORITHM = part, PRESETS = pattern. ENV + key = accent; LFO + key = slide.
- Hold a 303 step: K1 note, K2 gate, K3 accent, K4 slide.
- HOME + SEQ = tap tempo.

**Screen:** `x0x_909.png` shows the 909 with P1 at 125 BPM: an 11-row matrix (BD…RD) plus an AC accent row, orange hits, a grey playhead column, and knobs TUNE / TONE / SNAPPY / DECAY. Footer: "BLACK: TRACK · WHITE: STEP · HOME+BLK: MUTE".

**X0X-RMX** (Mr-Roboto, v1.1.0, validated on hardware) adds [C]:
- Bank A–P × 16 patterns per part.
- Orb-style Remix playback reordering that never alters the stored steps.
- Grids MAP/EUCLID for kick/snare/hat (X, Y, CHAOS, FILL, OFFSET) and directions FWD/REV/PING/RND.
- Screen: `x0xrmx_grids_map.png`.

**Other X0X derivatives:**
- MORPHEUS (8 tracks): a Reason Matrix-style 12-lane drum matrix with an ACC lane and a per-step CURVE automation lane. Screen: `morpheus_matrix.png`.
- TRIBE (10 tracks, 64 clips per track with follow modes, scatter FX, "capture the last 32 notes"). Screens: `tribe_clips.png`, `tribe_seq.png`.
- DREADNOUGHT: the full Digitakt condition set and retrig with a velocity ramp.
- fm1-rocket-os: role-based clip launching.
- Acultur8 X0X, fm1-amy, ZEN-1, FiMba-1 and HYP-1 descend from this line too.

### 3.10 Ravel (De-Pattern), the most experimental
- **Links:** <https://github.com/De-Pattern/Ravel_FM1>, emulator and installer.
- **Version:** 1.25.0 (fm1-editor.com). **Licence:** GPL-3.0-only. **Base:** Felucca hardware layer via X0X [C].
- **What it is:** 8 tracks (synth, strike, PERC, WEFT, GLITCH) with an 8 × 8 influence grid in which tracks modulate and trigger each other [C].

**Sequencer** [C]:
- Patterns A/B, each up to 64 steps. Per-track LENGTH 1–64 and RATE ¼×–4×. Directions FWD/REV/PINGPONG/SNAKE.
- **Per step:** NOTE, VELO, LENGTH, CHANCE, MICRO in 24ths, TIE, a per-step envelope, CUT (loop/reverse/stutter) and 2 p-locks.
- **RATCHET 1–8** with **R CURVE** (EVEN/FASTER/SLOWER/BOUNCE, plus fading versions) and **R MOVE** (up/down the scale).
- Conditions: ALWAYS, FIRST, NOT 1ST, 1:2…4:4, FILL, NO FILL.
- EUCLID writes real, editable steps.
- Per-track CLOCK source: master, LFO1/2, DUST, or another track's notes.
- **GRAPH mode:**
  - Each step has cords A/B saying where the head goes next.
  - BRANCH between them by chance, turns, LFO or motion.
  - Two playheads, with per-head MOTION speed generators.
- 16 scenes that switch or **glide over 1–8 bars**. A 32-row arrangement.
- **Density arcs:** 16 points per track that thin a part, off-beats first.
- A two-oscillator clock that bends the tempo. QUANTZE 0–100%. TAKE.

**Drums** [C]:
- PERC has 33 Machinedrum-style machines (TRX/EFM/P-I/GND).
- A KIT is **6 lanes on one track, each with its own machine, LEVEL, CHANCE, LENGTH and RATE**, giving polymeter inside the kit.

**Panel** [C]:
- White keys = steps, OCT = page. Black 1–2 = pattern A/B, 3–8 = kit lanes, 9/10/11 = COPY/PASTE/CLEAR.
- Hold HOME = a help overlay for the current page.

**Screens:**
- `ravel_seq_graph.png`: the GRAPH page for T1 SYNTH CZ. Headers CORD A NEXT / CORD B NONE / BRANCH TURNS / HEAD 2 MELODY, a circle of 16 step dots with lines for the H1 RHYTHM and H2 MELODY paths, and the footer "PRESETS, KEYS: STEP".
- `ravel_seq_euclid.png`: the euclid ring.
- `ravel_showcase.png`: 12 screens.

### 3.11 Other groovebox firmwares with notable sequencer or drum ideas
- **LOOM-8** (Charles Vestal; fm1-base; GPL-3.0 / MPL-2.0) [C]:
  - 8 tracks × 8 patterns × 64 steps. A per-track step scale sets how many 16ths a step lasts.
  - Per step: 2 of 15 **step tricks** (pulse, multiply, hold, flam, glide, bend, ramp, random, jump, skip-every-N…), plus chance or A:B and locks.
  - 32 scenes and a song.
  - **11 groove types** (swing, lilt, drunk, push-pull…) with an amount of −99…99 per track.
  - **WEAVE** crosses two patterns.
  - **COND** conductor track sets key and chords. **THROW** track records momentary effects.
  - An 11-sound kit on black keys 1–11, 11 + 8 kits, and a break slicer.
  - Hold a step: K1 velocity, K2 length, K3 chance, K4 pitch.
  - Screens: `loom8_trick.png` (T2 Steps: a 16-cell grid with notes, step 7 outlined, TRICK 1 "multiply" VALUE 3) and `loom8_beat.png`.
- **MONO2K** (Sequencist; v1.9) [C]:
  - 6 mono machines × 64 steps.
  - Monomachine **trig types** (ALL/AMP/FILTER/LFO/NONE = trigless lock). Conditions 1ST/PRE/FILL/A:B. Ratchets.
  - Per-track length and speed. Grids lanes. 4 × 16 patterns.
  - On a held step: black 1–5 = trig type, black 6–11 = quick conditions (100%, 50%, 1:2, 1:4, FILL, !FILL). SELECT = note, ALGORITHM = accent/slide, PRESETS = condition, OCT± = ratchet, K1–4 = locks.
  - Hold HOME: white keys = 16 patterns.
  - MNM-1 (galfaroth, a Hortator fork) and MNM-1 (sirpearson, KIT track with 11 voices and choke groups A/B/C) follow the same model.
- **FIZZ** (Quixotic7; MPL-2.0; beta, runs on a Mac via RemoteFM1) [C]:
  - Up to 128 steps per track (8 pages of 16, each page with its own start and end). 64 patterns, queued END/BAR/BEAT/NOW.
  - **The black keys select an edit mode:** NOTE, VEL, LEN, MICRO, RATCH, CHNC, COND, TRIG, FUNC, SLIDE, SOUND. With a step held, black 1–10 give 10 preset values and B11 clears.
  - Step FUNCTIONS: restart, reverse, random jump, LEAP/JUMP n.
  - Ratchet ×1–8 with a ramp. Track defaults with per-step overrides.
  - Tools: EUCLID, GRIDS, HUMANIZE.
- **Bigorna** (nzimas; Digitone II-inspired) [C]:
  - A DRUM track holds 4 subtracks (ST-A–D), each with its own steps, length and clock.
  - Digitone II conditions. MUTATE every N bars. MIDI-FX every N (ECHO, STUTTER, FLAM, GRACE…).
  - **PHRASE generator by sound role** (kick, snare, hat, bass, drone) with DENSITY and COMPLEXITY. Shapes include Euclid, 3+3+2 and polymeter cells.
  - **BREAK held:** repeat, half, double, reverse, chop, roll; the result can be saved as a pattern.
  - A looper with 3 loops per track.
- **Jangada** (zednaked) [C]:
  - **49 factory beats, each with its own fill**: maracatu, baião, coco, ijexá, samba, xote, frevo, funk, hip-hop, trap, jungle, dembow, amapiano… A kit loaded on an empty track brings its beat along.
  - **VIVO**, a generative layer that leaves the written pattern intact:
    - PULS: euclidean pulse that walks the melody.
    - DENS with MEM: chance with memory.
    - CYC: a chance cycle of its own length.
    - EVOL: cellular automata rules 30/90/110…
    - FRZ holds what you hear; SEED makes it deterministic.
    - Drawn as a ring.
  - Tile badges mark locks and conditions.
  - Screen: `jangada_screens.png`.
- **Melodee** (keremimo; v1.6.1) [C]:
  - Song-centric, with 16 patterns per track; a pattern can carry its own sound.
  - **Jam-to-song:** each loop logs the pattern combination and becomes a song section.
  - **Capture:** hold REC to write what you just played.
  - A piano-roll NOTES editor.
  - Key-light grammar: dark = empty, dim = content, bright = playing, breathing = queued.
  - 808/909/SID/CR78/FM drum kits.
- **Argo / Felucca 8 Patterns** (echoe) [C]: 8 sequences per track, a per-track CHAIN (built by turning PRESETS), switching NOW or at the END, and a generative GEN arp (DENS/CHORD/EVOLVE).
- **Loom FM-1** (Co-oscillator; paused) [C]:
  - Toggles between 4 × 4 and **8 × 8** step views and a DETAIL page that draws chance, ratchet, nudge and velocity as lanes.
  - A drum track with choke groups; muted lanes keep running.
  - A chord-progression generator.
  - Screen: `loomfm1_64step.png`.
- **FM1 Move** (Nicodesy06; based on SLOOP 2.6) [C]:
  - A **Groove Engine**: quantise strength 0–100%, 8 templates (Straight, MPC 16, House, UK Garage, Broken, Rolling, Latin, User) with timing, velocity and accent maps, per-pad timing offsets, seeded humanise.
  - 6 clips per track plus scene launch.
  - Screen: `fm1move_screens.png` (from the dev branch).
- **ORBIT** (dspaudio; SLOOP-based) [C]:
  - An **Event Tape** with 4 lanes: select a region, then COPY/LIFT/DROP notes, hits and locks between tracks and positions.
  - A drum GRID that edits **silently**: black keys audition voices, white keys toggle steps without sounding.
  - Screen: `orbit_preview.png`.
- **MC-1** (dspaudio) [C]:
  - An MC-505-style machine: 64 patterns × 4 parts × 16 steps and a 128-entry song.
  - Knob automation into a shared 384-event pool.
  - 8 drum kits on 16 lanes. Hold OCT− + black 1–4 = bank, then a white key = pattern.
  - Screens: `mc1_drums.png`, `mc1_song.png`.
- **Optimist** (w0ts; modular builder, SLOOP-based) [C]:
  - 16 patterns per track, conditions evaluated in a stated order (condition → fill → chance).
  - **Generators EUCLID / RANDOM / PULSE / GRIDS with output modes REPLACE / ADD / MASK, plus WRITE to commit** (non-destructive).
  - An ACCENT lane. An iOS/Mac "Optimist Mirror" app.
  - Screen: `optimist_drums.webp`.
- **zp12** (zvenson; SP-12-style) [C]:
  - 32 pads on 8 channels; **pads on the same channel position choke each other**.
  - K1–4 = channel faders. Loops on the 11 black keys, queued to the loop end.
  - Recorded knob locks. Count-in, AUTO CORRECT quantise, overdub.
  - Screen: `zp12_steps.png`.
- **BB1 / Big Beat Studio** (TexasRADIO / OLE BIG BEAT) [C]:
  - Two drum machines plus the Dillo acid bass.
  - Drums: an 808 plus sampled LinnDrum, LM-1, DMX, DrumTraks, Drumulator, Simmons, Rhythm King. 539 rhythm sections, 205 acid phrases.
  - **EVOLVE:** the pattern drifts and returns, with AMOUNT/EVERY and per-part and per-attribute masks, FREEZE/RETURN and step locks. EUCLID and RANDOM too.
  - Live record ends in a keep/discard review.
  - Black keys: voice (B1–8), accent (B9), bank (B10–11). Section launch, group mutes and kill keys.
  - Screens: `bb1_euclid.png` (EVOLVE · LFO · KIT A, tabs EVOLVE/EUCLID/RANDOM, four bars, a step strip, HITS 5 / STEPS 16 / ROTATE 0 / ACCENTS 2) and `bb1_steps.png`.
- **FOMAJAM** (konsumer; foma) and **UNIBOX** [C]:
  - 9 tracks; any track can be any machine (808/909/SDS-V/CR-78 modelled; 707/606/DMX/Linn/505/DR-55/SK-1/KPR-77/Rhythm Ace from ROM).
  - Ratchets ×1/2/3/4/6/8. Voice fallback across machines.
  - UNIBOX adds a **"hold REC and jam" free take with tempo detection**, auto-spread across chained patterns.
- **DREADNOUGHT** [C]: the full Digitakt condition set (%, FILL, PRE, NEI, 1ST, LST, A:B with negations), retrig with rate 1/1–1/80 and a velocity fade, track length in bars, and a bar ruler that shows shorter tracks repeating dimmed.
- **CHOPPAH** (fm1-base) [C]:
  - Breaks: 16 slices on the white keys; hold to loop one.
  - The 11 black keys are momentary pads: ROLL 1/8, 1/16, 1/32, REVERSE, FREEZE, HALF, TAPE STOP, GATE, RANDOM, FILTER THROW, DUB.
  - Drum lanes: FILL = Euclid hits plus ROTATE. Screen: `choppah_pads.png`.
- **BEETLE / BEETLE BLUE** (SikkenWorks) [C]:
  - Six-lane tracker. A Step Groove page (microtiming, ratchet, probability).
  - Song chain of 64 positions with a **pattern source per channel**. Mute groups and 4 snapshots.
  - BLUE adds a non-destructive per-lane length 1–16 and a 24-position live setlist.
- **KAWA / K-WASUB** (Omnipotard) [C]:
  - Tracker cells with per-track tables (micro-sequences for ratchets and arps).
  - **GROOVE tables** (7/5, 8/4), MAGIC generators (Euclid, random, break chop).
  - K-WASUB adds an 8-track drum sequencer with chance and conditions.
  - Screen: `kawa_tracks.png`.
- **Mini-Tone** [C]: STOCHASTIC mode (density, groove, weighted pitch classes, seeded, REROLL, LOCK into the pattern) and an **EUCLID with a second rhythm combined by AND/OR/XOR/SUB**.
- **Bubba Machine** (written from scratch in C99) [C]:
  - BR-8 TR-style 16 instruments. Repeats ×1–4 + FLAM. An accent layer.
  - Per-instrument length is claimed in the README but not in the manual [I, conflict].
  - Screen: `bubba_seq_tr.png`.
- **LCD-4 / IND-1 / CRT-4** (devrvega) [C]:
  - Pocket-operator style. Hold HOME/ARP/FX + keys pressed in order builds a chain.
  - LCD-4: 4 kits × 11 parts (black keys = part, white keys = steps). On a held step, OCT− = slide and OCT+ = ratchet.
  - IND-1: two Euclidean metal-percussion rings.
  - Screen: `lcd4_drums.png`.
- **GR!MM** (GRiMMBIENT; v2.0.2) [C]: 4 tracks × 64 steps with chance, ratchets, locks and chord steps. Tools include mutate. Song slots A–D recorded live. GENERATE modes DRIFT/PULSE/STORM. No drum engine. Screen: `grimm_seq.png`.
- **DIRGE, Caravel, Araminta, SPIRALFM1, MYCELIUM, RED MASS VAMPIRE OS, NoteSorcery, OberVave, BBL JAM BOX, Finton, Golana DZ** [C]: Felucca or SLOOP sequencers with small additions:
  - TAKE (DIRGE)
  - Morph Journey over bars (Caravel)
  - unified automation list, Grids and COOK (Araminta)
  - per-track probability and genre grooves (SPIRAL/MYCELIUM)
  - an 8 × 16 pattern overview (NoteSorcery)
  - 256 steps and clip launch (OberVave)
  - Golana DZ adds 64 steps and a song mode to the Golana synth

### 3.12 Generative and self-playing firmwares
- **AMB-1** (Charles Vestal; fm1-base; MPL-2.0) [C]:
  - Bell tape loops of 13/17/23/29 beats phase against each other.
  - The Pulse page has **three Euclidean rings of 16/12/7 steps**: K2 = Hits, K3 = swing 50–75.
  - The keys are a scale mask (lit = in scale).
  - Hold any button for a 1 s help card.
  - Screen: `amb1_pulse.png`.
- **HYP-1** (RedtailWorks; AMB-1 fork) [C]:
  - 6 drum lanes × 16 steps, 6 patterns per piece. Drum drift (Change every 4–64 bars, Pool, Mutate with kick and clap protected; a fill before each change).
  - Links: the kick opens the drone filter, the hats accent the acid.
  - SAVE tap = breakdown; tap again = 4-bar build then drop.
  - Screen: `hyp1_seq.png`.
  - Siblings: LOF-1, ECO-1, GRAV-1, BIT-1.
- **PERF-1** (deamonSLINKY; HYP-1 fork; v0.17.0) [C], the deepest drum toolset in the generative family:
  - Per lane (SEL + knob): K1 Euclid fill, K2 rotate, K3 probability per hit, K4 lane length 1–16.
  - Groove page:
    - **Density 0–100**: 50 = as written. Lower drops off-16ths, then off-8ths. Higher adds hits.
    - **Source per lane**: borrow the lane from another pattern.
  - Steps page:
    - Ratchet x2/x3/x4/x6, flam, swell3, swell4.
    - Push 0–7/12 of a step.
    - Level ghost/soft/normal/accent.
  - Phrase page:
    - Chains such as 1134 and the Amen's 1 1 3 4.
    - Slice: Halves, Stutter, Reverse, Mirror, Swap.
    - Half or double time.
  - Lane conditions; freeze a generated acid line into steps.
  - Screen: `perf1_gen.png`.
- **DUB-1** (AMB-1 fork) [C]:
  - 5 drum lanes with accents and chance. Phrase logic: main bar × 3, then a variant.
  - An 8-bar arrangement drops the kick and brings it back with a fill.
  - A held solo key = "throw into echo".
- **Tuna, Makohai, MAKU, Mutable Dreams, Bunker Evolved, AMARU OS, GammaWave, ONE CLICK FM-1, Haunted FM-1, MIN-1, UnholyUnion, Patricktronics** [C]: generators.
  - Tuna: Marbles-style chaos knobs, "freeze" into an editable pattern of up to 384 notes, shareable seed codes such as BACH-FUGUE-17.
  - Makohai: lanes queued and BLENDed between styles; MY STYLE learns your bars.
- **DRIFT (Fabian Freitag)** [C]: a seeded Euclidean sequencer (CHAOS 1–999, TIME variations). Screen: `drift_sequence.png`.
- **DRIFT (MaxPower)** [C]: 4 Euclidean lanes of unequal length.
- **TRIO** (Reytian) [C]: GRU neural networks play a walking bass and a swung jazz drummer that follow your chords.
- **Polly** (Charles Vestal) [C]:
  - A QY70-style arranger: styles with Groove A/B, Intro, fills and Ending.
  - **Black keys 1–5 = Intro / A / B / Fill / Ending on the next bar.**
  - A groove recorder and a drum piano roll.
- **HERA** (Ben Badio) [C]: a J-6 chord groovebox with 64 patterns on an 8 × 8 grid and a shuffle of −90 to +90%. Screen: `hera_patterns.png`.
- **FoMni / fm1-chord / ChoralRoot / CoralFlower / CHORDS** [C]: chord instruments.
  - FoMni has 10 OM-84 rhythms with auto-bass.
  - fm1-chord has 56 drum loops and a 4-layer looper.
  - ChoralRoot's looper records chord *gestures* (root and quality), so playback is re-voiced live. It has 5 record modes, including Advance and Step, and chance, ratchet and conditions per event.

### 3.13 MIDI sequencers and trackers (no sound, or tracker UI)
- **SEQ-4** (devrvega; OXI One-inspired) [C]:
  - 4 sequencers on 4 USB ports, each in one of 6 modes: Mono, Poly, Chord, Multitrack (8 drum tracks), Stochastic, Matriceal.
  - 128 steps, 16 patterns. Directions include drunk.
  - Per step: velocity, octave, gate, glide, condition, repeats ×1–5 or Skip, offset ±45%.
  - Euclid with invert. Grids on tracks 1–3.
  - **Capture** keeps the last 256 notes. Undo up to 20.
  - **Two-key gestures:** step + a step to its right = tie; SEL + steps = loop start/end. Black 1–8 = rows; hold one + tap steps to draw.
  - Screens: `seq4_drums.png`, `seq4_song.png`.
- **DriftSeq** (johnskiller; emulator only) [C]:
  - 16 tracks.
  - **Loop window** (start + length, mod 64): steps outside it keep their data but are silent.
  - 11 conditions, including "previous step fired".
  - **Euclid regeneration rewrites only the on/off bits.**
  - Hot pattern switching keeps each track's phase. A "drift view" shows the phase relationships.
- **fm1-t1** (tensor-programming; WIP) [C]:
  - A Torso T-1 model: 6 tracks × 6 "cycles", each with Euclid, ratchets, scale and locks.
  - RATCHET page: repeats 1–16, velocity slope, **Pace** (accelerating or decelerating), probability, groove templates G0–G15.
  - **TEMP snapshot:** hold SAVE or LFO, tweak, release to revert, OCT+ to commit.
- **Berlinan** (jiripisa; GPL-2.0-or-later) [C]:
  - A Berlin School ensemble with 7 MIDI voices on loops of unequal length.
  - Every action quantised to the bar, with a blinking pending key.
  - "Realign in N bars" display. Keyboard zones for voices, degrees, scenes and snapshots.
- **Ketch, MOONDAW, MASIF, KAWA, PT/FM, OPLBend Tracker, FM1-TRAX, Dungeon Tracker, SIDOU, FM-1 SID (GoatTracker), FMDj (LSDj)** [C]: trackers.
  - Ketch maps an M8 layout onto the keybed: the 4 lowest keys are a d-pad and the 4 highest white keys are SHIFT/PLAY/OPTION/EDIT.
  - MOONDAW uses named effects (RET, PRB, RMP…) and stores songs as plain-text `.trk` files. Screens: `ketch_phrase.png`, `moondaw_pattern.png`.
- **fm1-polyseq** (NOVALENTI): a C99 prototype with polyphonic 16 steps. The README says not to flash it [C].

### 3.14 Closed or commercial firmwares
- **Groove OS** (Peter Gombos) [C]:
  - $29, built on top of V15, version 2.0. Manual <https://www.groove-os.com/manual>, emulator `/emu`.
  - Eight tracks of FM or VA, or a KIT track (16 pads on two pages, analog-style voices, sound packs or your own recordings).
  - Steps across, scale notes down. Stacked notes, step settings and conditions, p-locks, **DICE**, stored patterns and chains.
  - "Keep the loop you just played without pressing record". Knob recording. Undo across all tracks. SAMPLER.
  - PERFORM: white keys mute tracks and trigger punch-ins; black keys launch scenes; K1–K4 are throws over the whole mix; locked against accidents while music plays.
  - Per-track loop lengths are claimed by awesome-fm-1 [C] but not shown in the manual text we read [I].
  - No screenshots on the manual page.
- **April OS** (beashoko): a sampling-focused Felucca fork with 32 three-second slots and an 8-track sequencer. Only the installer page is public [C].
- **UTA BOX** (singing): no sequencer focus.

### 3.15 Infrastructure (not sequencers in themselves)
- **fm1-dock** (Joakim Eriksson; v0.8; GPL-3.0; Dinghy-based) [C]:
  - A one-install host for synth modules in flash slots. Hold HOME = the module picker.
  - Modules: OberVave (4-track sequencer), FM-106, GATOR, DUB-1, FM-1 SID (GoatTracker), AMB-1, Niagara Drift, Scintilla…
  - Global options: MIDI channel, hardware EQ, KNOBS CC (CC 74/71/73/72), MIDI THRU, CC7 volume.
  - For our app this is a reference for a "module picker" home, not for sequencing.
- **jbschooley Virtual-FM-1** (GPL-3.0-or-later; VST3/AU/Standalone, iOS-buildable) [C]:
  - An emulator and editor that syncs with hardware.
  - Per instance it targets stock M-VAVE, FM-1+VA, Felucca 1.6.1 / 1.0.3, SLOOP 2.7, Melodee 1.4.1, FM1 Open or ChoralRoot. The Felucca, SLOOP, Melodee and ChoralRoot firmwares run from source with their screens and panels.
  - Its own sequencer mirrors FM-1+VA: 16 patterns × 64 steps, 9 notes per step, ratchet, chance, gate, transpose, accent, Tie & Slide per step and per note, Chain, swing, step and real-time recording.
  - JSON pattern and preset format with a schema. MIDI file import and export of patterns.
  - **The closest existing prior art to our iPad app.** Its JSON pattern schema (`docs/JSON-FORMAT.md`) is worth reading before we define our own format [I].
- **Development tools:** fm1-base, felucca-bsp, Dinghy, foma, fm1-emu, RemoteFM1, Optimist and core-fm1 are the platforms the firmwares above are built on. They are not user-facing sequencers.

---

## 4. Extra firmwares found only in the fm1-editor.com directory

These are not in awesome-fm-1 and were not researched beyond their one-line description. They are all relevant to rhythm or sequencing [C, directory text]:

| Firmware | One-line description |
|---|---|
| CLATTER Pocket | LXR-02-style generative drum machine (1.0.0) |
| Elixir | LXR-02-style drum machine engine and sequencer (0.25.2) |
| LUXR | Drum machine with eight LXR-style sounds (alpha 0.1) |
| GLITCH | Microsound drum machine (beta 0.3.0) |
| Compás | Cumbia, salsa, merengue and bolero rhythm section (1.0) |
| Coqui | Latin and Caribbean percussion groovebox (1.1) |
| Amenity | Live jungle firmware slicing the Amen break (1.0.0) |
| Pulhra | Minimal Felucca fork with an Elektron-style sequencer (1.5.1) |
| PHREAK | Six-track groovebox on SLOOP (1.9) |
| SHIFL | Live groovebox on Felucca with six synth tracks (beta 3.0) |
| Rhythmer | Six-track groovebox based on JIANT (beta) |
| ReplicantFM1 | Acid, techno and big-beat groovebox (2.0.0) |
| Nauclerus | Hortator-based groovebox with acid voices (1.0.0) |
| keySTEP ONE | Controller, MIDI router and pattern/song arranger (beta) |
| Kitten Synths | Six-track groovebox recording to a DAW over USB (beta) |
| BoopBox | SLOOP fork with an eight-track project format (1.5.1) |
| OG Synth | 16 engines, 28 effects, four tracks (1.4.2) |
| GabberBuddy, Daurade, ATEK303, GIO-1, CHAOS MACHINE, JamTrack, Jam Playground, RIDDIM ROOTS, NACHTFAHRT, FORMALFRED | Groove, acid, backing-band or generative machines |
| PT/FM, OPLBend Tracker, FM1-TRAX, Dungeon Tracker | Trackers |

Searches did not turn up repositories for CLATTER Pocket, Elixir or Pulhra [I: they probably live elsewhere or only in that directory].

---

## 5. Recommendations for the iPad app (inferred, for discussion)

Keep stock V15 as the default (`FUNCTION_SPEC.md` section 6). Offer an optional "Extended sequencer" mode, built from the community consensus:

1. **Steps and pages.** Patterns of 16 → 64 steps. The white keys stay the 16-step window, and OCT− / OCT+ page through it (FM-1+VA, Felucca, SLOOP). Add a Flow 8 × 8 overview (FM-1+VA, Loom FM-1, HERA); the iPad has room to show it beside the panel.
2. **Per-step attributes on a held step + K1–K4**, in the SLOOP / Hortator order:
   - K1 note or chance, K2 velocity, K3 ratchet ×1–4, K4 nudge in 1/64.
   - OCT+ on a held step = condition (FILL / !FILL / A:B).
   - Show them as Skiff-style FEEL tiles or Felucca / Loom DETAIL lanes.
3. **Locks:** hold a step (or SEL in FM-1+VA) and turn a knob. Limit 4 per step (FM-1+VA). Show them as a Locks lane.
4. **Drum part:**
   - A synthesised 8–12 lane kit on the GM map: kick, snare, clap, CH, OH, tom, rim, bell/cow.
   - Black keys = lane, white keys = steps. OCT− / OCT+ held = ghost / hard hits.
   - An optional ACC lane (X0X, MORPHEUS, Optimist).
   - Choke groups A/B/C (FM-1+VA).
   - Kits in the FM spirit: FM drums (sloopDX, Bigorna) or VA 808/909-style kits (Felucca's 80/66/77 set).
5. **Generators**, non-destructive in the Optimist / DriftSeq style (REPLACE / ADD / MASK, then WRITE):
   - Euclid per lane (HITS / STEPS / ROT) with Tonic's STYLE presets.
   - A Grids X/Y map: on iPad this can be a real XY pad (KARMA, X0X-RMX, Araminta).
   - PERF-1's Density knob.
6. **Performance layer** on held GLO, following the de-facto standard: keys 1–4 mute, 5–8 solo, 9 fill held, 10 fill next bar, last key tap tempo. Add Hold FX = punch-ins, and Hold SAVE = sections A–D with quick chain.
7. **Capture / TAKE:** keep the last loop played without pressing REC (Skiff, SLOOP free take, Melodee Capture, TRIBE, SEQ-4, Groove OS).
8. **Interchange:** read Virtual-FM-1's JSON pattern format, and consider importing FM-1+VA patterns for compatibility.

---

## 6. Downloaded screenshots (`research/images/firmware/`)

All are text-free downloads of project images. Descriptions come from viewing the image [C] or from the project's caption [C, caption].

| File | Firmware | What it shows |
|---|---|---|
| fm1va_SEQ.pattern.png, fm1va_SEQ.pattern.8bit.png, fm1va_SEQ.pattern.64.png | FM-1+VA | Lane view: lanes as pink bars, beat columns brighter, cursor column |
| fm1va_SEQ.flow.png, fm1va_SEQ.flow.play.png | FM-1+VA | Flow 8 × 8 dot grid with tie bars, slide waves, ratchet splits, lock dots |
| fm1va_SEQ.step.png, fm1va_SEQ.step.locks.png | FM-1+VA | Step Settings list (notes with velocity, Length, Ratchet, Gate); the step's locks |
| fm1va_SEQ.lane.drums.png, fm1va_EDIT.8bit.drums.png | FM-1+VA | Drum lane rows F0…E1; 8-bit drum editor |
| fm1va_SEQ.lane.locks.png, fm1va_SEQ.timing.png, fm1va_SEQ.chain.png | FM-1+VA | Locks lane; Rate/Swing/Gate; Chain setting |
| karma_steps.png, karma_drums.png, karma_drumgen.png, karma_gen.png, karma_home.png | KARMA | Step grid with chance, accent, slide and chord badges; animated drummer with a step strip; Grids MAP generator; GEN page; home tape lanes |
| sloop_screens.png | SLOOP | Nine screens: drum grid, kit, SEQ layer, GLO, SAVE (sections), PHYS, FM6, KEY, visualiser |
| sloopdx_screens.png | sloopDX | Tracks, FM drum grid, step layer [C, caption] |
| skiff_step_tiles.png, skiff_drum.png, skiff_song.png | Skiff | FEEL chance tiles; 8-lane drum grid; per-track song entry lists |
| tonic_euclid_kit.png, tonic_screens.png | Tonic | Per-pad Euclid on an 808 kit; home, kit, piano roll, chords |
| loom8_trick.png, loom8_beat.png | LOOM-8 | Step with a "multiply" trick; kit beat on Steps |
| x0x_909.png | X0X | 11-voice 909 matrix + accent row with TUNE/TONE/SNAPPY/DECAY |
| x0xrmx_grids_map.png | X0X-RMX | Grids MAP page (X, Y, CHAOS, MODE) [C, caption] |
| morpheus_matrix.png | MORPHEUS | 8-track matrix sequencer with status bar [C, caption] |
| tribe_clips.png, tribe_seq.png | TRIBE | 10-track clip grid; 16-step sequencer [C, caption] |
| ravel_seq_graph.png, ravel_seq_euclid.png, ravel_showcase.png | Ravel | Graph sequencer ring with two heads; euclid ring; 12-screen showcase |
| bb1_euclid.png, bb1_steps.png | BB1 | EVOLVE/EUCLID page (HITS/STEPS/ROTATE/ACCENTS); drum Steps with ratchets |
| orbit_preview.png | ORBIT | Event Tape, synth, mixer and sampler screens [C, caption] |
| mc1_drums.png, mc1_song.png | MC-1 | 16-lane drum grid; song arrangement |
| zp12_steps.png | zp12 | Step grid of one pad |
| optimist_drums.webp | Optimist | Drum lanes with steps |
| jiant_cheatsheet_controls.png | JIANT FM | Key map for every layer |
| jangada_screens.png | Jangada | HOME, tracks, drone, layers, kit, master… |
| loomfm1_64step.png | Loom FM-1 | 64-step 8 × 8 sequencer |
| grimm_seq.png | GR!MM | Sequencer screen |
| bubba_seq_tr.png | Bubba Machine | BR-8 TR drum sequencer |
| fm1move_screens.png | FM1 Move | Firmware-rendered screens (dev branch) |
| felucca_controls.jpg | Felucca | FM-1 panel with Felucca labels |
| mnm1sp_steprec.png | MNM-1 (sirpearson) | STEP REC piano roll |
| choppah_pads.png | CHOPPAH | Held performance pads with K1–K4 settings |
| kawa_tracks.png | KAWA | Tracker tracks |
| chipbox_step.png | Chipbox | Step screen |
| amb1_pulse.png | AMB-1 | Three Euclidean rings (Pulse page) |
| perf1_gen.png | PERF-1 | Steps, Acid steps, Groove, Phrase pages |
| hyp1_seq.png | HYP-1 | Drum sequencer on the device |
| seq4_drums.png, seq4_song.png | SEQ-4 | 8 drum tracks; song arranger |
| ketch_phrase.png, moondaw_pattern.png | Ketch, MOONDAW | Tracker phrase; pattern with 4 notes per step |
| hera_patterns.png | HERA | 64-pattern grid |
| lcd4_drums.png | LCD-4 | 808 kit screen |
| drift_sequence.png | DRIFT (Freitag) | Euclidean sequencer piano roll |

The `official_*` files in that folder come from the agent covering M-VAVE's firmwares, not from this report.

---

## 7. Sources

Indexes and press:
- awesome-fm-1: <https://github.com/cicloid/awesome-fm-1> (README read in full)
- FM1 firmware directory: <https://fm1-editor.com/firmware/>
- Elektronauts thread: <https://www.elektronauts.com/t/m-vave-fm-1/252170?page=22>
- Sonic State on KARMA: <https://sonicstate.com/news/2026/11/02/karma-turns-m-vave-fm-1into-a-groovebox/>
- Synth Anatomy on FM-1+VA: <https://synthanatomy.com/2026/09/baud-girl-fm-1-va-custom-m-vave-fm-1-firmware.html>

Firmware docs read (text only):
- FM-1+VA manual: <https://baudgirl.com/work/FM-1+VA/manual>
- Groove OS manual: <https://www.groove-os.com/manual>
- KARMA: <https://eatyourgreensstudio-dotcom.github.io/karma-fm1/> and `/emu/cheatsheet.html`
- X0X manual: <https://charlesvestal.github.io/fm1-x0x/manual/>
- TRIBE: <https://apiel.github.io/fm1-tribe/>
- BB1 guide: <https://thebigbeat.app/fm1/guide/>
- Felucca wiki: <https://github.com/hugelton/Felucca/wiki>
- Manuals for Tonic, LOOM-8, MONO2K, FIZZ, SEQ-4, AMB-1, HYP-1, PERF-1, DriftSeq, fm1-t1, Berlinan, Ketch, MOONDAW, Polly, HERA, ChoralRoot, Optimist, ORBIT and JIANT (linked from each repository)

Repository READMEs read (`https://github.com/<owner>/<repo>`):
- hugelton/Felucca, isod89/sloop-fm1, zvenson/dxsloop, zvenson/zp12, dspaudio/orbit, dspaudio/mc-1
- Wulgaren/Araminta, juanjiant-bit/JIANT, Spiralfractalplugins/spiralfm1, megagott/mycelium-fm1
- karlalex732-dotcom/RED-MASS-VAMPIRE-OS-FOR-M-VAVE-FM1, catacombius/NoteSorcery, w0ts/optimist
- illuminus5/skiff, DeadActive/hortator, pjac1810/lax32, Quixotic7/FIZZ, InigoHernandez/mono2k
- galfaroth/mnm1, sirpearson/fm-1-monomachine, RahelPuest/tonic-fm1, charlesvestal/fm1-loom
- UnkleBlairy/BBL-JAM-BOX, nzimas/bigorna, justynroberts/fm1-finton, eldontyrellcorp/Mini-Tone
- charlesvestal/fm1-x0x, Mr-Roboto/fm1-x0x-rmx, benbadio/morpheus-fm1, TexasRADIO/bb1-firmware
- konsumer/fomajam, chinotto1/unibox, apiel/fm1-tribe, kclack/acid-fm1, TwistedGenetics/DREADNOUGHT
- profikid/fm1-break-choppah, kidbee85-beep/cut-a-dor-release, Guizmoh/K-WASUB_Firmware_for_FM1
- Guizmoh/Kawa-Tracker-Fm1, cmlarsen/fm1-rocket-os, SikkenWorks/BEETLE, SikkenWorks/BEETLE-BLUE, pbarilla/chipbox
- keremimo/melodee, zednaked/jangada, echoe/Felucca_seq_per_track, Co-oscillator/Loom-FM-1
- sinscum/DIRGE, GRiMMBIENT/grimm, bonszaimusic/caravel, Nicodesy06/FM1-MOVE, Erbubar23/bubba-machine
- dzwerg/Golana-DZ, Gadlele/Golana, De-Pattern/Ravel_FM1
- charlesvestal/fm1-amb, RustyPawz/fm1-HYP1, deamonSLINKY/PERF-1, sbegueria/fm1-dub
- delirioux/tuna, delirioux/makohai, johnskiller/driftseq, NOVALENTI/fm1-polyseq
- devrvega/SEQ-4, devrvega/IND-1, devrvega/LCD-4, jiripisa/fm1-berlinan
- risseraka/fm1-tracker-ketch, jaeggerr/moondaw-fm1, Reytian/fm1-trio
- charlesvestal/fm1-polly, benbadio/hera-fm1, math0ne/fm1-chord, charlesvestal/fm1-fomni
- Quixotic7/ChoralRootFM1, Orbitator/oneclick-fm1, FBNFRTG/drift-fm1, I-am-MaxPower/drift-fm1
- Vaayaa/rift-fw, zvenson/obervave, jartificer/fm1-gm, TheShrimpBlimp/pigeon
- thecemeterygates/masif-fm1, tensor-programming/fm1-t1, DimmKirr/core-fm1
- joakimeriksson/fm1-dock, jbschooley/Virtual-FM-1
