# FM-1 alternative firmwares: which are most used, and the three ported as packages

Compiled 2026-11-11. Sources:

* the GitHub REST API: repository stars and forks, and release-asset download counts, fetched on 2026-11-11;
* GitHub search for "fm-1 m-vave" and "fm1 firmware", sorted by stars;
* the index [cicloid/awesome-fm-1](https://github.com/cicloid/awesome-fm-1), which lists about 349 GitHub repositories;
* the earlier survey in `FIRMWARE_COMMUNITY_SEQ.md`.

Only READMEs, wikis and manuals were read, as text. No firmware source was cloned, downloaded or
run, so the "clone into its own directory" precaution never came into play.

## How much each firmware is used

There is no telemetry, so every figure below is a proxy.

* Stars measure interest, not use.
* Release downloads count every asset fetch. That includes web installers fetching from GitHub
  releases, CI jobs and people downloading twice.
* Several projects attach two or three firmware files to each release (`.bin`, `.fwsc`, `.zip`).

"FW downloads" counts only the firmware assets (`.fwsc`, `.bin`, `.zip`, `.uf2`) across all releases.

| Firmware | Repo | Stars | Forks | Releases | FW downloads | Licence |
|---|---|---:|---:|---:|---:|---|
| **SLOOP** (isod89 / 3dSam) | isod89/sloop-fm1 | **781** | 110 | 16 | **9,529** | GPL-3.0 |
| **Felucca** (Hügelton / Leo Kuroshita) | hugelton/Felucca | **707** | **179** | 21 | 4,450 | GPL-3.0-only (engines MIT, BSP MPL-2.0) |
| JIANT FM | juanjiant-bit/JIANT | 234 | 22 | 0 (not on GitHub releases) | n/a | GPL-3.0-only |
| X0X (Charles Vestal) | charlesvestal/fm1-x0x | 230 | 35 | 26 | 2,761 | GPL-3.0-only |
| **Melodee** (Ellic Studio / Kerem Kilic) | keremimo/melodee | 201 | n/a | 41 | **24,558** | GPL-3.0-only |
| Skiff | illuminus5/skiff | 154 | 28 | 18 | 5,555 | GPL-3.0-only |
| AMB-1 | charlesvestal/fm1-amb | 126 | n/a | 6 | 1,904 | MPL-2.0 |
| Hortator | DeadActive/hortator | 57 | 4 | n/a | n/a | GPL-3.0-only |
| KARMA | eatyourgreensstudio-dotcom/karma-fm1 | 29 | 5 | n/a | n/a | GPL-3.0-only |
| Ravel | De-Pattern/Ravel_FM1 | 29 | 2 | n/a | n/a | GPL-3.0-only |
| FM-1+VA (Baud Girl) | closed source, baudgirl.com | n/a | n/a | n/a | no public counts | closed, free |

For context:

* M-VAVE's own SDK, m-vave/fm1_open, has 346 stars and its licence is listed as NOASSERTION.
  Parts of it are GPL-3.0.
* The resource hub aroum/fm1-custom-fw has 408 stars and the emulator joakimeriksson/fm1-emu
  has 207. Neither is a firmware.

How to read the evidence:

* **SLOOP** leads on stars and on unambiguous firmware downloads: about 1.3 assets per release,
  almost all `.fwsc`. About a dozen forks keep its control grammar (ORBIT, sloopDX, zp12,
  SPIRALFM1, MYCELIUM, Optimist, FM1 Move …, see `FIRMWARE_COMMUNITY_SEQ.md` §3.3). The
  evidence that it is the most used is strong.
* **Felucca** is second on stars and first on forks. It is the base most other firmwares are
  built on: Melodee, Skiff, Hortator, X0X, JIANT, Argo, Caravel, DIRGE and others. Its web
  installer may also fetch builds outside the counted assets. The evidence is strong.
* **Melodee** has by far the most download events, but they are inflated. Releases average 8.8
  assets, typically a `.bin` and a `.fwsc` per build plus JSON manifests for its web installer,
  and there are 41 releases. Even halved, it stays ahead of X0X and Skiff. The evidence is
  moderate: real use is likely high, but the counts overstate it.
* **X0X** and **JIANT** are close on stars, and X0X has forum praise on Elektronauts.
  **Skiff** has as many downloads as Felucca. These are the next candidates.
* Forum and video mentions were not counted systematically. The mentions noted in
  `FIRMWARE_COMMUNITY_SEQ.md` (Elektronauts for X0X, Sonic State for KARMA) are anecdotal.

## The three chosen

1. **SLOOP 2.8**: the most starred and most downloaded firmware with an unambiguous count.
2. **Felucca 1.8.1**: the platform most firmwares come from, and the most forked.
3. **Melodee 1.6.1**: the most downloaded firmware by event count, even after discounting
   inflation.

There are far more than three real FM-1 community firmwares (about 190), so no stand-ins from
related hardware were needed.

### Licences and what was reused

All three originals are GPL-3.0(-only), which is incompatible with reuse in this app.

* **No code was copied from any of them.** Each package is a new implementation of the
  behaviour described in the project's own README, wiki or manual.
* Felucca's engines repository is MIT and could legally be reused. It was not used either.
* Melodee ships Sequential's Prophet-5 programs and Casio's CZ-1 preset tones. They are not
  reproduced; the packages carry their own sounds, named by category.
* The packages' own text records this in `credits` and `license`
  (`Firmwares/<id>/manifest.json`).

## How each port maps onto the app

### Common to all three

The package host is in `FM1/FirmwareHost/`. The format is described in `Firmwares/README.md`.

**New native host code**, which every package uses:

* `VASynth`: a virtual-analog poly with two PolyBLEP oscillators, sub, noise, sync and
  Poly-Mod, a zero-delay 4-pole ladder and an SVF, ADSRs, glide, mono/legato/unison and an LFO.
* `PDSynth`: CZ-style phase distortion with eight waveforms, the line modes, a DCW envelope and
  a wavefolder.
* `MasterBus`: duck, dust, DJ filter and 13 punch-in effects.
* `PkgSequencer`: patterns, polymeter, swing, chance, conditions, ratchets, ties and slides,
  nudge, two locks a step, songs and live record.
* `PkgArp`: an arpeggiator per instrument. Its 14 modes take the names in Felucca's feature list
  (UP, DN, UPDN, RND, ORD, REPEAT, DNUP, UP+8, CONV, DIVG, PINKY, THUMB, WALK, CHORD). It also
  has rates from 1/4 to 1/64 with triplets, 1–4 octaves, gate and latch. It locks to the
  sequencer's grid and swing while playing and runs free when stopped.
* `PackageEngine`: the mixer, attached to `FMEngine` through a nil-by-default block hook.
* Bridges for the existing FM engine and drum kit (`HostInstruments.swift`).
* The JavaScriptCore runtime (`PackageHost.swift` and `Prelude.swift`).
* The Canvas screen renderer (`PackageScreenView.swift`).
* The catalog and installer.

**Package data and script**, per package:

* `manifest.json` declares the instruments and tracks.
* `lib.js` holds the shared helpers: hold, tap and double-tap tracking, undo snapshots, scales,
  chords and pattern tools.
* `main.js` holds every screen, page, layer, key mapping, knob mapping, sound, kit, song and
  record behaviour.

**Engine limits common to all three ports:**

* Each original lets any track load any of 12 or 13 engines. This host fixes one engine per track:
  * track 1 is ANALOG / PROPHET (`va`);
  * track 2 is FM6 (the app's FM engine, presets from the user's 128-voice bank);
  * track 3 is PHASE / CZ-1 (`pd`);
  * track 4 is DRUM.
* Physical models, granular, sampler, SID, organ, noise and similar engines are not available.
* Drums come from the app's single 11-voice analog kit. The named kits (808, 909, 606, CR78, VA
  kits, genre kits) are parameter sets that **approximate** those machines. They are not
  separate drum models.
