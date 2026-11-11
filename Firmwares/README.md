# Firmware packages

The real FM-1 can be reflashed with community firmwares. FM Pocket does the same with
**firmware packages**: each one is a folder in this directory, and more can be installed
inside the app (Firmware menu → **Install from URL…** or **Install from Files…**) without
rebuilding it.

iOS does not let an app load downloaded native code, so a package holds no native code. It
has three parts:

* data that tells the host which sound blocks to build,
* a sequencer layout,
* JavaScript for screens, keys and knobs, which the app runs in JavaScriptCore.

Sound always comes from the host's native blocks. The script edits their parameters and step
data. It never runs on the audio thread.

```
Firmwares/
  README.md            this file
  stock-v15/           native: the original M-VAVE V15 behaviour (built into the app)
  groove/              native: FM Pocket Groove (built into the app)
  sloop/               script package: SLOOP 2.8 (isod89)
  felucca/             script package: Felucca 1.8.1 (Hügelton Instruments)
  melodee/             script package: Melodee 1.6.1 (Ellic Studio)
  tools/pack.py        folder → single-file .fm1fw bundle
  dist/                built .fm1fw bundles, ready to host and install
FM1/FirmwareHost/      the host: catalog, installer, script runtime, native blocks
```

## Package layout

```
my-firmware/
  manifest.json
  lib.js               any number of scripts, run in the order the manifest lists them
  main.js
```

To distribute a package as one file, run `python3 Firmwares/tools/pack.py Firmwares/my-firmware`.
This writes `Firmwares/dist/my-firmware.fm1fw`, a JSON file:

```json
{"fm1fw": 1, "files": {"manifest.json": "…", "lib.js": "…", "main.js": "…"}}
```

You can install it in three ways:

* from any https URL;
* from a `manifest.json` URL, with the scripts in the same folder;
* from a file picked in Files.

An installed package whose `id` matches a bundled one replaces it, which is how you ship an
update. Swipe left on a downloaded package in the menu to delete it.

## manifest.json

```json
{
  "format": 1,
  "id": "my-firmware",                 // a-z 0-9 -, ≤ 32 chars; also its data folder
  "name": "My Firmware",               // shown in the menu and on the boot screen
  "version": "1.0",
  "bootTitle": "MINE",                 // big title on the boot screen (default: name)
  "summary": "One paragraph for the menu.",
  "credits": "Who made the original and what this is based on.",
  "license": "Licence of the package (and of the firmware it ports)",
  "source": "https://…",
  "runtime": "script",                 // "native" is reserved for firmwares built into the app
  "scripts": ["lib.js", "main.js"],
  "engine": {
    "instruments": [
      {"id": "t1", "type": "va", "voices": 6},
      {"id": "t2", "type": "fm"},
      {"id": "t3", "type": "pd", "voices": 6},
      {"id": "drums", "type": "drums"}
    ],
    "sequencer": {
      "patterns": 8,                   // 1–16 per track
      "tracks": [
        {"id": "t1", "instrument": "t1"},
        {"id": "t2", "instrument": "t2"},
        {"id": "t3", "instrument": "t3"},
        {"id": "dr", "instrument": "drums", "lanes": 11}
      ]
    }
  }
}
```

Limits:

* 1–8 instruments, with at most one `fm`.
* At most 8 tracks.
* 1–12 voices for `va` and `pd`.
* Scripts under 2 MB each.

The installer rejects packages that break these limits. It also checks every script's syntax
before writing anything.

## Native blocks the host exposes

