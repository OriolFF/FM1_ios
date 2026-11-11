// SLOOP for FM Pocket — a re-implementation of the behaviour documented in the SLOOP 2.8
// README (github.com/isod89/sloop-fm1, GPL-3.0). No SLOOP code is used; see ../README.md
// and research/FIRMWARES.md for what is ported and what is approximated.

var C = { t1: "#4aa8ff", t2: "#4fd67a", t3: "#ffd23f", t4: "#ff8a3d", bg: "#0b0d12", panel: "#171b24", dim: "#2a3040", white: "#f2f4f8", red: "#ff4a3d", grey: "#8b93a7" };
var TC = [C.t1, C.t2, C.t3, C.t4];
var INST = ["t1", "t2", "t3", "drums"];
var ENGINE = ["ANALOG", "FM6", "PHASE", "DRUMS"];
var DR = 3;                                  // drum track index
var LANES = ["BD", "SD", "LT", "MT", "HT", "RM", "CP", "CB", "CY", "OH", "CH"];
// the 16 drum sounds on the white keys: lane + velocity/tune variant (11 voices in this host)
var PADS = [[0, "KICK"], [0, "KICK2"], [1, "SNARE"], [6, "CLAP"], [10, "HAT"], [9, "OPEN"], [10, "PEDAL"], [5, "RIM"],
            [2, "LO TOM"], [3, "MID TOM"], [4, "HI TOM"], [7, "COWBELL"], [8, "CYMBAL"], [1, "SNARE2"], [6, "CLAP2"], [8, "RIDE"]];
var LEVELS = [["GHOST", 34], ["SOFT", 64], ["NORM", 100], ["HARD", 127]];

// ---- sounds (normalised parameters of this host's blocks) ----
var SOUNDS = {
  t1: [
    { name: "ACID 303", wave1: 0, osc2: 0, sub: 0, cutoff: 0.30, res: 0.78, envamt: 0.9, fa: 0, fd: 0.42, fs: 0, a: 0.02, d: 0.5, s: 0.7, r: 0.2, mode: 1, glide: 0.22, drive: 0.55 },
    { name: "808 SLIDE", wave1: 3, osc2: 0, sub: 0.3, cutoff: 0.6, res: 0, envamt: 0.5, a: 0.01, d: 0.8, s: 0.0, r: 0.6, mode: 1, glide: 0.35, drive: 0.6, lfopitch: 0 },
    { name: "REESE", wave1: 0, wave2: 0, osc2: 1, detune: 0.58, cutoff: 0.45, res: 0.2, envamt: 0.55, a: 0.02, d: 0.6, s: 0.9, r: 0.3, mode: 1, drive: 0.4 },
    { name: "SUPERSAW", wave1: 0, wave2: 0, osc2: 0.9, detune: 0.6, cutoff: 0.72, res: 0.1, envamt: 0.55, a: 0.04, d: 0.6, s: 0.8, r: 0.5, mode: 3, spread: 0.5 },
    { name: "STRING MACHINE", wave1: 0, wave2: 1, osc2: 0.6, detune: 0.56, cutoff: 0.62, res: 0.05, envamt: 0.5, a: 0.55, d: 0.6, s: 0.9, r: 0.65, lforate: 0.45, lfopw: 0.3 },
    { name: "HOUSE STAB", wave1: 1, wave2: 0, semi2: 31, osc2: 0.7, cutoff: 0.5, res: 0.35, envamt: 0.85, fd: 0.38, fs: 0.1, a: 0.01, d: 0.45, s: 0.2, r: 0.35 },
    { name: "DUB CHORD", wave1: 0, wave2: 1, semi2: 31, osc2: 0.8, cutoff: 0.42, res: 0.4, envamt: 0.75, fd: 0.5, fs: 0.15, a: 0.01, d: 0.55, s: 0.0, r: 0.5 },
    { name: "SYNC LEAD", wave1: 0, wave2: 0, semi2: 36, osc2: 1, osc1: 0.2, sync: 1, cutoff: 0.7, res: 0.2, envamt: 0.6, a: 0.01, d: 0.5, s: 0.8, r: 0.3, mode: 2, glide: 0.15 },
    { name: "SOFT PAD", wave1: 2, wave2: 0, osc2: 0.5, detune: 0.54, cutoff: 0.5, res: 0.1, envamt: 0.55, a: 0.68, d: 0.7, s: 0.9, r: 0.75, lforate: 0.35, lfocutoff: 0.15 },
    { name: "PLUCK", wave1: 1, wave2: 0, osc2: 0.5, cutoff: 0.35, res: 0.3, envamt: 0.95, fd: 0.36, fs: 0, a: 0.0, d: 0.45, s: 0, r: 0.35 }
  ],
  t3: [
    { name: "CZ BRASS", wave1: 0, line: 0, dcw: 0.15, dcwenv: 0.8, da: 0.35, dd: 0.5, ds: 0.4, a: 0.3, d: 0.5, s: 0.85, r: 0.4 },
    { name: "CZ BASS", wave1: 1, line: 0, dcw: 0.1, dcwenv: 0.85, dd: 0.4, ds: 0.05, a: 0.0, d: 0.5, s: 0.4, r: 0.3, mode: 1, glide: 0.1 },
    { name: "RESO PLUCK", wave1: 5, dcw: 0.2, dcwenv: 0.75, dd: 0.42, ds: 0, a: 0, d: 0.48, s: 0, r: 0.4 },
    { name: "GLASS BELL", wave1: 3, wave2: 5, line: 1, semi2: 43, dcw: 0.25, dcwenv: 0.5, dd: 0.55, ds: 0.1, a: 0, d: 0.65, s: 0, r: 0.6 },
    { name: "DIGI ORGAN", wave1: 4, wave2: 2, line: 1, semi2: 36, dcw: 0.45, dcwenv: 0, a: 0.01, d: 0.3, s: 1, r: 0.2 },
    { name: "SITAR", wave1: 6, line: 2, dcw: 0.3, dcwenv: 0.6, dd: 0.6, ds: 0.2, a: 0, d: 0.65, s: 0.2, r: 0.5, fold: 0.15 },
    { name: "PHASE PAD", wave1: 0, line: 2, detune: 0.6, dcw: 0.2, dcwenv: 0.4, da: 0.65, dd: 0.7, ds: 0.5, a: 0.6, d: 0.7, s: 0.9, r: 0.72, vib: 0.15 },
    { name: "FOLD LEAD", wave1: 0, dcw: 0.5, dcwenv: 0.3, fold: 0.55, a: 0.01, d: 0.5, s: 0.8, r: 0.3, mode: 2, glide: 0.12 }
  ]
};
var KITS = [
  { name: "808", p: {} },
  { name: "909", p: { "BD.decay": 0.38, "BD.tone": 0.7, "SD.tone": 0.75, "SD.decay": 0.45, "CH.decay": 0.35, "OH.decay": 0.55, "CP.tone": 0.62 } },
  { name: "606", p: { "BD.tune": 0.62, "BD.decay": 0.35, "SD.tune": 0.62, "SD.decay": 0.35, "CH.tone": 0.75, "CH.decay": 0.3 } },
  { name: "TRAP", p: { "BD.decay": 0.95, "BD.tune": 0.42, "CH.decay": 0.25, "SD.tone": 0.66, "CP.decay": 0.6 } },
  { name: "DRILL", p: { "BD.decay": 1.0, "BD.tune": 0.38, "SD.tune": 0.6, "RM.level": 0.9, "CH.tone": 0.6 } },
  { name: "BOOMBAP", p: { "BD.decay": 0.55, "BD.tone": 0.35, "SD.tone": 0.4, "SD.decay": 0.6, "CH.tone": 0.35 } },
  { name: "LO-FI", p: { "BD.tone": 0.25, "SD.tone": 0.25, "CH.tone": 0.2, "OH.tone": 0.25, "CY.tone": 0.2 } },
  { name: "HOUSE", p: { "BD.decay": 0.45, "BD.tone": 0.62, "OH.decay": 0.42, "CP.decay": 0.55 } },
  { name: "TECHNO", p: { "BD.decay": 0.62, "BD.tune": 0.45, "BD.tone": 0.8, "CH.decay": 0.28, "RM.tune": 0.4 } },
  { name: "MINIMAL", p: { "BD.decay": 0.3, "BD.tune": 0.55, "RM.decay": 0.3, "CH.decay": 0.2, "CB.tune": 0.7 } },
  { name: "ELECTRO", p: { "BD.tune": 0.48, "SD.tune": 0.4, "CP.tone": 0.75, "CB.level": 0.85 } },
  { name: "JUNGLE", p: { "BD.decay": 0.4, "SD.tune": 0.7, "SD.tone": 0.8, "SD.decay": 0.4, "HT.tune": 0.7 } },
  { name: "AMBIENT", p: { "BD.tone": 0.3, "SD.decay": 0.8, "CY.decay": 0.9, "OH.decay": 0.85 } }
];