* Audio is mono up to the app's stereo FX chain.

### SLOOP

**Ported:**

* The TRACKS home screen, with coloured tracks 1–3 plus drums 4 and the four coloured knob dials.
* Every button as a hold layer:
  * **FX** punch: white keys play loops 1/4–1/32, stutter, reverse, tape stop, half speed,
    filter sweeps, crush and echo; black keys play kills, freeze and loop 1/8T. The knobs are
    FILTER, DUST, DUCK and the track's filter.
  * **EDIT** erases a sound or note, live or from the whole pattern. Its black keys are drum
    mutes, its knobs are SHIFT, LENGTH ×2/½ and TRANSPOSE, and EDIT + OCT− / OCT+ is undo / redo.
  * **ARP** is note repeat, recorded as ratchets. It runs on the host arpeggiator in CHORD mode,
    so repeats are sample-timed and land on the loop's grid while it plays. Locking the ARP
    layer with HOME keeps the repeat on.
  * **SEQ** shows the 16 steps on the white keys, with pages on OCT±. Hold a step for note,
    level (GHOST / SOFT / NORM / HARD), ratchet, nudge and locks (ALGORITHM picks the parameter,
    PRESETS sets the value); OCT+ sets the fill condition. Without a held step the knobs are
    SOUND/NOTE, DIV, SWING and LENGTH.
  * **SEL** sets the key, chord, scale, key mode and transpose.
  * **GLO**: keys 1–4 mute, 5–8 solo, 9 is fill while held, 10 is fill on the next bar,
    16 is tap tempo. The knobs are the track levels.
  * **SAVE**: keys 1–4 play sections A–D, 5–8 save them, 13 is loop/song and 16 is the chain.
    Several keys tapped while holding make a quick chain.