| type | block | parameters (`inst.set(name, value)`) |
|---|---|---|
| `fm` | the app's 6-operator DX7-compatible engine, the same one the stock firmware uses | DX7 VCED index 0–155 with raw values, or the names `algorithm`, `feedback`, `lfospeed`, `lfodelay`, `lfopmd`, `lfoamd`, `lfowave`, `transpose`, `op1.level` … `op6.level`, `op<n>.coarse`, `op<n>.fine`, `op<n>.detune`. `inst.preset(i)` loads voice *i* (0–127) of the user's bank and returns its name. |
| `va` | virtual-analog polysynth, new for packages (`VASynth.swift`) | `wave1` `wave2` (0 saw, 1 pulse, 2 tri, 3 sine) · `pw` · `semi2` (index 0–48 = −24…+24) · `detune` (0.5 = 0) · `osc1` `osc2` `sub` `noise` (levels) · `sync` (0/1) · `polymod` (osc 2 → osc 1 FM) · `cutoff` (20 Hz·2^(10v)) · `res` · `ftype` (0 4-pole LP, 1 BP, 2 HP) · `envamt` (0.5 = 0) · `keytrack` · `fa fd fs fr` (filter ADSR) · `a d s r` (amp ADSR) · `drive` · `glide` · `mode` (0 poly, 1 mono, 2 legato, 3 unison) · `lforate` `lfowave` (0 tri, 1 sine, 2 square, 3 S&H) `lfopitch` `lfocutoff` `lfopw` · `level` · `vel` · `spread` |
| `pd` | phase-distortion (CZ-style) polysynth, new for packages (`PDSynth.swift`) | `wave1` `wave2` (0 saw, 1 square, 2 pulse, 3 double sine, 4 saw-pulse, 5–7 resonance 1–3) · `line` (0 = 1, 1 = 1+2, 2 = 1+1′, 3 = 1×2 ring) · `semi2` · `detune` · `dcw` · `dcwenv` · `da dd ds dr` (DCW envelope) · `a d s r` (DCA) · `fold` · `vib` `vibrate` · `level` · `vel` · `glide` · `mode` (0 poly, 1 mono, 2 legato) |
| `slot` | one track's sound source that can switch engine at runtime, new for packages (`SlotInstrument` in `HostInstruments.swift`). Declare `"engines": ["va", "fm", "pd"]` (any of the three) and the starting `"engine"`. Each engine inside keeps its own sound; an `fm` in a slot has an FM engine of its own, so several tracks can play FM voices at once. | those of the selected engine. `inst.engine()` reads it, `inst.engine("pd")` switches (notes in flight on the old engine are released, and its tail rings out), `inst.engines()` lists the choices and `inst.type` follows the selection. |
| `drums` | the app's 11-voice analog drum kit, one private instance per package (`DrumKit.swift`) | lanes 0–10 are BD SD LT MT HT RM CP CB CY OH CH. Each lane has `<lane>.level`, `.tune`, `.decay` and `.tone`, for example `BD.decay`. There is also `accent`. Play a lane with `inst.hit(lane, vel)`. |

Value rules:

* Continuous values run from 0 to 1.
* Discrete parameters (with a count) take an integer index.
* Time parameters map 0…1 to 1 ms…10 s, exponentially: 0.25 ≈ 10 ms, 0.5 ≈ 100 ms, 0.75 ≈ 1 s.

The host adds two more blocks for every package.

**Master bus** (`MasterBus.swift`, new). It sits after the instruments and before the app's
stereo FX chain:

* `fm.master({filter: -1…1, dust: 0…1, duck: 0…1})`. `filter` is a DJ filter: below 0 is
  low-pass, above 0 is high-pass. `dust` is bit and rate reduction plus crackle. `duck`
  makes drum lane 0 pump the synths.
* `fm.punch(name, beats)` starts one tempo-synced punch-in effect, and `fm.punch("OFF")` stops
  it. The names are `REPEAT`, `STUTTER`, `REVERSE`, `TAPE STOP`, `HALF SPEED`, `LP SWEEP`,
  `HP SWEEP`, `CRUSH`, `GATE`, `ECHO`, `KILL LOW`, `KILL MID` and `KILL HIGH`.

**Arpeggiator** (`PkgArp.swift`, new). Every instrument has one, off by default. While it is
on, that instrument's live notes (`inst.note` / `inst.off`) go to the arpeggiator instead of
straight to the sound. Sequencer steps still play the instrument directly. It runs on the audio
thread:

* While the sequencer plays, steps fall on its beat grid and take its swing. A key up to 15 %
  of a step late still gets the current step.
* When the sequencer is stopped, it runs at the sequencer's tempo and the first key sounds at
  once.
* `inst.arp({on, mode, rate, octaves, gate, latch})` changes any of these and returns them all,
  plus `modeName`, `rateName` and `step`, a step counter for a beat LED. `inst.arp()` only reads
  them.
* `mode` is an index or a name from `fm.arpModes`: `UP DN UPDN RND ORD REPEAT DNUP UP+8 CONV
  DIVG PINKY THUMB WALK CHORD`.
  * ORD plays the order the keys went down, REPEAT the latest key, and CHORD every held note
    each step.
  * UP+8 plays each note and then its octave.
  * CONV goes from outside in, DIVG from inside out.
  * PINKY puts the top note between the others, THUMB the bottom note.
  * WALK moves one note up or down at random.