// ---- state ----
var B = new LIB.Buttons();
var undo = new LIB.Undo(8);
var S = fm.store.get("ui", null) || { track: 0, sound: [0, 0, 0], kit: 0, octave: 0, root: 0, scale: 0, chord: 0, keys: 0, transpose: 0, lane: 0, recLen: 1, recStart: 0 };
var screen = "tracks";            // tracks | visual | page | rec
var page = null;                  // {group, index}
var layer = null, locked = null;  // held layer name / locked layer
var heldStep = -1, stepPage = 0, lockParam = 0;
var recording = false, armed = false;
var flash = null, flashUntil = 0;  // transient message
var visStyle = 0;
var sections = fm.store.get("sections", [false, false, false, false]);
var chainKeys = [];
var heldKeys = {};                // k → notes playing
var drumHitLevel = 2;             // NORM
var repeatRate = 2, repeatActive = false;
// note repeat runs on the host arpeggiator (CHORD mode: every held note each step), so the
// repeats are sample-timed and land on the loop's grid while it plays
var REPEAT_RATES = ["1/8", "1/16", "1/32", "1/32T", "1/64"], REPEAT_NAMES = ["1/8", "1/16", "1/32", "1/48", "1/64"];
function setRepeat(on) {
  repeatActive = on;
  for (var t = 0; t < 4; t++) inst(t).arp(on && t === S.track ? { on: true, mode: "CHORD", rate: REPEAT_RATES[repeatRate], octaves: 1, gate: 0.5, latch: false } : { on: false });
}
function setRepeatRate(d) { repeatRate = LIB.clamp(repeatRate + d, 0, 4); if (repeatActive) inst(S.track).arp({ rate: REPEAT_RATES[repeatRate] }); }
var tapTimes = [];
var mutes = [false, false, false, false], solos = [false, false, false, false];
var fillNext = false;
var keyFlash = {};
var lastBeat = -1;

function inst(t) { return fm.inst(INST[t]); }
function say(msg, ms) { flash = msg; flashUntil = fm.now() + (ms || 1100); }
function pat(t) { return fm.seq.pattern(t); }
function saveUI() { fm.store.set("ui", S); }
function soundName(t) {
  if (t === DR) return KITS[S.kit].name;
  if (t === 1) return fm.presetName(S.sound[1]);
  return SOUNDS[INST[t]][S.sound[t] % SOUNDS[INST[t]].length].name;
}
function loadSound(t, i) {
  if (t === DR) { S.kit = LIB.wrap(i, KITS.length); applyKit(); return; }
  if (t === 1) { S.sound[1] = LIB.wrap(i, 128); fm.inst("t2").preset(S.sound[1]); return; }
  var list = SOUNDS[INST[t]], d = list[LIB.wrap(i, list.length)];
  S.sound[t] = LIB.wrap(i, list.length);
  var tbl = inst(t).params(), defaults = { wave1: 0, wave2: 1, pw: 0.5, semi2: 24, detune: 0.5, osc1: 1, osc2: 0.7, sub: 0, noise: 0, sync: 0, polymod: 0, cutoff: 0.55, res: 0.2, ftype: 0, envamt: 0.7, keytrack: 0.5, fa: 0.05, fd: 0.45, fs: 0.3, fr: 0.4, a: 0.02, d: 0.5, s: 0.8, r: 0.35, drive: 0.2, glide: 0, mode: 0, lforate: 0.5, lfowave: 0, lfopitch: 0, lfocutoff: 0, lfopw: 0, level: 0.8, vel: 0.5, spread: 0.3, line: 0, dcw: 0.3, dcwenv: 0.6, da: 0.02, dd: 0.5, ds: 0.3, dr: 0.4, fold: 0, vib: 0, vibrate: 0.55 };
  for (var k = 0; k < tbl.length; k++) {
    var n = tbl[k];
    inst(t).set(n, d[n] !== undefined ? d[n] : (defaults[n] !== undefined ? defaults[n] : 0));
  }
}
function applyKit() {
  var d = fm.inst("drums");
  for (var l = 0; l < LANES.length; l++) {
    d.set(LANES[l] + ".level", 100 / 127); d.set(LANES[l] + ".tune", 64 / 127);
    d.set(LANES[l] + ".decay", 64 / 127); d.set(LANES[l] + ".tone", 64 / 127);
  }
  var p = KITS[S.kit].p;
  for (var k in p) if (p.hasOwnProperty(k)) d.set(k, p[k]);
}

function onBoot() {
  fm.inst("t1").level(0.9); fm.inst("t2").level(0.9); fm.inst("t3").level(0.85); fm.inst("drums").level(1);
  if (!fm.store.get("init", false)) {
    for (var t = 0; t < 3; t++) loadSound(t, S.sound[t]);
    applyKit();
    fm.seq.tempo(96);
    fm.seq.swing(54);
    // a first beat so the tracks screen is not empty
    var kick = [0, 4, 8, 12], hat = [2, 6, 10, 14];
    for (var i = 0; i < 4; i++) { fm.seq.set(DR, 0, kick[i], { vel: 100 }, 0); fm.seq.set(DR, 0, hat[i], { vel: 70 }, 10); }
    fm.seq.set(DR, 0, 4, { vel: 100 }, 1); fm.seq.set(DR, 0, 12, { vel: 100 }, 1);
    fm.store.set("init", true);
  } else {
    fm.inst("t2").preset(S.sound[1]);
  }
  fm.fx("reverb", true, 1, 35, 22);
  fm.fx("delay", true, -1, 30, 25);
  fm.master({ filter: 0, dust: 0, duck: 0 });
}

// ---- keys ----
function synthNote(k) {
  var n;
  if (S.keys === 2) {                         // scale on the white keys
    var w = fm.whiteIndex(k); if (w < 0) return null;
    n = LIB.degree(60 + S.root, S.scale, w - 4);
  } else {
    n = 53 + k;
    if (S.keys === 1) n = LIB.snap(n, S.root, S.scale);
  }
  n += (S.octave + fm.octave()) * 12 + S.transpose;
  return LIB.chordNotes(n, S.chord, 60 + S.root, S.scale);
}
function padOf(k) {
  var w = fm.whiteIndex(k);
  if (w >= 0) return w;
  var b = fm.blackIndex(k); if (b < 0) return -1;
  // a black key doubles the white key on its left
  var whiteLeft = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14];
  return whiteLeft[b];
}
function padVel(p) {
  var v = LEVELS[drumHitLevel][1];
  if (PADS[p][1].slice(-1) === "2") v = Math.round(v * 0.8);
  return v;
}