* HOME tapped while a layer is held locks the layer. HOME on TRACKS opens the visualiser
  (SELECT picks one of 4 styles).
* REC while playing records over the loop. REC while stopped arms the REC screen (length
  1/2/4 bars, start on the first note or on PLAY). Hold REC for about 2 s to clear the track.
* 16 drum pads on the white keys; a black key doubles the white key on its left.
* OCT− / OCT+ held on the drum track give ghost / hard hits.
* The PLAY light flashes on the beat, and keys 1/5/9/13 glow in layers.

**Approximated:**

* 16 drum sounds are mapped onto 11 voices.
* 13 kits instead of 37.
* Note repeat on the drum track doesn't pump the master duck, which live kick hits do.
* About 20 sounds instead of 153.

**Missing:**

* free-tempo REC (it shows "n/a");
* song recording (SAVE + key 14);
* five punches (tape wobble, octave up, flanger, auto-pan, fade out), shown as "n/a here";
* TEXTURE, the INSERT effects, MIDI LEARN, user samples and the HOME-hold menu settings (the
  menu shows ABOUT only).

### Felucca

**Ported:**

* Pages by button, where taps go round:
  * HOME: HOME, MIXER, CLOCK;
  * SEQ: STEP (piano roll or drum grid), DETAIL (chance, ratchet, nudge and velocity lanes),
    AUTOMATION (a list of a track's records);
  * GLO: SONG (16 sections of slot A–D or rest per track, with repeats);
  * SAVE: PRESETS (by category) and PROJECT (slots A–D, copy);
  * EDIT 1 / 2 / VOICE, ENV, LFO / LFO 2, FX / SENDS, SCL / CHORD.
* Quick layers, held or latched by double-tap:
  * SEQ TOOLS: CLEAR, REVERSE, SHIFT < >, RANDOM, COOK, EUCLID, DOUBLE, HALF, plus BEAT and the
    lane tools on DRUM. The knobs are LEN, DIV, SWING and GATE, and OCT− puts the track back.
  * GLO: mutes, solos, E4 FILL, tap and levels.
  * FX: repeat, reverse, sweeps, tape stop, freeze, phaser, reverb and echo throws, stutter,
    crush, and track mutes on the black keys.
  * EDIT: drum lane mutes.
  * SCL: the root.
  * REC: CLEAR, COUNT-IN, QUANTIZE.
* Hold a step on SEQ > STEP and turn a knob to lock that parameter; PRESETS sets the nudge.
* SAVE held is a one-step undo.
* MOMENTARY: hold LFO and turn a knob; the value jumps back on release, and OCT+ keeps it.
* The scale keyboard (QNT OFF / SNAP / WHITE / SEQ, ROOT, 16 scales, TRN) and chord keys.
* Step recording at the cursor while stopped.
* The "1 A*" header with the play state and tempo, and the knob cards.
* 8 drum lanes on the GM map, with kits STD, 80, 10, 66, 55, 77, DEEP, TIGHT and PERC.

**Approximated:**

* The arpeggiator, on ARP (MODE with OFF first, RATE, OCT, GATE) and ARP 2 (LATCH), with the
  ARP light as a beat LED. The wiki lists the mode names and mentions latch and a beat LED, but
  doesn't define the chord modes or the page layout. The meanings of DNUP, UP+8, CONV, DIVG,
  PINKY, THUMB and WALK and the knob layout are this port's own. Live recording records the
  keys, not the arpeggio, and there is no arp on the drum track.
* Felucca's 128-record automation becomes two locks a step in the host.
* Recorded knob motion is not captured.
* QNT SEQ snaps the keys only.
* The kits are parameter sets of the 808-style voice.

**Missing:**

* the modulation matrix, CLICK, MIDI LEARN, the 13-engine choice, SLICE and samples;
* the HOME-hold menu and palettes.

### Melodee

**Ported:**

* The Stage (HOME) shows the selected track's four engine knobs:
  * Prophet: cutoff, resonance, filter envelope, release;
  * FM6: MLVL, MRAT, MEG, DTUN;
  * CZ-1: wave, DCW, detune, vibrato.
  It also shows the chord over the live waveform and a lane per track with the sound, the
  playing pattern and the next one, and step dots. An armed track's lane has a breathing or
  beat-flashing red border.
* HOME tapped again opens the chord wheel in fifths: the key's notes are marked, the sounding
  chord is joined and the track levels pulse in the corners.
* The PRESETS browser: KNOB 1 picks a category or RECENT, KNOB 2 the sound, OCT− returns to
  the previous sound.
* SEQ > NOTES is a piano roll:
  * KNOB 1 STEP, KNOB 2 PITCH, KNOB 3 LENGTH in quarter steps, KNOB 4 VEL (or SLIDE while ENV
    is held);
  * PRESETS zooms;
  * OCT+ places a note or opens the note's sheet (chance, slide, copy, delete);
  * stopped and armed, keys enter notes at the cursor.
* SEQ also has PATTERN and TEMPO pages, and SONG:
  * up to 64 sections, each with a pattern or REST per track and repeats, plus a time ruler;
  * OCT+ / OCT− add and remove sections;
  * hold REC to turn the logged jam into the song ("take jam");
  * Loop song on GLO > GLOBAL.
* Hold SEQ for PATTERNS:
  * white keys pick patterns 1–16 (the playing one lit, ones with notes glowing, the queued
    one breathing); picking an empty pattern arms REC, as does a double tap;
  * black keys 1–4 pick the track;
  * hold a pattern key for the dialog: delete, copy, C# halves, D# doubles.
* REC arms the track without starting; while playing it waits for the loop start.
* Stopped and armed, the first key starts playback and records from step 1. REC + PLAY arms
  and starts together.
* Capture: hold REC to write the last 1, 2 or 4 bars played.
* EDIT held undoes up to 8 levels, and EDIT + OCT− / OCT+ is undo / redo.
* The GLO and SCL quick layers; double-press GLO to lock it.
* Chords: AUTO and AUTO2 (an approximation of Melodee's voice leading: closest inversion, or
  melody on top), plus triads, sevenths and fixed shapes.
* Eight palettes.

**Approximated:**

* PROPHET is the generic `va` block, not the SSI/Curtis models.
* CZ-1 uses ADSR in place of the eight-point envelopes.
* AUTO harmony is simplified.
* Capture quantises to the step grid and keeps the offset as nudge.
* The arpeggiator has the same ARP / ARP 2 pages and modes as the Felucca port. Melodee's
  README mentions ARP, ARP 2, REPEAT, ARP OCT, ARP RATE and a beat LED, but doesn't list its
  modes, so the Felucca list stands in. ARP RATE isn't offered as a HOME SELECT target.

**Missing:**

* the MIDI-only tracks 5–8 and USB host;
* SID and the per-track note FX;
* the 27 timed punch FX in SONG;
* a preset per block or pattern;
* Melodee's actual preset libraries;
* the 32 projects (there is one per package).

## Verification of this work

* **Build:**
  `xcodebuild -project FM1.xcodeproj -scheme FM1 -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/fm1-dd-fw build`
  succeeds with no warnings in the new code.
* **Stock output is bit-identical.**
  * Method: all 128 factory voices rendered through the HEAD `FMEngine.swift` and through the
    modified one (the `blockHook` is nil for stock and Groove).
  * Result: both produce the same output hash, `7e8cc537b57a9cd0`.
* **Package engines** were run offline, each manifest's engine playing all four tracks for 6 s:
  * output is finite;
  * the mix peaks at 0.875;
  * CPU is about 0.3–0.4 % of realtime on the Mac;
  * the loops advance;
  * the punches and DJ filter run.
* **Arpeggiator, offline** (`PkgArp.swift` driven block by block against a recording
  instrument):
  * each mode's note order on a C-E-G chord, and 2-octave UP;
  * free-running spacing, with the first note at once;
  * synced steps on the grid, plus the late-key tolerance;
  * swing at 75 %, and gate length;
  * release with and without latch, latch replacement, and switch-off releasing everything;
  * RND and WALK staying inside the held notes, and a 40-note, 4-octave stress on every mode.
  Every check passes. Through the full `PackageEngine`, two arps on each package fired 50 steps
  in 6 s at 124 BPM (49.6 expected), with finite output at under 1 % CPU.
* **VA/PD stress:** 300 random patches with locks produced no non-finite samples.
* **Scripts:** each package took 30,000 fuzzed panel events against a mock host in Node
  without an exception or a bad draw command.
* **UI tests:** `FirmwareMenuTests` and `FirmwarePackageTests` pass on the simulator:
  * install from a URL, flash and run a script firmware;
  * bundled SLOOP, then back to stock;
  * Felucca's ARP page: KNOB 1 turns the arpeggiator on and shows its mode, and a second ARP tap
    opens ARP 2.
* **Screens:** screenshots of SLOOP, Felucca and Melodee booted in the simulator show their own
  screens.
* **Install over the network:** `testInstallFromHTTPSAndRun` downloads Felucca's packed file from
  the public GitHub repo over https, then flashes and runs it.
* **MIDI in:** the script fuzz includes random note, CC and program messages on all 16 channels.
* **Not verified:**
  * listening tests, since nothing was heard;
  * a physical iPad.