* `rate` is an index or a name from `fm.arpRates`: `1/4 1/8 1/8T 1/16 1/16T 1/32 1/32T 1/64`.
* `octaves` runs 1–4 and `gate` 0.05–1 of a step.
* With `latch`, notes keep playing after release, and the next chord replaces them.
* On a `drums` instrument the notes are lane numbers, and each step hits the lane.

**FX chain**: `fm.fx(kind, on, a, b, c)` switches and sets the app's own effects, `filter`,
`reverb`, `delay`, `distortion`, `chorus` and `phaser`. Values are 0–100, as on the stock FX
page. A script firmware starts with every effect off.

If a firmware needs a sound block the host lacks, add it natively in
`FM1/FirmwareHost/Audio/`, register its `type` in `PackageEngine.init` and
`FirmwareManifest.instrumentTypes`, and document it here. Packages can then use it.

## The sequencer

The host plays the steps sample-accurately on the audio thread. The script only reads and
writes step data, on the main thread.

Track layout:

* Each track has `patterns` patterns of 64 steps.
* A note track has one row per step, with up to four notes.
* A drum track has one row per lane.

Each step has these fields:

| field | meaning |
|---|---|
| `vel` | 1–127. 0 means the step is empty. |
| `notes` | Up to four MIDI notes. Note tracks only. |
| `len` | Length in quarter steps. The default 3 is 75 %. Values over 4 tie into the following steps. |
| `chance` | 0–100. |
| `cond` | 0 always, 1 FILL, 2 !FILL, 3 first loop, 4 not first loop, 100 + a·10 + b for A:B (play on loop *a* of every *b*). |
| `ratchet` | 1–8 hits within the step. |
| `accent` | Boolean. |
| `slide` | Boolean. Legato and glide on mono `va` and `pd` voices. |
| `nudge` | −8…+7 sixteenths of a step. |
| `locks` | Up to two `[param, value]` pairs. The value is 0–255, or an index for a discrete parameter. A lock holds from its step until the next step without that lock. |

Each pattern also has a `length` (1–64) and a `div`. The div is an index into `fm.seq.divNames`:
1/32, 1/16T, 1/16 (the default), 1/8T, 1/8, 1/4, 1/2, 1 BAR, 2 BARS, 4 BARS.

Other behaviour:

* Tracks of different lengths stay in phase (polymeter).
* Swing runs from 50 to 75 % (MPC style) and applies to every second step of a 1/16 or 1/8 grid.
* `fm.seq.select(t, p)` changes the pattern at that track's loop end while playing.
* A **song** is a list of up to 64 `{patterns: [p per track, -1 = rest], repeats}` entries. The
  song advances at the loop end of track 0.

## Script API

The scripts share one global scope. The host calls these functions if they exist:

| function | when |
|---|---|
| `onBoot()` | Once, after the scripts load. Instrument parameters saved last time are restored *after* it. |
| `onMidi(kind, n, v, ch)` | Incoming MIDI while the package runs: `kind` is `"on"`, `"off"`, `"cc"` (n = controller, v = value) or `"program"`. The stock firmware's MIDI channel setting filters it first. Without `onMidi`, MIDI does nothing in the package. `LIB.midiNote(...)` and `LIB.gmLane(n)` in the bundled `lib.js` play a note on a track, with the GM drum map on a drum track. |
| `onButton(name, down)` | Every rubber button and OCT key, on press and on release. The names are `FX SEL ENV LFO EDIT GLO HOME SAVE ARP SEQ PLAY REC OCT- OCT+`. Holds, taps and double taps are up to the script; `fm.now()` gives the time in ms. |
| `onKey(k, down, velocity)` | Keys 0–26, from left to right. Use `fm.isWhite(k)`, `fm.whiteIndex(k)` (0–15) and `fm.blackIndex(k)` (0–10). |
| `onKnob(i, delta)` | KNOB 1–4 as 0–3. Each detent is ±1. |
| `onEncoder(name, delta)` | `SELECT`, `PRESETS` or `ALGORITHM`. MASTER always stays the host's volume. |
| `onTick(ms)` | 15 times a second. |
| `render(g)` | After every event and tick. It draws the 240 × 240 screen and sets the LEDs. |
| `onShutdown()` | Before another firmware is flashed. |

Drawing with `g`. Coordinates are in 240 × 240 screen pixels. Colours are `"#rrggbb"` or
`"#rrggbbaa"`.