function onKey(k, down, vel) {
  if (layer) { layerKey(layer, k, down); return; }
  if (screen === "page" && page && page.group === "SEQ") { seqLayerKey(k, fm.whiteIndex(k), fm.blackIndex(k), down); return; }
  var t = S.track;
  if (t === DR) {
    var p = padOf(k);
    if (p < 0 || !down) { if (!down && p >= 0) fm.inst("drums").off(PADS[p][0]); return; }
    var lane = PADS[p][0], v = padVel(p);
    if (repeatActive) fm.inst("drums").note(lane, v); else fm.inst("drums").hit(lane, v);
    keyFlash[k] = fm.now();
    if (armed && !fm.seq.playing() && S.recStart === 0) startRecording();
    if (recording) {
      var rate = [1, 1, 2, 3, 4][repeatRate];
      var st = fm.seq.recordHit(DR, lane, v);
      if (st < 0) { st = 0; fm.seq.set(DR, pat(DR), 0, { vel: v }, lane); }
      if (st >= 0 && repeatActive) fm.seq.set(DR, pat(DR), st, { ratchet: rate }, lane);
    }
    return;
  }
  if (down) {
    var notes = synthNote(k); if (!notes) return;
    if (armed && !fm.seq.playing() && S.recStart === 0) startRecording();
    heldKeys[k] = notes;
    for (var i = 0; i < notes.length; i++) {
      inst(t).note(notes[i], vel);
      if (recording && fm.seq.record(t, notes[i], vel) < 0) {
        // the transport is just starting: the first note lands on step 1
        var st0 = fm.seq.get(t, pat(t), 0), ns = st0.vel ? st0.notes : [];
        if (ns.indexOf(notes[i]) < 0 && ns.length < 4) ns.push(notes[i]);
        fm.seq.set(t, pat(t), 0, { vel: vel, notes: ns, len: 3 });
      }
      lastNote[t] = notes[0];
    }
  } else if (heldKeys[k]) {
    for (var j = 0; j < heldKeys[k].length; j++) inst(t).off(heldKeys[k][j]);
    delete heldKeys[k];
  }
}

// ---- layers ----
var PUNCH_WHITE = [["LOOP 1/4", "REPEAT", 1], ["LOOP 1/8", "REPEAT", 0.5], ["LOOP 1/16", "REPEAT", 0.25], ["LOOP 1/32", "REPEAT", 0.125],
  ["STUTTER", "STUTTER", 0.0625], ["REVERSE", "REVERSE", 1], ["TAPE STOP", "TAPE STOP", 1], ["HALF SPEED", "HALF SPEED", 1],
  ["FILTER DOWN", "LP SWEEP", 1], ["FILTER UP", "HP SWEEP", 1], ["PHONE", "KILL LOW", 1], ["BIT CRUSH", "CRUSH", 1],
  ["ALIAS", "CRUSH", 1], ["GATE", "GATE", 0.25], ["ECHO", "ECHO", 1], ["TAPE WOBBLE", null, 1]];
var PUNCH_BLACK = [["KILL LOW", "KILL LOW", 1], ["KILL MID", "KILL MID", 1], ["KILL HIGH", "KILL HIGH", 1], ["REWIND", "TAPE STOP", 1],
  ["OCTAVE UP", null, 1], ["FLANGER", null, 1], ["AUTO-PAN", null, 1], ["FREEZE", "REPEAT", 2], ["LOOP 1/8T", "REPEAT", 1 / 3],
  ["MONO", null, 1], ["FADE OUT", null, 1]];
var punchKey = -1;

function layerKey(name, k, down) {
  var w = fm.whiteIndex(k), b = fm.blackIndex(k);
  B.use(name);
  switch (name) {
    case "FX": {
      var def = w >= 0 ? PUNCH_WHITE[w] : PUNCH_BLACK[b];
      if (down) {
        punchKey = k;
        if (def[1]) { fm.punch(def[1], def[2]); say(def[0]); } else say(def[0] + " · n/a here");
      } else if (punchKey === k) { fm.punch("OFF"); punchKey = -1; }
      return;
    }
    case "GLO":
      if (!down) { if (w === 8) fm.seq.fill(false); return; }
      if (w >= 0 && w < 4) { mutes[w] = !mutes[w]; applyMix(); }
      else if (w >= 4 && w < 8) { solos[w - 4] = !solos[w - 4]; applyMix(); }
      else if (w === 8) fm.seq.fill(true);
      else if (w === 9) { fillNext = true; say("FILL NEXT BAR"); }
      else if (w === 15) tap();
      return;
    case "SAVE":
      if (!down || w < 0) return;
      if (w < 4) { chainKeys.push(w); playSection(w); }
      else if (w < 8) saveSection(w - 4);
      else if (w === 12) { var on = !fm.seq.songOn(); fm.seq.songOn(on); say(on ? "SONG" : "LOOP"); }
      else if (w === 13) say("SONG REC · n/a here");
      else if (w === 15) startChain();
      return;
    case "SEQ": seqLayerKey(k, w, b, down); return;
    case "SEL":
      if (down && w >= 0) { S.root = LIB.wrap(53 + k, 12); saveUI(); say("KEY " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "")); }
      return;
    case "EDIT":
      if (!down) return;
      if (b >= 0 && S.track === DR) { var lane = PADS[padOf(k)][0]; var m = !fm.seq.laneMute(DR, lane); fm.seq.laneMute(DR, lane, m); say(LANES[lane] + (m ? " MUTE" : " ON")); return; }
      eraseKey(k);
      return;
    case "ARP":
      onKeyPlain(k, down);
      return;
  }
}
function onKeyPlain(k, down) { var l = layer; layer = null; onKey(k, down, fm.velocity()); layer = l; }

function seqLayerKey(k, w, b, down) {
  var t = S.track, p = pat(t);
  if (w < 0) {
    if (down && t === DR) { S.lane = PADS[padOf(k)][0]; fm.inst("drums").hit(S.lane, 90); }
    return;
  }
  var s = stepPage * 16 + w;
  if (down) {
    heldStep = s;
    B.use("SEQ");
  } else if (heldStep === s) {
    if (!stepTouched) toggleStep(t, p, s);
    heldStep = -1; stepTouched = false;
  }
}
var stepTouched = false;
function toggleStep(t, p, s) {
  undo.push(t, p);
  if (t === DR) {
    var st = fm.seq.get(t, p, s, S.lane);
    if (st.vel) fm.seq.clear(t, p, s, S.lane); else { fm.seq.set(t, p, s, { vel: LEVELS[drumHitLevel][1] }, S.lane); fm.inst("drums").hit(S.lane, 90); }
  } else {
    var cur = fm.seq.get(t, p, s);
    if (cur.vel) fm.seq.clear(t, p, s);
    else fm.seq.set(t, p, s, { vel: 100, notes: [lastNote[t] || 60], len: 3 });
  }
}
var lastNote = [48, 60, 72, 0];

function eraseKey(k) {
  var t = S.track, p = pat(t);
  undo.push(t, p);
  if (t === DR) {
    var lane = PADS[padOf(k)][0];
    if (!fm.seq.playing()) { fm.seq.clear(DR, p, -1, lane); say("ERASED " + LANES[lane]); }
    else eraseHeld = { k: k, lane: lane };
  } else {
    var notes = synthNote(k) || [];
    for (var s = 0; s < 64; s++) {
      var st = fm.seq.get(t, p, s);
      if (st.vel && st.notes.indexOf(notes[0]) >= 0) {
        if (fm.seq.playing() && s !== fm.seq.step(t)) continue;
        var rest = st.notes.filter(function (n) { return n !== notes[0]; });
        if (rest.length) fm.seq.set(t, p, s, { notes: rest }); else fm.seq.clear(t, p, s);
      }
    }
    if (fm.seq.playing()) eraseHeld = { k: k, note: notes[0] };
  }
}
var eraseHeld = null;