* `g.clear(c)`
* `g.rect(x, y, w, h, c, radius)`
* `g.frame(x, y, w, h, c, lineWidth, radius)`
* `g.line(x1, y1, x2, y2, c, w)`
* `g.circle(x, y, r, c)`
* `g.ring(x, y, r, c, w)`
* `g.arc(x, y, r, deg0, deg1, c, w)`, with 0° at the top, clockwise
* `g.text(x, y, s, {size, color, align: "left"|"center"|"right", weight: "bold", font: "sans"|"mono"|"display"|"square"})`
* `g.scope(x, y, w, h, c, w)`, the live output

LEDs, set inside `render`:

* `fm.led.key(k, "#rrggbb" | null)`
* `fm.led.button(name, "off"|"on"|"blue"|"red"|"green")`

The host lights a key while it is held.

The rest of `fm`:

* `fm.inst(id)` returns an instrument with these methods: `note(n, v)`, `off(n)`, `hit(lane, v)`,
  `set(p, v)`, `setAll({…})`, `get(p)`, `params()`, `paramIndex(name)`, `level(v)`,
  `mute(b)`, `meter()`, `allOff()`, `arp([{…}])` (see Arpeggiator above), `engine([name])` and
  `engines()` (slots), and `preset(i)` (an FM engine: loads voice *i* of the user's bank into that
  instrument's own FM engine, or into the app's shared one for a plain `fm` instrument).
* `fm.seq` has these functions:
  * `get(t, p, s, row)` and `set(t, p, s, {…}, row)`
  * `clear(t, p[, s, row])`, `copy(t, from, to)` and `has(t, p)`
  * `length(t, p[, n])` and `div(t, p[, d])`
  * `play()`, `stop()`, `playing()`, `tempo([bpm])`, `swing([50…75])` and `fill([b])`
  * `mute(t[, b])`, `laneMute(t, lane[, b])`, `select(t[, p])` and `pattern(t)`, which returns
    the pattern playing
  * `step(t)` (the current step, −1 when stopped), `loop(t)` and `beat()`
  * `record(t, note, vel)` and `recordHit(t, lane, vel)`. Each writes at the nearest step
    while playing, keeps the timing as nudge, and returns the step or −1.
  * `song(sections, loop)`, `songOn([b])` and `songSection()`

  Tracks are given as an index or as an id.
* `fm.master(…)`, `fm.punch(…)` and `fm.fx(…)`, described above.
* `fm.presetName(i)` gives the name of FM bank voice *i*.
* `fm.arpModes` and `fm.arpRates` list the arpeggiator's mode and rate names.
* `fm.octave()` and `fm.velocity()` give the panel's settings.
* `fm.store.get(k, default)` and `fm.store.set(k, v)` keep JSON values per package.
* `fm.now()` and `fm.log(…)`.

The host saves step data, songs, tempo, levels, instrument parameters (every engine of a slot, and
its selection), arpeggiator settings and `fm.store`. It saves
them per package, when the firmware changes and when the app goes to the background, and
restores them at the next boot.

### Safety

A script has no file, network or system access. All it can reach is `fm` and `g`.

If a script throws, the host stops calling it and shows **SCRIPT ERROR** with the message.
Flash another firmware to recover.

JavaScriptCore cannot interrupt a script stuck in an endless loop, so keep handlers short.
Each one runs at most a few times per frame.

## A minimal package

```js
// main.js — a two-track toy firmware
var lead = fm.inst("lead"), kit = fm.inst("drums");
function onBoot() { lead.setAll({cutoff: 0.6, res: 0.3, mode: 1, glide: 0.2}); }
function onKey(k, down, vel) {
  var n = 53 + k + fm.octave() * 12;
  if (down) { lead.note(n, vel); fm.seq.record("lead", n, vel); } else lead.off(n);
}
function onButton(name, down) { if (name === "PLAY" && down) fm.seq.playing() ? fm.seq.stop() : fm.seq.play(); }
function render(g) {
  g.clear("#101418");
  g.text(120, 100, "HELLO", {size: 28, align: "center", font: "display", color: "#7fd5f2"});
  g.scope(20, 150, 200, 60, "#7fd5f2");
  fm.led.button("PLAY", fm.seq.playing() ? "green" : "off");
}
```

The UI test `FM1UITests/FirmwarePackageTests.swift` installs this kind of package from a
`data:` URL. It then flashes the package and checks the script's screen.