function applyMix() {
  var anySolo = solos.indexOf(true) >= 0;
  for (var t = 0; t < 4; t++) fm.seq.mute(t, mutes[t] || (anySolo && !solos[t]));
}
function tap() {
  var now = fm.now();
  tapTimes = tapTimes.filter(function (x) { return now - x < 2500; });
  tapTimes.push(now);
  if (tapTimes.length >= 2) {
    var d = (tapTimes[tapTimes.length - 1] - tapTimes[0]) / (tapTimes.length - 1);
    fm.seq.tempo(Math.round(60000 / d));
  }
  say("TAP " + Math.round(fm.seq.tempo()) + " BPM");
}
function saveSection(i) {
  for (var t = 0; t < 4; t++) fm.seq.copy(t, pat(t), i);
  sections[i] = true; fm.store.set("sections", sections);
  say("SAVED " + "ABCD"[i]);
}
function playSection(i) {
  if (!sections[i]) { say("SECTION " + "ABCD"[i] + " EMPTY"); return; }
  for (var t = 0; t < 4; t++) fm.seq.select(t, i);
  say("NEXT: " + "ABCD"[i]);
}
function startChain() {
  var list = [];
  for (var i = 0; i < 4; i++) if (sections[i]) list.push({ patterns: [i, i, i, i], repeats: 1 });
  if (!list.length) { say("SAVE A SECTION FIRST"); return; }
  fm.seq.song(list, true); fm.seq.songOn(true); say("CHAIN " + list.length);
}

// ---- buttons ----
var LAYER_BUTTONS = { FX: 1, SEL: 1, EDIT: 1, GLO: 1, ARP: 1, SEQ: 1, SAVE: 1 };
function onButton(name, down) {
  if (down) {
    B.press(name);
    if (name === "HOME" && layer && LAYER_BUTTONS[layer]) { locked = locked === layer ? null : layer; B.use(layer); say(locked ? layer + " LOCKED" : "UNLOCKED"); return; }
    if (name === "OCT-" || name === "OCT+") { octDown(name); return; }
    if (LAYER_BUTTONS[name] && !locked) { layer = name; if (name === "SEQ") stepPage = Math.floor(Math.max(0, fm.seq.step(S.track)) / 16); if (name === "ARP") setRepeat(true); }
    return;
  }
  var kind = B.release(name);
  if (name === "OCT-" || name === "OCT+") { octUp(name, kind); return; }
  if (LAYER_BUTTONS[name] && layer === name && !locked) {
    layer = null; heldStep = -1;
    if (name === "ARP") setRepeat(false);
    if (name === "FX" && punchKey >= 0) { fm.punch("OFF"); punchKey = -1; }
    if (name === "GLO") fm.seq.fill(false);
    if (name === "SAVE" && chainKeys.length > 1) {
      var list = chainKeys.filter(function (i) { return sections[i]; }).map(function (i) { return { patterns: [i, i, i, i], repeats: 1 }; });
      if (list.length) { fm.seq.song(list, true); fm.seq.songOn(true); say("QUICK CHAIN " + list.length); }
    }
    chainKeys = [];
    if (kind === "hold") return;
  }
  if (kind === "hold") {
    if (name === "REC" && B.heldFor !== undefined) return;
    if (name === "HOME") { openPage("MENU", 0); return; }
    return;
  }
  // taps
  switch (name) {
    case "HOME": screen = screen === "tracks" ? "visual" : "tracks"; page = null; break;
    case "PLAY": togglePlay(); break;
    case "REC": recButton(); break;
    case "SAVE": if (screen === "tracks") openPage("SONG", 0); else openPage("SONG", 0); break;
    default: openPage(name, null);
  }
}
function octDown(name) {
  var other = name === "OCT-" ? "OCT+" : "OCT-";
  if (B.isDown("EDIT")) { B.use("EDIT"); if (name === "OCT-" ? undo.undo() : undo.redoOne()) say(name === "OCT-" ? "UNDO" : "REDO"); else say("NOTHING TO " + (name === "OCT-" ? "UNDO" : "REDO")); return; }
  if (layer === "SEQ" && heldStep >= 0) {
    stepTouched = true;
    if (name === "OCT+") {
      var t = S.track, row = t === DR ? S.lane : 0, st = fm.seq.get(t, pat(t), heldStep, row);
      var c = (st.cond + 1) % 3; fm.seq.set(t, pat(t), heldStep, { cond: c }, row);
      say(["ALWAYS", "FILL ONLY", "NO FILL"][c]);
    }
    return;
  }
  if (layer === "SEQ") { stepPage = LIB.clamp(stepPage + (name === "OCT+" ? 1 : -1), 0, 3); B.use("SEQ"); return; }
  if (S.track === DR && !layer) { drumHitLevel = name === "OCT-" ? 0 : 3; return; }
  if (B.isDown(other)) { S.octave = 0; saveUI(); say("OCTAVE 0"); B.use(other); B.use(name); }
}
function octUp(name, kind) {
  if (S.track === DR && !layer) { drumHitLevel = 2; return; }
  if (kind !== "tap" && kind !== "double") return;
  if (layer) return;
  S.octave = LIB.clamp(S.octave + (name === "OCT+" ? 1 : -1), -3, 3); saveUI();
  say("OCTAVE " + S.octave);
}
function togglePlay() {
  if (fm.seq.playing()) { fm.seq.stop(); recording = false; for (var t = 0; t < 3; t++) inst(t).allOff(); }
  else { if (armed) startRecording(); else fm.seq.play(); }
}
function startRecording() {
  recording = true; armed = false;
  var bars = [1, 2, 4][S.recLen];
  if (!fm.seq.has(S.track, pat(S.track))) fm.seq.length(S.track, pat(S.track), 16 * bars);
  undo.push(S.track, pat(S.track));
  if (!fm.seq.playing()) fm.seq.play();
  screen = "tracks"; page = null;
}
function recButton() {
  if (fm.seq.playing()) { if (recording) { recording = false; say("REC OFF"); } else { undo.push(S.track, pat(S.track)); recording = true; say("RECORDING"); } return; }
  armed = !armed;
  if (armed) { screen = "rec"; page = null; } else screen = "tracks";
}

// ---- pages ----
var GROUPS = {
  FX: ["MASTER", "SENDS"], SEL: ["KEY"], ENV: ["ENV"], LFO: ["LFO"], EDIT: ["SOUND 1", "SOUND 2", "SOUND 3"],
  GLO: ["GLOBAL"], ARP: ["REPEAT"], SEQ: ["STEPS"], SONG: ["SONG"], MENU: ["ABOUT"]
};
function openPage(group, index) {
  if (!GROUPS[group]) return;
  if (page && page.group === group && index === null) page.index = (page.index + 1) % GROUPS[group].length;
  else page = { group: group, index: index || 0 };
  if (S.track === DR && group === "EDIT") page.group = "KIT";
  screen = "page";
}

// knob definitions for the current context: [label, value text, fraction, onTurn(d)]
function P(name, label, t) {
  t = t === undefined ? S.track : t;
  var i = inst(t);
  return [label || name.toUpperCase(), function () { var v = i.get(name); return isDiscrete(t, name) ? String(v) : String(Math.round(v * 100)); },
    function () { var v = i.get(name); return isDiscrete(t, name) ? 0.5 : v; },
    function (d) { var v = i.get(name); i.set(name, isDiscrete(t, name) ? v + d : LIB.clamp(v + d * 0.01, 0, 1)); }];
}
function isDiscrete(t, name) { return ["wave1", "wave2", "semi2", "sync", "ftype", "mode", "lfowave", "line"].indexOf(name) >= 0; }
function knobsNow() {
  var t = S.track;
  if (layer === "FX") return [M("filter", "FILTER", -1, 1), M("dust", "DUST", 0, 1), M("duck", "DUCK", 0, 1), t === DR ? KNONE : P(t === 1 ? "op1.level" : (t === 2 ? "dcw" : "cutoff"), "TRK FILT")];
  if (layer === "GLO") return [0, 1, 2, 3].map(function (i) { return LV(i); });
  if (layer === "SEL") return [["CHORD", function () { return LIB.CHORDS[S.chord]; }, function () { return S.chord / 5; }, function (d) { S.chord = LIB.clamp(S.chord + d, 0, 5); saveUI(); }],
    ["SCALE", function () { return LIB.SCALES[S.scale][0]; }, function () { return S.scale / 15; }, function (d) { S.scale = LIB.wrap(S.scale + d, 16); saveUI(); }],
    ["KEYS", function () { return ["CHROM", "SNAP", "WHITE"][S.keys]; }, function () { return S.keys / 2; }, function (d) { S.keys = LIB.clamp(S.keys + d, 0, 2); saveUI(); }],
    ["TRANSP", function () { return String(S.transpose); }, function () { return (S.transpose + 12) / 24; }, function (d) { S.transpose = LIB.clamp(S.transpose + d, -12, 12); saveUI(); }]];
  if (layer === "EDIT") return [["SHIFT", function () { return "◀ ▶"; }, function () { return 0.5; }, function (d) { undo.push(t, pat(t)); LIB.shift(t, pat(t), d > 0 ? 1 : -1); }],
    ["LENGTH", function () { return String(fm.seq.length(t, pat(t))); }, function () { return fm.seq.length(t, pat(t)) / 64; }, function (d) { var L = fm.seq.length(t, pat(t)); undo.push(t, pat(t)); if (d > 0) LIB.double(t, pat(t)); else fm.seq.length(t, pat(t), Math.max(1, L >> 1)); }],
    ["TRANSP", function () { return "±1"; }, function () { return 0.5; }, function (d) { if (t !== DR) transposePattern(t, d); }], KNONE];
  if (layer === "ARP") return [["RATE", function () { return REPEAT_NAMES[repeatRate]; }, function () { return repeatRate / 4; }, setRepeatRate], KNONE, KNONE, KNONE];
  if (layer === "SEQ") {
    if (heldStep >= 0) return stepKnobs();
    return [t === DR ? ["SOUND", function () { return LANES[S.lane]; }, function () { return S.lane / 10; }, function (d) { S.lane = LIB.clamp(S.lane + d, 0, 10); }]
                     : ["NOTE", function () { return LIB.noteName(lastNote[t] || 60); }, function () { return ((lastNote[t] || 60) - 24) / 72; }, function (d) { lastNote[t] = LIB.clamp((lastNote[t] || 60) + d, 24, 96); }],
      ["DIV", function () { return fm.seq.divNames[fm.seq.div(t, pat(t))]; }, function () { return fm.seq.div(t, pat(t)) / 9; }, function (d) { fm.seq.div(t, pat(t), LIB.clamp(fm.seq.div(t, pat(t)) + d, 0, 9)); }],
      ["SWING", function () { return String(Math.round((fm.seq.swing() - 50) * 4)); }, function () { return (fm.seq.swing() - 50) / 25; }, function (d) { fm.seq.swing(LIB.clamp(fm.seq.swing() + d * 0.25, 50, 75)); }],
      ["LENGTH", function () { return String(fm.seq.length(t, pat(t))); }, function () { return fm.seq.length(t, pat(t)) / 64; }, function (d) { fm.seq.length(t, pat(t), LIB.clamp(fm.seq.length(t, pat(t)) + d, 1, 64)); }]];
  }
  if (screen === "rec") return [["MODE", function () { return "TEMPO"; }, function () { return 1; }, function () { say("FREE MODE · n/a here"); }],
    ["LENGTH", function () { return ["1 BAR", "2 BARS", "4 BARS"][S.recLen]; }, function () { return S.recLen / 2; }, function (d) { S.recLen = LIB.clamp(S.recLen + d, 0, 2); saveUI(); }],
    ["START", function () { return ["1ST NOTE", "PLAY"][S.recStart]; }, function () { return S.recStart; }, function (d) { S.recStart = LIB.clamp(S.recStart + d, 0, 1); saveUI(); }],
    ["BPM", function () { return String(Math.round(fm.seq.tempo())); }, function () { return (fm.seq.tempo() - 40) / 200; }, function (d) { fm.seq.tempo(fm.seq.tempo() + d); }]];
  if (screen === "page" && page) return pageKnobs();
  // tracks screen: the selected track's four main controls
  if (t === DR) return [KIT("BD", "decay", "KICK"), KIT("SD", "tone", "SNARE"), KIT("CH", "decay", "HATS"), LV(DR)];
  if (t === 1) return [P("op1.level", "OP1 LVL"), P("op2.level", "OP2 LVL"), P("feedback", "FEEDBK"), LV(1)];
  if (t === 2) return [P("dcw", "DCW"), P("dcwenv", "DCW ENV"), P("r", "RELEASE"), LV(2)];
  return [P("cutoff", "CUTOFF"), P("res", "RESO"), P("envamt", "ENV"), LV(0)];
}
var KNONE = null;
function M(key, label, lo, hi) {
  return [label, function () { return String(Math.round(master[key] * 100)); }, function () { return (master[key] - lo) / (hi - lo); },
    function (d) { master[key] = LIB.clamp(master[key] + d * 0.02, lo, hi); fm.master(master); B.use("FX"); }];
}
var master = fm.store.get("master", { filter: 0, dust: 0, duck: 0 });
function LV(t) { return ["LEVEL " + (t + 1), function () { return String(Math.round(inst(t).level() * 100)); }, function () { return inst(t).level(); }, function (d) { inst(t).level(LIB.clamp(inst(t).level() + d * 0.02, 0, 1)); B.use("GLO"); }]; }
function KIT(lane, p, label) {
  var key = lane + "." + p;
  return [label + " " + p.toUpperCase().slice(0, 3), function () { return String(Math.round(fm.inst("drums").get(key) * 127)); }, function () { return fm.inst("drums").get(key); },
    function (d) { fm.inst("drums").set(key, LIB.clamp(fm.inst("drums").get(key) + d / 127, 0, 1)); }];
}
function transposePattern(t, d) {
  undo.push(t, pat(t));
  for (var s = 0; s < 64; s++) { var st = fm.seq.get(t, pat(t), s); if (st.vel) fm.seq.set(t, pat(t), s, { notes: st.notes.map(function (n) { return LIB.clamp(n + d, 12, 120); }) }); }
}
function stepKnobs() {
  var t = S.track, p = pat(t), row = t === DR ? S.lane : 0;
  function get() { return fm.seq.get(t, p, heldStep, row); }
  function set(o) { stepTouched = true; if (get().vel === 0) o.vel = o.vel || 100, o.notes = o.notes || [lastNote[t] || 60]; fm.seq.set(t, p, heldStep, o, row); }
  return [t === DR ? ["SOUND", function () { return LANES[S.lane]; }, function () { return S.lane / 10; }, function (d) { S.lane = LIB.clamp(S.lane + d, 0, 10); stepTouched = true; }]
                   : ["NOTE", function () { var st = get(); return st.vel ? LIB.noteName(st.notes[0]) : "--"; }, function () { return 0.5; }, function (d) { var st = get(); set({ notes: [(st.notes[0] || 60) + d] }); }],
    [t === DR ? "LEVEL" : "VELOCITY", function () { var st = get(); return t === DR ? (st.vel ? LEVELS[levelIndex(st.vel)][0] : "--") : String(st.vel); }, function () { return get().vel / 127; },
      function (d) { var st = get(); set({ vel: t === DR ? LEVELS[LIB.clamp(levelIndex(st.vel || 100) + d, 0, 3)][1] : LIB.clamp((st.vel || 100) + d * 4, 1, 127) }); }],
    ["RATCHET", function () { return "x" + get().ratchet; }, function () { return (get().ratchet - 1) / 3; }, function (d) { set({ ratchet: LIB.clamp(get().ratchet + d, 1, 4) }); }],
    ["NUDGE", function () { var n = get().nudge * 4; return (n > 0 ? "+" : "") + n; }, function () { return (get().nudge + 8) / 15; }, function (d) { set({ nudge: LIB.clamp(get().nudge + d, -8, 7) }); }]];
}
function levelIndex(v) { return v < 50 ? 0 : v < 80 ? 1 : v < 115 ? 2 : 3; }
function pageKnobs() {
  var t = S.track, g = page.group, i = page.index;
  if (g === "MASTER" || (g === "FX" && i === 0)) return [M("filter", "FILTER", -1, 1), M("dust", "DUST", 0, 1), M("duck", "DUCK", 0, 1), ["TEMPO", function () { return String(Math.round(fm.seq.tempo())); }, function () { return (fm.seq.tempo() - 40) / 200; }, function (d) { fm.seq.tempo(fm.seq.tempo() + d); }]];
  if (g === "FX") return [FXK("reverb", 1, "REVERB"), FXK("delay", 1, "DELAY"), FXK("chorus", 1, "CHORUS"), FXK("distortion", 1, "DRIVE")];
  if (g === "ENV") return t === DR ? [KIT("BD", "decay", "KICK"), KIT("SD", "decay", "SNARE"), KIT("OH", "decay", "OPEN"), KIT("CY", "decay", "CYM")]
    : t === 1 ? [FMR(0), FMR(1), FMR(2), FMR(3)] : [P("a", "ATTACK"), P("d", "DECAY"), P("s", "SUSTAIN"), P("r", "RELEASE")];
  if (g === "LFO") return t === 0 ? [P("lforate", "RATE"), P("lfopitch", "PITCH"), P("lfocutoff", "FILTER"), P("lfopw", "PW")]
    : t === 2 ? [P("vibrate", "RATE"), P("vib", "DEPTH"), KNONE, KNONE] : t === 1 ? [P("lfospeed", "SPEED"), P("lfopmd", "PMD"), P("lfoamd", "AMD"), KNONE] : [KNONE, KNONE, KNONE, KNONE];
  if (g === "SOUND 1" || g === "SOUND 2" || g === "SOUND 3" || g === "EDIT") {
    if (t === 0) return [[P("wave1", "WAVE 1"), P("wave2", "WAVE 2"), P("semi2", "SEMI 2"), P("detune", "DETUNE")], [P("cutoff", "CUTOFF"), P("res", "RESO"), P("ftype", "TYPE"), P("drive", "DRIVE")], [P("mode", "VOICE"), P("glide", "GLIDE"), P("sub", "SUB"), P("noise", "NOISE")]][i];
    if (t === 2) return [[P("wave1", "WAVE 1"), P("wave2", "WAVE 2"), P("line", "LINE"), P("semi2", "SEMI 2")], [P("dcw", "DCW"), P("dcwenv", "DCW ENV"), P("dd", "DCW DEC"), P("fold", "FOLD")], [P("mode", "VOICE"), P("glide", "GLIDE"), P("detune", "DETUNE"), P("vel", "VELO")]][i];
    if (t === 1) return [[P("algorithm", "ALGO"), P("feedback", "FEEDBK"), P("op1.coarse", "OP1 RAT"), P("op2.coarse", "OP2 RAT")], [P("op1.level", "OP1 LVL"), P("op2.level", "OP2 LVL"), P("op3.level", "OP3 LVL"), P("op4.level", "OP4 LVL")], [P("op5.level", "OP5 LVL"), P("op6.level", "OP6 LVL"), P("transpose", "TRANSP"), KNONE]][i];
  }
  if (g === "KIT") return [KIT(LANES[S.lane], "level", LANES[S.lane]), KIT(LANES[S.lane], "tune", LANES[S.lane]), KIT(LANES[S.lane], "decay", LANES[S.lane]), KIT(LANES[S.lane], "tone", LANES[S.lane])];
  if (g === "GLO") return [["BPM", function () { return String(Math.round(fm.seq.tempo())); }, function () { return (fm.seq.tempo() - 40) / 200; }, function (d) { fm.seq.tempo(fm.seq.tempo() + d); }],
    ["SWING", function () { return String(Math.round((fm.seq.swing() - 50) * 4)); }, function () { return (fm.seq.swing() - 50) / 25; }, function (d) { fm.seq.swing(LIB.clamp(fm.seq.swing() + d * 0.25, 50, 75)); }], KNONE, KNONE];
  if (g === "ARP") return [["RATE", function () { return REPEAT_NAMES[repeatRate]; }, function () { return repeatRate / 4; }, setRepeatRate], KNONE, KNONE, KNONE];
  if (g === "SEQ") { var l = layer; layer = "SEQ"; var k = knobsNow(); layer = l; return k; }
  return [KNONE, KNONE, KNONE, KNONE];
}
function FMR(op) { return P("op" + (op + 1) + ".level", "OP" + (op + 1)); }
var fxState = fm.store.get("fx", { reverb: [true, 35], delay: [true, 30], chorus: [false, 40], distortion: [false, 30] });
function FXK(kind, slot, label) {
  return [label, function () { return fxState[kind][0] ? String(fxState[kind][1]) : "OFF"; }, function () { return fxState[kind][0] ? fxState[kind][1] / 100 : 0; },
    function (d) {
      var v = fxState[kind][1] + d * 2; fxState[kind] = [v > 0, LIB.clamp(v, 0, 100)];
      if (kind === "reverb") fm.fx("reverb", fxState[kind][0], 1, fxState[kind][1], 22);
      else if (kind === "delay") fm.fx("delay", fxState[kind][0], -1, fxState[kind][1], 25);
      else fm.fx(kind, fxState[kind][0], fxState[kind][1], fxState[kind][1], 50);
      fm.store.set("fx", fxState);
    }];
}

function onKnob(i, d) {
  var ks = knobsNow(), k = ks[i];
  if (layer) B.use(layer);
  if (!k) return;
  k[3](d);
  if (layer === "FX" || (page && page.group === "MASTER")) fm.store.set("master", master);
}

function onEncoder(name, d) {
  if (name === "ALGORITHM") {
    if (layer === "SEQ" && heldStep >= 0) { var n = inst(S.track).params().length || 1; lockParam = LIB.wrap(lockParam + d, n); stepTouched = true; say("LOCK " + (inst(S.track).params()[lockParam] || "--")); return; }
    for (var t = 0; t < 3; t++) inst(t).allOff();
    S.track = LIB.clamp(S.track + d, 0, 3); saveUI(); if (repeatActive) setRepeat(true); return;
  }
  if (name === "PRESETS") {
    if (layer === "SEQ" && heldStep >= 0 && S.track !== DR) {
      var t2 = S.track, names = inst(t2).params(); if (!names.length) return;
      lockParam = LIB.wrap(lockParam, names.length);          // the picker may have been set on another track
      var st = fm.seq.get(t2, pat(t2), heldStep), cur = st.locks.length ? st.locks[0][1] : 128;
      fm.seq.set(t2, pat(t2), heldStep, { locks: [[names[lockParam], LIB.clamp(cur + d * 4, 0, 255)]] });
      stepTouched = true; say("LOCK " + names[lockParam] + " " + Math.round(LIB.clamp(cur + d * 4, 0, 255) / 2.55)); return;
    }
    loadSound(S.track, (S.track === DR ? S.kit : S.sound[S.track]) + d); saveUI();
    say((S.track === DR ? "KIT " : "") + soundName(S.track)); return;
  }
  if (name === "SELECT") {
    if (screen === "visual") { visStyle = LIB.wrap(visStyle + d, 4); return; }
    if (screen === "page" && page && GROUPS[page.group] && !layer) { page.index = LIB.wrap(page.index + d, GROUPS[page.group].length); return; }
    if (screen === "page" && page && (page.group === "KIT")) { S.lane = LIB.clamp(S.lane + d, 0, 10); return; }
    fm.seq.tempo(LIB.clamp(fm.seq.tempo() + d, 40, 240));
    if (layer) B.use(layer);
  }
}

// ---- time ----
function onTick(ms) {
  // REC held ~2 s clears the track
  if (B.heldFor("REC") > 2000 && !B.used.REC) {
    B.use("REC"); undo.push(S.track, pat(S.track)); fm.seq.clear(S.track, pat(S.track)); say("TRACK " + (S.track + 1) + " CLEARED");
  }
  // fill on the next bar
  var beat = fm.seq.beat();
  if (beat >= 0) {
    var bar = Math.floor(beat / 4);
    if (fillNext && bar !== lastBeat) { fm.seq.fill(true); fillNext = "on"; lastBeat = bar; }
    else if (fillNext === "on" && bar !== lastBeat) { fm.seq.fill(false); fillNext = false; }
    if (lastBeat < 0) lastBeat = bar;
  }
  // live erase while EDIT is held on a moving loop
  if (eraseHeld && B.isDown("EDIT") && fm.seq.playing()) {
    var t = S.track, s = fm.seq.step(t);
    if (s >= 0) {
      if (t === DR) fm.seq.clear(DR, pat(DR), s, eraseHeld.lane);
      else { var st = fm.seq.get(t, pat(t), s); if (st.vel && st.notes.indexOf(eraseHeld.note) >= 0) fm.seq.clear(t, pat(t), s); }
    }
  } else eraseHeld = null;
}

// ---- drawing ----
function header(g, title, col) {
  g.rect(0, 0, 240, 24, C.panel);
  g.rect(6, 4, 22, 16, col, 4);
  g.text(17, 5, String(S.track + 1), { size: 12, weight: "bold", align: "center", color: "#0b0d12" });
  g.text(34, 4, title, { size: 13, weight: "bold", color: C.white });
  var playing = fm.seq.playing();
  g.text(234, 5, Math.round(fm.seq.tempo()) + (playing ? " ▶" : " ■"), { size: 12, weight: "bold", align: "right", color: recording ? C.red : (playing ? "#5dff7a" : C.grey) });
}
function knobRow(g, ks) {
  for (var i = 0; i < 4; i++) {
    var x = 30 + i * 60, y = 202, k = ks[i];
    if (!k) { g.ring(x, y, 14, "#ffffff18", 3); continue; }
    LIB.knob(g, x, y, 15, k[2](), TC[i]);
    g.text(x, y - 7, k[1](), { size: 10, weight: "bold", align: "center", color: C.white });
    g.text(x, 222, k[0], { size: 9, weight: "bold", align: "center", color: TC[i] });
  }
}
function stepsOf(t, p) {
  var out = [], rows = fm.seq.rows(t);
  for (var s = 0; s < 16; s++) {
    var on = false;
    for (var r = 0; r < rows && !on; r++) if (fm.seq.get(t, p, s, r).vel) on = true;
    out.push(on);
  }
  return out;
}
function drawTracks(g) {
  header(g, "TRACKS" + (fm.seq.songOn() ? " · SONG " + "ABCD".charAt(fm.seq.songSection()) : ""), TC[S.track]);
  for (var t = 0; t < 4; t++) {
    var y = 30 + t * 40, sel = t === S.track, p = pat(t);
    g.rect(4, y, 232, 36, sel ? "#222838" : C.panel, 6);
    if (sel) g.frame(4, y, 232, 36, TC[t], 1.5, 6);
    g.rect(10, y + 6, 22, 24, TC[t], 5);
    g.text(21, y + 10, String(t + 1), { size: 13, weight: "bold", align: "center", color: "#0b0d12" });
    var muted = fm.seq.mute(t);
    g.text(40, y + 3, soundName(t).slice(0, 14), { size: 11, weight: "bold", color: muted ? C.grey : C.white });
    g.text(232, y + 3, (muted ? "MUTE " : "") + ENGINE[t] + " " + "ABCD".charAt(p % 4), { size: 9, align: "right", color: C.grey });
    var st = stepsOf(t, p), cur = fm.seq.step(t);
    for (var s = 0; s < 16; s++) {
      var x = 40 + s * 12, c = st[s] ? TC[t] : "#ffffff22";
      if (cur >= 0 && cur % 16 === s) c = C.white;
      g.rect(x, y + 22, 9, 8, c, 2);
    }
    var m = inst(t).meter();
    g.rect(226, y + 30 - 22 * Math.min(1, m), 4, 22 * Math.min(1, m), TC[t], 1);
  }
}
function drawGrid(g) {
  // the SEQ layer / drum grid: 4 × 4 steps of the page
  var t = S.track, p = pat(t), row = t === DR ? S.lane : 0, cur = fm.seq.step(t);
  header(g, (t === DR ? "DRUMS GRID · " + LANES[S.lane] : "SEQ · " + ENGINE[t]) + "  " + (stepPage + 1) + "/4", TC[t]);
  for (var i = 0; i < 16; i++) {
    var s = stepPage * 16 + i, x = 12 + (i % 4) * 56, y = 30 + Math.floor(i / 4) * 40;
    var st = fm.seq.get(t, p, s, row), inLen = s < fm.seq.length(t, p);
    g.rect(x, y, 50, 34, st.vel ? TC[t] : (inLen ? "#ffffff1c" : "#ffffff08"), 5);
    if (s === heldStep) g.frame(x - 1, y - 1, 52, 36, C.white, 2, 6);
    else if (s === cur) g.frame(x, y, 50, 34, "#ffffffaa", 1.5, 5);
    if (st.vel) {
      var lbl = t === DR ? LEVELS[levelIndex(st.vel)][0] : LIB.noteName(st.notes[0] || 60);
      g.text(x + 25, y + 4, lbl, { size: 11, weight: "bold", align: "center", color: "#0b0d12" });
      var tags = (st.ratchet > 1 ? "x" + st.ratchet + " " : "") + (st.cond === 1 ? "FILL " : st.cond === 2 ? "!FILL " : "") + (st.locks.length ? "◆" : "") + (st.nudge ? "~" : "");
      if (tags) g.text(x + 25, y + 19, tags, { size: 9, align: "center", color: "#0b0d12" });
    } else g.text(x + 4, y + 2, String(s + 1), { size: 8, color: "#ffffff40" });
  }
}
function drawKit(g) {
  header(g, "DRUMS KIT · " + KITS[S.kit].name, C.t4);
  for (var i = 0; i < 16; i++) {
    var x = 12 + (i % 4) * 56, y = 30 + Math.floor(i / 4) * 40, lane = PADS[i][0];
    var lit = fm.now() - (keyFlash[fm.keyOfWhite(i)] || 0) < 150;
    g.rect(x, y, 50, 34, lane === S.lane ? "#ff8a3d55" : "#ffffff16", 5);
    if (lit) g.rect(x, y, 50, 34, C.t4, 5);
    g.text(x + 25, y + 10, PADS[i][1], { size: 9, weight: "bold", align: "center", color: C.white });
  }
}
function drawLayerHint(g, title, rows) {
  header(g, title, TC[S.track]);
  for (var i = 0; i < rows.length; i++) g.text(14, 34 + i * 17, rows[i], { size: 11, color: i === 0 ? C.white : "#c8cfdc" });
}
function drawPage(g) {
  var grp = page.group, name = GROUPS[grp] ? GROUPS[grp][page.index] : grp;
  if (grp === "KIT") { drawKit(g); return; }
  if (grp === "STEPS" || grp === "SEQ") { drawGrid(g); return; }
  if (grp === "SONG") { drawSong(g); return; }
  if (grp === "MENU") { drawLayerHint(g, "MENU · ABOUT", ["SLOOP 2.8 for FM Pocket", "A re-implementation from", "the SLOOP manual.", "Original: isod89 / 3dSam,", "GPL-3.0. No SLOOP code.", "", "HOME: back"]); return; }
  header(g, grp + (GROUPS[grp] && GROUPS[grp].length > 1 ? " · " + name + " " + (page.index + 1) + "/" + GROUPS[grp].length : ""), TC[S.track]);
  g.text(120, 60, soundName(S.track), { size: 18, weight: "bold", align: "center", color: TC[S.track] });
  g.text(120, 88, ENGINE[S.track], { size: 11, align: "center", color: C.grey });
  g.scope(20, 112, 200, 60, LIB.hexA(TC[S.track], "cc"), 1.5);
}
function drawSong(g) {
  header(g, "SONG · SECTIONS A–D", C.t4);
  for (var i = 0; i < 4; i++) {
    var x = 12 + i * 56, playing = fm.seq.songOn() && fm.seq.songSection() === i;
    var current = pat(0) === i;
    g.rect(x, 40, 50, 60, sections[i] ? (current ? C.t4 : "#ff8a3d55") : "#ffffff12", 6);
    if (playing) g.frame(x - 1, 39, 52, 62, C.white, 2, 7);
    g.text(x + 25, 52, "ABCD".charAt(i), { size: 24, weight: "bold", align: "center", color: sections[i] ? "#0b0d12" : "#ffffff40" });
  }
  g.text(120, 112, fm.seq.songOn() ? "SONG / CHAIN ON" : "LOOP", { size: 12, weight: "bold", align: "center", color: C.white });
  g.text(120, 132, "hold SAVE: 1–4 play · 5–8 save", { size: 10, align: "center", color: C.grey });
  g.text(120, 146, "13 loop/song · 16 chain", { size: 10, align: "center", color: C.grey });
}
function drawRec(g) {
  header(g, "REC · TRACK " + (S.track + 1), C.red);
  g.circle(120, 70, 22, armed ? C.red : "#ff4a3d55");
  g.text(120, 104, armed ? (S.recStart === 0 ? "PLAY A NOTE TO START" : "PRESS PLAY") : "", { size: 12, weight: "bold", align: "center", color: C.white });
  g.text(120, 124, "tempo mode · " + ["1 BAR", "2 BARS", "4 BARS"][S.recLen], { size: 11, align: "center", color: C.grey });
}
function drawVisual(g) {
  var col = TC[visStyle % 4];
  g.clear("#000000");
  if (visStyle === 1) { for (var i = 0; i < 4; i++) g.scope(10, 30 + i * 50, 220, 40, LIB.hexA(TC[i], "aa"), 1); }
  else if (visStyle === 2) { var m = 0; for (var t = 0; t < 4; t++) { m = inst(t).meter(); g.ring(120, 120, 20 + t * 22 + m * 12, TC[t], 3); } }
  else if (visStyle === 3) { for (var t2 = 0; t2 < 4; t2++) { var mm = Math.min(1, inst(t2).meter()); g.rect(20 + t2 * 52, 220 - 200 * mm, 40, 200 * mm, TC[t2], 4); } }
  else g.scope(0, 40, 240, 160, col, 2);
}

function render(g) {
  g.clear(C.bg);
  var showKnobs = true;
  if (screen === "visual" && !layer) { drawVisual(g); showKnobs = false; }
  else if (layer === "SEQ") drawGrid(g);
  else if (layer === "FX") drawLayerHint(g, "FX · PUNCH", ["white: loops 1/4–1/32, stutter, reverse,", "tape stop, half speed, filter, phone,", "crush, alias, gate, echo", "black: kills low/mid/high, rewind,", "freeze, loop 1/8T (some n/a here)", "", punchKey >= 0 ? "▶ " + (fm.whiteIndex(punchKey) >= 0 ? PUNCH_WHITE[fm.whiteIndex(punchKey)][0] : PUNCH_BLACK[fm.blackIndex(punchKey)][0]) : ""]);
  else if (layer === "GLO") drawMix(g);
  else if (layer === "SAVE") drawSong(g);
  else if (layer === "SEL") drawLayerHint(g, "SEL · KEY", ["KEY " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "") + " " + LIB.SCALES[S.scale][0], "CHORD " + LIB.CHORDS[S.chord] + " · KEYS " + ["CHROM", "SNAP", "WHITE"][S.keys], "white key = key of the song"]);
  else if (layer === "EDIT") drawLayerHint(g, "EDIT · ERASE", ["press a sound or a note to erase it", fm.seq.playing() ? "(as the loop plays)" : "(stopped: from the whole pattern)", "black keys: live drum mutes", "OCT− undo · OCT+ redo"]);
  else if (layer === "ARP") drawLayerHint(g, "ARP · ROLL", ["hold a key: note repeat", "recorded as ratchets while REC", "RATE " + REPEAT_NAMES[repeatRate]]);
  else if (screen === "rec") drawRec(g);
  else if (screen === "page" && page) drawPage(g);
  else drawTracks(g);
  if (showKnobs) { g.rect(0, 180, 240, 60, "#00000066"); knobRow(g, knobsNow()); }
  if (flash && fm.now() < flashUntil) {
    g.rect(20, 92, 200, 34, "#000000dd", 8); g.frame(20, 92, 200, 34, TC[S.track], 1.5, 8);
    g.text(120, 100, flash, { size: 13, weight: "bold", align: "center", color: C.white });
  }
  leds();
}
function drawMix(g) {
  header(g, "GLO · MIX", TC[S.track]);
  var labels = ["MUTE 1", "MUTE 2", "MUTE 3", "MUTE 4", "SOLO 1", "SOLO 2", "SOLO 3", "SOLO 4", "FILL", "BAR", "", "", "", "", "", "TAP"];
  for (var i = 0; i < 16; i++) {
    var x = 12 + (i % 4) * 56, y = 30 + Math.floor(i / 4) * 36, on = (i < 4 && mutes[i]) || (i >= 4 && i < 8 && solos[i - 4]) || (i === 8 && fm.seq.fill()) || (i === 9 && fillNext);
    if (!labels[i]) continue;
    g.rect(x, y, 50, 30, on ? (i < 8 ? TC[i % 4] : C.white) : "#ffffff16", 5);
    g.text(x + 25, y + 8, labels[i], { size: 10, weight: "bold", align: "center", color: on ? "#0b0d12" : C.white });
  }
}
function leds() {
  var t = S.track, p = pat(t), cur = fm.seq.step(t), beatGlow = layer ? "#ffffff30" : null;
  for (var i = 0; i < 16; i++) {
    var k = fm.keyOfWhite(i), c = null;
    if (layer === "SEQ") {
      var s = stepPage * 16 + i, st = fm.seq.get(t, p, s, t === DR ? S.lane : 0);
      c = st.vel ? TC[t] : (i % 4 === 0 ? "#ffffff30" : null);
      if (s === cur) c = C.white;
    } else if (layer && i % 4 === 0) c = beatGlow;
    else if (!layer && t === DR && fm.now() - (keyFlash[k] || 0) < 120) c = C.t4;
    fm.led.key(k, c);
  }
  var playing = fm.seq.playing(), beat = fm.seq.beat();
  var onBeat = playing && beat >= 0 && (beat % 1) < 0.2;
  fm.led.button("PLAY", playing ? (onBeat ? "green" : "off") : "off");
  fm.led.button("REC", recording || (armed && (fm.now() % 600 < 300)) ? "red" : "off");
  var names = ["FX", "SEL", "EDIT", "GLO", "ARP", "SEQ", "SAVE"];
  for (var n = 0; n < names.length; n++) fm.led.button(names[n], layer === names[n] ? (locked === names[n] ? "blue" : "on") : "off");
  if (screen === "page" && page && !layer) { var gname = page.group === "KIT" ? "EDIT" : page.group === "MASTER" ? "FX" : page.group === "SONG" ? "SAVE" : page.group; fm.led.button(gname, "on"); }
  fm.led.button("HOME", screen === "tracks" || screen === "visual" ? "on" : "off");
}

function onShutdown() { saveUI(); fm.store.set("master", master); fm.punch("OFF"); }

// Incoming MIDI: notes play the selected track (GM drum map on the drum track) and record while REC runs.
function onMidi(kind, n, v, ch) {
  if (kind !== "on" && kind !== "off") return;
  var t = S.track;
  LIB.midiNote(t, inst(t), t === DR, kind, n, v, recording && fm.seq.playing());
}
