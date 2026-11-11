// Melodee for FM Pocket — a re-implementation of the behaviour documented in the Melodee 1.6.1
// README and manual (github.com/keremimo/melodee, GPL-3.0). No Melodee code is used, and no
// third-party preset banks are included; see ../README.md and research/FIRMWARES.md.

var PALETTES = [
  { name: "NIGHT", bg: "#101218", panel: "#1b1f29", text: "#eef1f6", sub: "#8d96a8", tracks: ["#ff7a59", "#5cc8ff", "#c38bff", "#ffd166"] },
  { name: "DAY", bg: "#eef0f3", panel: "#ffffff", text: "#1d2330", sub: "#6b7385", tracks: ["#e5533d", "#1d8fe0", "#8a4fe0", "#d39a00"] },
  { name: "CONTRAST", bg: "#000000", panel: "#151515", text: "#ffffff", sub: "#b0b0b0", tracks: ["#ff3b30", "#00c8ff", "#d070ff", "#ffe000"] },
  { name: "SUNSET", bg: "#1d1220", panel: "#2b1a2e", text: "#ffe9de", sub: "#c79a9a", tracks: ["#ff8a5b", "#ffb347", "#ff5e8a", "#c86bfa"] },
  { name: "OCEAN", bg: "#0b1a24", panel: "#11293a", text: "#e3f6ff", sub: "#7fa7bb", tracks: ["#3ad1c8", "#4aa3ff", "#7f8cff", "#b4f06a"] },
  { name: "NEON", bg: "#07070d", panel: "#14142a", text: "#f4f4ff", sub: "#9090c0", tracks: ["#ff2fd0", "#2ff3ff", "#b6ff2f", "#ffb02f"] },
  { name: "CANDY", bg: "#fff2f8", panel: "#ffffff", text: "#3a2340", sub: "#9a7ca2", tracks: ["#ff6fa8", "#6fb8ff", "#b58cff", "#ffb86f"] },
  { name: "LO-FI", bg: "#1c1b17", panel: "#2a2822", text: "#e8e2cf", sub: "#a39c86", tracks: ["#d9a066", "#8fb3a0", "#b49ab8", "#d6c56b"] }
];
var INST = ["t1", "t2", "t3", "drums", "m5", "m6", "m7", "m8"];
// tracks 5–8 are MIDI tracks: they play external instruments on their channel (KNOB 1, CH)
var NT = 8;
function isMidi(t) { return t >= 4; }
function bank(t) { return t < 4 ? 0 : 4; }
// tracks 1–3 are host slots: each can load PROPHET (va), FM6 (fm) or CZ-1 (pd)
var ENGINE_NAMES = { va: "PROPHET", fm: "FM6", pd: "CZ-1", drums: "DRUM", midi: "MIDI" };
var DEFAULT_ENGINE = ["va", "fm", "pd"];
var DR = 3, NPAT = 16;
var HOSTN = ["BD", "SD", "LT", "MT", "HT", "RM", "CP", "CB", "CY", "OH", "CH"];
var GM = [["KICK", 0], ["SNARE", 1], ["CL HAT", 10], ["OP HAT", 9], ["CLAP", 6], ["LO TOM", 2], ["HI TOM", 4], ["RIM", 5]];
var CATS = ["ALL", "BASS", "LEAD", "PAD", "KEYS", "BRASS", "PLUCK", "BELL", "DRUM", "FX", "RECENT"];

// Original sounds (Melodee ships Sequential's and Casio's factory programs; they are not
// reproduced here — these are this package's own patches in the same categories).
var SOUNDS = {
  va: [
    { name: "INIT PROPHET", cat: "KEYS" },
    { name: "FUNK BASS", cat: "BASS", wave1: 1, wave2: 0, osc2: 0.6, semi2: 12, pw: 0.35, cutoff: 0.3, res: 0.45, envamt: 0.85, fd: 0.38, fs: 0.05, a: 0, d: 0.45, s: 0.6, r: 0.25, mode: 1, glide: 0.08 },
    { name: "POLY BRASS", cat: "BRASS", wave1: 0, wave2: 0, osc2: 0.85, detune: 0.54, cutoff: 0.4, res: 0.15, envamt: 0.8, fa: 0.35, fd: 0.5, fs: 0.55, a: 0.22, d: 0.5, s: 0.85, r: 0.38 },
    { name: "SYNC SCREAM", cat: "LEAD", wave1: 0, wave2: 0, semi2: 38, osc1: 0, osc2: 1, sync: 1, polymod: 0.3, cutoff: 0.7, res: 0.3, envamt: 0.6, a: 0.01, d: 0.5, s: 0.8, r: 0.3, mode: 2, glide: 0.15 },
    { name: "SOFT STRINGS", cat: "PAD", wave1: 0, wave2: 1, pw: 0.3, osc2: 0.7, detune: 0.57, cutoff: 0.55, res: 0.05, envamt: 0.45, fa: 0.6, a: 0.62, d: 0.7, s: 0.9, r: 0.72, lforate: 0.4, lfopw: 0.35 },
    { name: "PM BELLS", cat: "BELL", wave1: 3, wave2: 2, semi2: 43, polymod: 0.7, osc2: 0.2, cutoff: 0.75, res: 0.1, envamt: 0.3, a: 0, d: 0.68, s: 0, r: 0.62 },
    { name: "CLAV PLUCK", cat: "PLUCK", wave1: 1, pw: 0.18, osc2: 0, cutoff: 0.38, res: 0.4, envamt: 0.9, fd: 0.35, fs: 0, a: 0, d: 0.42, s: 0, r: 0.3 },
    { name: "WIND NOISE", cat: "FX", osc1: 0, osc2: 0, noise: 1, cutoff: 0.5, res: 0.75, envamt: 0.4, fa: 0.7, a: 0.6, d: 0.6, s: 0.8, r: 0.7, lforate: 0.3, lfocutoff: 0.5 }
  ],
  pd: [
    { name: "INIT TONE", cat: "KEYS", wave1: 0, dcw: 0, dcwenv: 0 },
    { name: "CZ BRASS", cat: "BRASS", wave1: 0, dcw: 0.1, dcwenv: 0.85, da: 0.3, dd: 0.5, ds: 0.45, a: 0.25, d: 0.5, s: 0.85, r: 0.4 },
    { name: "CZ SOLO", cat: "LEAD", wave1: 2, dcw: 0.35, dcwenv: 0.5, a: 0.01, d: 0.5, s: 0.85, r: 0.3, mode: 2, glide: 0.12, vib: 0.18, vibrate: 0.55 },
    { name: "CZ SYNTH BASS", cat: "BASS", wave1: 1, wave2: 0, line: 1, semi2: 12, dcw: 0.05, dcwenv: 0.9, dd: 0.42, ds: 0, a: 0, d: 0.5, s: 0.4, r: 0.25, mode: 1 },
    { name: "RESO SWEEP", cat: "PLUCK", wave1: 7, dcw: 0.05, dcwenv: 0.95, dd: 0.55, ds: 0.05, a: 0, d: 0.55, s: 0.1, r: 0.4 },
    { name: "GLASS PAD", cat: "PAD", wave1: 3, wave2: 6, line: 2, detune: 0.6, dcw: 0.2, dcwenv: 0.4, da: 0.65, dd: 0.7, ds: 0.5, a: 0.62, d: 0.7, s: 0.9, r: 0.72 },
    { name: "TINE BELL", cat: "BELL", wave1: 3, wave2: 5, line: 1, semi2: 36, dcw: 0.25, dcwenv: 0.55, dd: 0.55, ds: 0.05, a: 0, d: 0.66, s: 0, r: 0.6 }
  ]
};
var KITS = [
  { name: "808", p: {} },
  { name: "909", p: { "BD.decay": 0.38, "BD.tone": 0.72, "SD.tone": 0.78, "SD.decay": 0.42, "CH.decay": 0.32, "OH.decay": 0.55, "CP.tone": 0.62 } },
  { name: "CR78", p: { "BD.decay": 0.3, "BD.tune": 0.6, "SD.decay": 0.3, "SD.tone": 0.4, "CH.tone": 0.75, "CH.decay": 0.25, "RM.tune": 0.8, "CB.tune": 0.65 } },
  { name: "FM", p: { "BD.tune": 0.55, "BD.tone": 0.9, "SD.tone": 0.9, "CB.level": 0.9, "RM.level": 0.9 } }
];

var B = new LIB.Buttons();
var undo = new LIB.Undo(8);
var S = fm.store.get("ui", null) || { track: 0, sound: [1, 0, 3], kit: 0, palette: 0, octave: 0, root: 0, scale: 2, qnt: 0, chord: 0, voic: 0, autosave: true, loopSong: false, recent: [] };
var section = "HOME", pageIx = 0;          // open section and page
var PAGES = { HOME: ["STAGE", "WHEEL"], SEQ: ["NOTES", "PATTERN", "TEMPO", "SONG"], SCL: ["SCALE", "CHORD"], FX: ["RACK"], GLO: ["MIXER", "GLOBAL"], ENV: ["ENV"], LFO: ["LFO"], EDIT: ["EDIT 1", "EDIT 2"], ARP: ["ARP", "ARP 2"], SAVE: ["PROJECT"], MENU: ["MENU"] };
var browser = null;                         // {cat, prev}
var armed = false, recording = false, recWait = false;
var cursor = 0, zoom = 16, sheet = null;
var heldPat = -1, heldPatT0 = 0, patDialog = null;
var layer = null, latched = null;
var flash = "", flashUntil = 0;
var heldKeys = {}, sounding = {}, lastChord = [], lastVoicing = [];
var capture = [];                           // [beat, note|lane, vel, track]
var jam = [], lastLoop = -1;
var song = fm.store.get("song", []), songCur = 0, songTrack = 0;
song.forEach(function (sec) { while (sec.p.length < NT) sec.p.push(-1); });   // songs from before the MIDI tracks: they rest
var tapTimes = [], lastNote = 60;

function P() { return PALETTES[S.palette]; }
function TC(t) { return t < 4 ? P().tracks[t] : LIB.hexA(P().tracks[t - 4], "aa"); }
function inst(t) { return fm.inst(INST[t]); }
function E(t) { return t === DR ? "drums" : (isMidi(t) ? "midi" : inst(t).engine()); }
function engineName(t) { return ENGINE_NAMES[E(t)]; }
function setEngine(t, d) {
  if (t === DR || isMidi(t)) return;
  var list = inst(t).engines(), e = list[LIB.clamp(list.indexOf(E(t)) + d, 0, list.length - 1)];
  if (e === E(t)) return;                     // a knob: stops at the ends
  inst(t).allOff(); inst(t).engine(e);
  loadSound(t, 0); say("T" + (t + 1) + " " + ENGINE_NAMES[e]);
}
function pat(t) { return fm.seq.pattern(t); }
function say(m, ms) { flash = m; flashUntil = fm.now() + (ms || 1100); }
function saveUI() { fm.store.set("ui", S); }
function page() { var p = PAGES[section]; return p[pageIx % p.length]; }
function soundName(t) {
  if (t === DR) return KITS[S.kit].name + " KIT";
  if (isMidi(t)) return "MIDI CH " + (Math.round(inst(t).get("channel")) + 1);
  if (E(t) === "fm") return fm.presetName(S.sound[t]);
  return SOUNDS[E(t)][S.sound[t]].name;
}
var DEF = { wave1: 0, wave2: 1, pw: 0.5, semi2: 24, detune: 0.5, osc1: 1, osc2: 0.7, sub: 0, noise: 0, sync: 0, polymod: 0, cutoff: 0.55, res: 0.2, ftype: 0, envamt: 0.7, keytrack: 0.5, fa: 0.05, fd: 0.45, fs: 0.3, fr: 0.4, a: 0.02, d: 0.5, s: 0.8, r: 0.35, drive: 0.15, glide: 0, mode: 0, lforate: 0.5, lfowave: 0, lfopitch: 0, lfocutoff: 0, lfopw: 0, level: 0.8, vel: 0.5, spread: 0.3, line: 0, dcw: 0.3, dcwenv: 0.6, da: 0.02, dd: 0.5, ds: 0.3, dr: 0.4, fold: 0, vib: 0, vibrate: 0.55 };
function loadSound(t, i, quiet) {
  if (isMidi(t)) return;                      // a MIDI track has one DEFAULT preset
  if (t === DR) {
    S.kit = LIB.wrap(i, KITS.length);
    var d = fm.inst("drums");
    for (var l = 0; l < HOSTN.length; l++) { d.set(HOSTN[l] + ".level", 100 / 127); d.set(HOSTN[l] + ".tune", 0.5); d.set(HOSTN[l] + ".decay", 0.5); d.set(HOSTN[l] + ".tone", 0.5); }
    var p = KITS[S.kit].p; for (var k in p) if (p.hasOwnProperty(k)) d.set(k, p[k]);
  } else if (E(t) === "fm") { S.sound[t] = LIB.wrap(i, 128); inst(t).preset(S.sound[t]); }
  else {
    var list = SOUNDS[E(t)]; S.sound[t] = LIB.wrap(i, list.length);
    var s = list[S.sound[t]], names = inst(t).params();
    for (var n = 0; n < names.length; n++) inst(t).set(names[n], s[names[n]] !== undefined ? s[names[n]] : (DEF[names[n]] !== undefined ? DEF[names[n]] : 0));
  }
  var tag = t + ":" + E(t) + ":" + (t === DR ? S.kit : S.sound[t]);
  S.recent = [tag].concat(S.recent.filter(function (x) { return x !== tag; })).slice(0, 12);
  if (!quiet) saveUI();
}

function onBoot() {
  if (!fm.store.get("init", false)) {
    for (var t0 = 0; t0 < 3; t0++) inst(t0).engine(DEFAULT_ENGINE[t0]);
    loadSound(0, 1, true); loadSound(1, S.sound[1], true); loadSound(2, 3, true); loadSound(DR, 0, true);
    fm.seq.tempo(110); fm.seq.swing(52);
    fm.store.set("init", true); saveUI();
  }
  // projects saved before tracks became engine slots: reload each track's chosen sound once
  if (!fm.store.get("slots", false)) { for (var ts = 0; ts < 3; ts++) loadSound(ts, S.sound[ts], true); fm.store.set("slots", true); }
  fm.inst("t1").level(0.85); fm.inst("t3").level(0.8);
  fm.seq.song(song.map(function (s) { return { patterns: s.p, repeats: s.r }; }), S.loopSong);
  fm.fx("reverb", true, 1, 28, 25);
}

// ---- chords (SCL > CHORD): OFF, AUTO, AUTO2, triads, sevenths, fixed shapes ----
var CHORD_MODES = ["OFF", "AUTO", "AUTO2", "TRIAD", "7TH", "SUS4", "POWER"];
function closest(notes, prev) {
  // choose the inversion nearest to the previous voicing (smooth voice leading)
  if (!prev.length) return notes;
  var best = notes, bestD = 1e9, avgPrev = prev.reduce(function (a, b) { return a + b; }, 0) / prev.length;
  for (var inv = 0; inv < notes.length; inv++) {
    for (var o = -1; o <= 1; o++) {
      var v = notes.map(function (n, i) { return n + (i < inv ? 12 : 0) + o * 12; }).sort(function (a, b) { return a - b; });
      var avg = v.reduce(function (a, b) { return a + b; }, 0) / v.length, d = Math.abs(avg - avgPrev);
      if (d < bestD) { bestD = d; best = v; }
    }
  }
  return best;
}
function chordFor(n) {
  var root = 60 + S.root;
  switch (S.chord) {
    case 0: return [n];
    case 1: { var c = closest(LIB.chordNotes(n, 1, root, S.scale), lastVoicing); lastVoicing = c; return c; }
    case 2: { var under = LIB.chordNotes(n - 12, 1, root, S.scale).map(function (x) { while (x >= n) x -= 12; return x; }); var v = closest(under, lastVoicing.filter(function (x) { return x < n; })); lastVoicing = v.concat([n]); return lastVoicing; }
    case 3: return LIB.chordNotes(n, 1, root, S.scale);
    case 4: return LIB.chordNotes(n, 2, root, S.scale);
    case 5: return LIB.chordNotes(n, 4, root, S.scale);
    default: return LIB.chordNotes(n, 5, root, S.scale);
  }
}
function keyNote(k) {
  var n;
  if (S.qnt === 2) { var w = fm.whiteIndex(k); if (w < 0) return null; n = LIB.degree(60 + S.root, S.scale, w - 4); }
  else { n = 53 + k; if (S.qnt === 1) n = LIB.snap(n, S.root, S.scale); }
  return n + (S.octave + fm.octave()) * 12;
}

// ---- keys ----
function onKey(k, down, vel) {
  var t = S.track, w = fm.whiteIndex(k), b = fm.blackIndex(k);
  if (B.isDown("SEQ") || (section === "SEQ" && page() === "PATTERNS")) { patternKey(k, w, b, down); return; }
  if (layer === "GLO") { gloKey(k, w, b, down); return; }
  if (layer === "SCL") { if (down && w >= 0) { S.root = LIB.wrap(53 + k, 12); saveUI(); say("ROOT " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "")); B.use("SCL"); } return; }
  if (t === DR) {
    if (!down) return;
    var gm = w >= 0 ? GM[w % 8] : (b >= 0 ? GM[b % 8] : null); if (!gm) return;
    fm.inst("drums").hit(gm[1], vel); sounding["d" + gm[1]] = fm.now();
    afterPlay(t, [gm[1]], vel, true);
    return;
  }
  if (down) {
    var n = keyNote(k); if (n === null) return;
    var notes = chordFor(n);
    heldKeys[k] = notes; lastChord = notes; lastNote = n;
    for (var i = 0; i < notes.length; i++) { inst(t).note(notes[i], vel); sounding[notes[i]] = true; }
    afterPlay(t, notes, vel, false);
  } else if (heldKeys[k]) {
    for (var j = 0; j < heldKeys[k].length; j++) { inst(t).off(heldKeys[k][j]); delete sounding[heldKeys[k][j]]; }
    delete heldKeys[k];
    if (stepEntry && !Object.keys(heldKeys).length) { stepEntry = false; cursor = (cursor + 1) % fm.seq.length(t, pat(t)); }
  }
}
var stepEntry = false;
function afterPlay(t, notes, vel, drum) {
  // stopped and armed: the first key starts playback and records from step zero
  if (armed && !fm.seq.playing()) {
    if (section === "SEQ" && page() === "NOTES" && !drum) {
      // NOTES page while stopped: keys enter a note or chord at the cursor, then advance on release
      fm.seq.set(t, pat(t), cursor, { vel: vel, notes: notes.slice(0, 4), len: 4 }); stepEntry = true; return;
    }
    undo.push(t, pat(t)); recording = true; recWait = false; fm.seq.play();
    if (drum) fm.seq.set(t, pat(t), 0, { vel: vel }, notes[0]); else fm.seq.set(t, pat(t), 0, { vel: vel, notes: notes.slice(0, 4), len: 4 });
    return;
  }
  if (recording && !recWait) {
    for (var i = 0; i < notes.length; i++) { if (drum) fm.seq.recordHit(t, notes[i], vel); else fm.seq.record(t, notes[i], vel); }
  } else if (fm.seq.playing()) {
    var beat = fm.seq.beat();
    for (var j = 0; j < notes.length; j++) capture.push([beat, notes[j], vel, t, drum]);
    if (capture.length > 256) capture.splice(0, capture.length - 256);
  }
}

// ---- PATTERNS (hold SEQ): white keys pick patterns 1–16, black keys 1–4 pick tracks ----
function patternKey(k, w, b, down) {
  B.use("SEQ");
  var t = S.track;
  if (patDialog) {
    if (!down) return;
    if (w >= 0) {
      if (w === patDialog.p) { undo.push(t, w); fm.seq.clear(t, w); say("PATTERN " + (w + 1) + " DELETED"); }
      else { fm.seq.copy(t, patDialog.p, w); say("COPIED " + (patDialog.p + 1) + " → " + (w + 1)); }
      patDialog = null;
    } else if (b === 3) { var L = fm.seq.length(t, patDialog.p); fm.seq.length(t, patDialog.p, Math.max(1, L >> 1)); say("HALVED · LEN " + Math.max(1, L >> 1)); }
    else if (b === 4) { undo.push(t, patDialog.p); LIB.double(t, patDialog.p); say("DOUBLED · LEN " + fm.seq.length(t, patDialog.p)); }
    return;
  }
  if (b >= 0) { if (down && b < NT) { selectTrack(b); } return; }
  if (w < 0) return;
  if (down) { heldPat = w; heldPatT0 = fm.now(); return; }
  if (heldPat !== w) return;
  heldPat = -1;
  if (fm.now() - heldPatT0 > 900) return;  // the dialog opened on the hold
  var now = fm.now(), dbl = lastPatTap.k === w && now - lastPatTap.t < 400;
  lastPatTap = { k: w, t: now };
  fm.seq.select(t, w);
  if (!fm.seq.has(t, w)) { armed = true; recWait = fm.seq.playing(); say("PATTERN " + (w + 1) + " · REC ARMED"); }
  else if (dbl) { armed = true; recWait = fm.seq.playing(); say("REC ARMED"); }
  else say(fm.seq.playing() ? "NEXT: " + (w + 1) : "PATTERN " + (w + 1));
}
var lastPatTap = { k: -1, t: 0 };
function selectTrack(t) { for (var i = 0; i < NT; i++) if (i !== DR) inst(i).allOff(); S.track = LIB.clamp(t, 0, NT - 1); saveUI(); }

// ---- GLO quick layer: mutes, solos, fill, tap ----
function gloKey(k, w, b, down) {
  B.use("GLO");
  if (!down) { if (w === 8) fm.seq.fill(false); return; }
  if (w >= 0 && w < 4) { var m = !fm.seq.mute(w); fm.seq.mute(w, m); say("T" + (w + 1) + (m ? " MUTE" : " ON")); }
  else if (w >= 4 && w < 8) { var t = w - 4; var solo = !fm.seq.mute(t) && [0, 1, 2, 3].every(function (i) { return i === t || fm.seq.mute(i); }); for (var i = 0; i < 4; i++) fm.seq.mute(i, !solo && i !== t); say(solo ? "SOLO OFF" : "SOLO T" + (t + 1)); }
  else if (w === 8) fm.seq.fill(true);
  else if (w >= 9 && w < 13) { var mt = w - 5, mm = !fm.seq.mute(mt); fm.seq.mute(mt, mm); say("T" + (mt + 1) + (mm ? " MUTE" : " ON")); }
  else if (w === 15) tap();
}
function tap() {
  var now = fm.now(); tapTimes = tapTimes.filter(function (x) { return now - x < 2500; }); tapTimes.push(now);
  if (tapTimes.length > 1) fm.seq.tempo(Math.round(60000 * (tapTimes.length - 1) / (tapTimes[tapTimes.length - 1] - tapTimes[0])));
  say("BPM " + Math.round(fm.seq.tempo()));
}

// ---- buttons ----
function onButton(name, down) {
  if (down) {
    B.press(name);
    if (name === "OCT-" || name === "OCT+") { octave(name === "OCT+"); return; }
    if (name === "GLO" || name === "SCL" || name === "SEL") layer = name === "SEL" ? "SCL" : name;
    if (name === "PLAY" && B.isDown("REC")) { B.use("REC"); armed = true; startOrStop(); B.use("PLAY"); }
    return;
  }
  var kind = B.release(name);
  var lname = name === "SEL" ? "SCL" : name;
  if (layer === lname) {
    if (kind === "double" && lname === "GLO") { latched = "GLO"; say("GLO LOCKED"); return; }
    if (latched !== lname) layer = null;
    if (lname === "GLO") fm.seq.fill(false);
    if (kind === "hold") return;
  } else if (latched === lname) { latched = null; layer = null; say("GLO UNLOCKED"); return; }
  if (name === "OCT-" || name === "OCT+") return;
  if (kind === "hold") {
    if (name === "SEQ") { heldPat = -1; patDialog = null; return; }
    if (name === "EDIT") { if (undo.undo()) say("UNDO"); else say("NOTHING TO UNDO"); return; }
    if (name === "SAVE") { fm.seq.stop(); say("SAVED " + ("0" + (fm.store.get("slot", 1))).slice(-2)); return; }
    if (name === "HOME") { section = "MENU"; pageIx = 0; return; }
    if (name === "REC") { if (section === "SEQ" && page() === "SONG") takeJam(); else doCapture(); return; }
    return;
  }
  browser = null;
  switch (name) {
    case "PLAY": startOrStop(); return;
    case "REC":
      armed = !armed; recording = false;
      recWait = armed && fm.seq.playing();
      say(armed ? "T" + (S.track + 1) + " ARMED" : "DISARMED");
      return;
    case "SEL": name = "SCL";
  }
  if (!PAGES[name]) return;
  if (section === name) pageIx = (pageIx + 1) % PAGES[name].length; else { section = name; pageIx = 0; }
  sheet = null;
}
function startOrStop() {
  if (fm.seq.playing()) { fm.seq.stop(); recording = false; recWait = false; for (var t = 0; t < NT; t++) if (t !== DR) inst(t).allOff(); return; }
  if (armed) { undo.push(S.track, pat(S.track)); recording = true; recWait = false; }
  lastLoop = -1; jam = [];
  fm.seq.play();
}
function octave(up) {
  if (B.isDown("EDIT")) { B.use("EDIT"); if (up ? undo.redoOne() : undo.undo()) say(up ? "REDO" : "UNDO"); return; }
  if (browser) { if (up) { browser = null; say("LOADED"); } else { loadSound(S.track, browser.prev); browser = null; say("BACK"); } return; }
  if (patDialog && !up) { patDialog = null; return; }
  if (section === "SEQ" && page() === "NOTES") { notesOct(up); return; }
  if (section === "SEQ" && page() === "SONG") { songOct(up); return; }
  if (section === "HOME") {
    if (B.isDown(up ? "OCT-" : "OCT+")) { S.octave = 0; say("OCTAVE 0"); } else { S.octave = LIB.clamp(S.octave + (up ? 1 : -1), -3, 3); say("OCTAVE " + S.octave); }
    saveUI(); return;
  }
  if (!up) { section = "HOME"; pageIx = 0; }
}
function notesOct(up) {
  var t = S.track, p = pat(t), row = t === DR ? GM[drumLane][1] : 0, st = fm.seq.get(t, p, cursor, row);
  if (!up) { if (sheet) sheet = null; else cursor = Math.max(0, cursor - 1); return; }
  if (sheet) { applySheet(); return; }
  if (!st.vel) { undo.push(t, p); fm.seq.set(t, p, cursor, t === DR ? { vel: 100 } : { vel: 100, notes: [lastNote], len: 4 }, row); say("PLACED"); }
  else sheet = { i: 0 };
}
var SHEET = ["Chance 50%", "Chance 100%", "Slide on/off", "Copy to next", "Delete"];
function applySheet() {
  var t = S.track, p = pat(t), row = t === DR ? GM[drumLane][1] : 0, st = fm.seq.get(t, p, cursor, row);
  undo.push(t, p);
  switch (sheet.i) {
    case 0: fm.seq.set(t, p, cursor, { chance: 50 }, row); break;
    case 1: fm.seq.set(t, p, cursor, { chance: 100 }, row); break;
    case 2: fm.seq.set(t, p, cursor, { slide: !st.slide }, row); break;
    case 3: if (cursor < 63) fm.seq.set(t, p, cursor + 1, st, row); break;
    case 4: fm.seq.clear(t, p, cursor, row); break;
  }
  say(SHEET[sheet.i].toUpperCase()); sheet = null;
}
function songOct(up) {
  if (up) {
    var cur = song[songCur] || { p: [0, 1, 2, 3, 4, 5, 6, 7].map(pat), r: 1 };
    song.splice(songCur + 1, 0, JSON.parse(JSON.stringify(cur))); if (song.length > 64) song.pop();
    songCur = Math.min(song.length - 1, songCur + 1); say("SECTION ADDED");
  } else if (song.length) { song.splice(songCur, 1); songCur = Math.max(0, songCur - 1); say("SECTION REMOVED"); }
  applySong();
}
function applySong() {
  fm.store.set("song", song);
  fm.seq.song(song.map(function (s) { return { patterns: s.p, repeats: s.r }; }), S.loopSong);
  fm.seq.songOn(song.length > 0 && section === "SEQ" && page() === "SONG");
}
function takeJam() {
  if (!jam.length) { say("NO JAM YET"); return; }
  song = [];
  for (var i = 0; i < jam.length; i++) {
    var last = song[song.length - 1];
    if (last && last.p.join() === jam[i].join()) last.r++; else song.push({ p: jam[i].slice(), r: 1 });
  }
  songCur = 0; applySong(); say("JAM → SONG (" + song.length + ")");
}
function doCapture() {
  var t = S.track, p = pat(t);
  var mine = capture.filter(function (c) { return c[3] === t; });
  if (!mine.length) { say("NOTHING TO CAPTURE"); return; }
  undo.push(t, p);
  var endBeat = fm.seq.beat(), span = endBeat - mine[0][0];
  var bars = span <= 4 ? 1 : (span <= 8 ? 2 : 4), steps = bars * 16;
  var empty = !fm.seq.has(t, p);
  if (empty) fm.seq.length(t, p, steps); else steps = fm.seq.length(t, p);
  var start = endBeat - steps / 4;
  for (var i = 0; i < mine.length; i++) {
    if (mine[i][0] < start) continue;
    var pos = (mine[i][0] - start) * 4, s = Math.round(pos) % steps, nudge = LIB.clamp(Math.round((pos - Math.round(pos)) * 16), -8, 7);
    if (mine[i][4]) fm.seq.set(t, p, s, { vel: mine[i][2], nudge: nudge }, mine[i][1]);
    else { var st = fm.seq.get(t, p, s), ns = st.vel ? st.notes : []; if (ns.indexOf(mine[i][1]) < 0 && ns.length < 4) ns.push(mine[i][1]); fm.seq.set(t, p, s, { vel: mine[i][2], notes: ns, len: 3, nudge: nudge }); }
  }
  capture = capture.filter(function (c) { return c[3] !== t; });
  say("CAPTURED " + bars + " BAR" + (bars > 1 ? "S" : ""));
}

// ---- knobs ----
function K(label, text, frac, turn) { return { label: label, text: text, frac: frac, turn: turn }; }
function PK(t, name, label, fmt) {
  var i = inst(t), disc = ["wave1", "wave2", "semi2", "sync", "ftype", "mode", "lfowave", "line"].indexOf(name) >= 0;
  return K(label, function () { var v = i.get(name); return fmt ? fmt(v) : (E(t) === "fm" ? String(Math.round(v)) : (disc ? String(v) : String(Math.round(v * 127)))); },
    function () { var v = i.get(name); return E(t) === "fm" ? v / 99 : (disc ? 0.5 : v); },
    function (d) { var v = i.get(name); if (E(t) === "fm") i.set(name, LIB.clamp(v + d, 0, name === "algorithm" || /coarse$/.test(name) ? 31 : (name === "feedback" ? 7 : 99))); else i.set(name, disc ? v + d : LIB.clamp(v + d / 127, 0, 1)); });
}
var CZW = ["SAW", "SQUARE", "PULSE", "DBL SINE", "SAW-PULSE", "RESO 1", "RESO 2", "RESO 3"];
function midiK(t) {
  return K("CH", function () { return String(Math.round(inst(t).get("channel")) + 1); }, function () { return inst(t).get("channel") / 15; },
    function (d) { inst(t).allOff(); inst(t).set("channel", LIB.clamp(Math.round(inst(t).get("channel")) + d, 0, 15)); });
}
function stageKnobs(t) {
  if (isMidi(t)) return [midiK(t), null, null, null];
  if (E(t) === "va") return [PK(t, "cutoff", "CUTOFF"), PK(t, "res", "RESO"), PK(t, "envamt", "FILT ENV"), PK(t, "r", "RELEASE")];
  if (E(t) === "fm") return [PK(t, "op2.level", "MLVL"), PK(t, "op2.coarse", "MRAT"), PK(t, "feedback", "MEG"), PK(t, "op1.detune", "DTUN")];
  if (E(t) === "pd") return [PK(t, "wave1", "WAVE", function (v) { return CZW[v]; }), PK(t, "dcw", "DCW"), PK(t, "detune", "DETUNE"), PK(t, "vib", "VIBRATO")];
  return [drumK(0, "level", "KICK"), drumK(1, "level", "SNARE"), drumK(2, "level", "HATS"), drumK(drumLane, "decay", GM[drumLane][0].slice(0, 6) + " DEC")];
}
var drumLane = 0;
function drumK(gmIx, p, label) {
  var key = HOSTN[GM[gmIx][1]] + "." + p;
  return K(label, function () { return String(Math.round(fm.inst("drums").get(key) * 127)); }, function () { return fm.inst("drums").get(key); },
    function (d) { fm.inst("drums").set(key, LIB.clamp(fm.inst("drums").get(key) + d / 127, 0, 1)); });
}
function stepK(field, label, lo, hi, step, fmt) {
  return K(label, function () { var t = S.track, st = fm.seq.get(t, pat(t), cursor, t === DR ? GM[drumLane][1] : 0); return st.vel ? (fmt ? fmt(st[field], st) : String(st[field])) : (field === "notes" ? "SELECT A NOTE" : "--"); },
    function () { var t = S.track, st = fm.seq.get(t, pat(t), cursor, t === DR ? GM[drumLane][1] : 0); return field === "notes" ? 0.5 : (st[field] - lo) / (hi - lo); },
    function (d) {
      var t = S.track, row = t === DR ? GM[drumLane][1] : 0, st = fm.seq.get(t, pat(t), cursor, row); if (!st.vel) return;
      var o = {};
      if (field === "notes") o.notes = st.notes.map(function (n) { return LIB.clamp(n + d, 12, 120); });
      else if (field === "slide") o.slide = !st.slide;
      else o[field] = LIB.clamp(st[field] + d * step, lo, hi);
      fm.seq.set(t, pat(t), cursor, o, row);
      if (field === "notes" && t !== DR) { inst(t).note(o.notes[0], 90); var nn = o.notes[0]; pendingOff.push([fm.now() + 200, t, nn]); }
    });
}
var pendingOff = [];
function knobs() {
  var t = S.track;
  if (browser) return [K("LIST", function () { return CATS[browser.cat]; }, function () { return browser.cat / (CATS.length - 1); }, function (d) { browser.cat = LIB.clamp(browser.cat + d, 0, CATS.length - 1); }),
    K("SOUND", function () { return soundName(t).slice(0, 9); }, function () { return 0.5; }, function (d) { browse(d); }), null,
    K("ENGINE", function () { return engineName(t); }, function () { return t === DR ? 0 : inst(t).engines().indexOf(E(t)) / 2; }, function (d) { if (t === DR) say("THE DRUM TRACK KEEPS ITS KIT"); else setEngine(t, d > 0 ? 1 : -1); })];
  if (layer === "GLO") return [0, 1, 2, 3].map(function (i) { return K("T" + (i + 1) + " LVL", function () { return String(Math.round(inst(i).level() * 100)); }, function () { return inst(i).level(); }, function (d) { inst(i).level(LIB.clamp(inst(i).level() + d * 0.02, 0, 1)); B.use("GLO"); }); });
  if (B.isDown("SEQ")) return [0, 1, 2, 3].map(function (j) { var i = j + bank(S.track); return K("T" + (i + 1), function () { return String(pat(i) + 1); }, function () { return pat(i) / 15; }, function (d) { fm.seq.select(i, LIB.clamp(fm.seq.select(i) + d, 0, NPAT - 1)); B.use("SEQ"); }); });
  if (sheet) return [K("ACTION", function () { return SHEET[sheet.i]; }, function () { return sheet.i / 4; }, function (d) { sheet.i = LIB.clamp(sheet.i + d, 0, SHEET.length - 1); }), null, null, null];
  switch (section + ":" + page()) {
    case "ARP:ARP": return t === DR ? [null, null, null, null] : LIB.arpKnobs(inst(t), false);
    case "ARP:ARP 2": return t === DR ? [null, null, null, null] : LIB.arpKnobs(inst(t), true);
    case "SEQ:NOTES":
      return [K("STEP", function () { return String(cursor + 1); }, function () { return cursor / 63; }, function (d) { cursor = LIB.clamp(cursor + d, 0, fm.seq.length(t, pat(t)) - 1); }),
        t === DR ? K("LANE", function () { return GM[drumLane][0]; }, function () { return drumLane / 7; }, function (d) { drumLane = LIB.clamp(drumLane + d, 0, 7); }) : stepK("notes", "PITCH", 0, 1, 1, function (v) { return v.map(LIB.noteName).join(" "); }),
        stepK("len", "LENGTH", 1, 64, B.isDown("ENV") ? 1 : 1, function (v) { return (v / 4).toFixed(2); }),
        B.isDown("ENV") ? stepK("slide", "SLIDE", 0, 1, 1, function (v, st) { return st.slide ? "ON" : "OFF"; }) : stepK("vel", "VEL", 1, 127, 2)];
    case "SEQ:PATTERN": return [K("LEN", function () { return String(fm.seq.length(t, pat(t))); }, function () { return fm.seq.length(t, pat(t)) / 64; }, function (d) { fm.seq.length(t, pat(t), LIB.clamp(fm.seq.length(t, pat(t)) + d, 1, 64)); }),
      K("DIV", function () { return fm.seq.divNames[fm.seq.div(t, pat(t))]; }, function () { return fm.seq.div(t, pat(t)) / 9; }, function (d) { fm.seq.div(t, pat(t), LIB.clamp(fm.seq.div(t, pat(t)) + d, 0, 9)); }),
      K("PATTERN", function () { return String(pat(t) + 1); }, function () { return pat(t) / 15; }, function (d) { fm.seq.select(t, LIB.clamp(fm.seq.select(t) + d, 0, NPAT - 1)); }), null];
    case "SEQ:TEMPO": return [K("BPM", function () { return String(Math.round(fm.seq.tempo())); }, function () { return (fm.seq.tempo() - 40) / 200; }, function (d) { fm.seq.tempo(LIB.clamp(fm.seq.tempo() + d, 30, 300)); }),
      K("SWG", function () { return Math.round(fm.seq.swing()) + "%"; }, function () { return (fm.seq.swing() - 50) / 25; }, function (d) { fm.seq.swing(LIB.clamp(fm.seq.swing() + d, 50, 75)); }),
      K("QNT", function () { return "1/16"; }, function () { return 0.5; }, function () { say("QNT fixed to the step grid here"); }), null];
    case "SEQ:SONG": return [K("SECTION", function () { return song.length ? (songCur + 1) + "/" + song.length : "--"; }, function () { return song.length ? songCur / Math.max(1, song.length - 1) : 0; }, function (d) { songCur = LIB.clamp(songCur + d, 0, Math.max(0, song.length - 1)); }),
      K("TRACK", function () { return "T" + (songTrack + 1); }, function () { return songTrack / 3; }, function (d) { songTrack = LIB.clamp(songTrack + d, 0, NT - 1); }),
      K("PATTERN", function () { var s = song[songCur]; return !s ? "--" : (s.p[songTrack] < 0 ? "REST" : String(s.p[songTrack] + 1)); }, function () { var s = song[songCur]; return s ? (s.p[songTrack] + 1) / 16 : 0; }, function (d) { var s = song[songCur]; if (!s) return; s.p[songTrack] = LIB.clamp(s.p[songTrack] + d, -1, NPAT - 1); applySong(); }),
      K("REPEAT", function () { var s = song[songCur]; return s ? "x" + s.r : "--"; }, function () { var s = song[songCur]; return s ? s.r / 16 : 0; }, function (d) { var s = song[songCur]; if (!s) return; s.r = LIB.clamp(s.r + d, 1, 16); applySong(); })];
    case "SCL:SCALE": return [K("ROOT", function () { return LIB.noteName(60 + S.root).replace(/-?\d+$/, ""); }, function () { return S.root / 11; }, function (d) { S.root = LIB.wrap(S.root + d, 12); saveUI(); }),
      K("SCALE", function () { return LIB.SCALES[S.scale][0]; }, function () { return S.scale / 15; }, function (d) { S.scale = LIB.wrap(S.scale + d, 16); saveUI(); }),
      K("KEYS", function () { return ["CHROM", "SNAP", "WHITE"][S.qnt]; }, function () { return S.qnt / 2; }, function (d) { S.qnt = LIB.clamp(S.qnt + d, 0, 2); saveUI(); }), null];
    case "SCL:CHORD": return [K("CHORD", function () { return CHORD_MODES[S.chord]; }, function () { return S.chord / 6; }, function (d) { S.chord = LIB.clamp(S.chord + d, 0, 6); lastVoicing = []; saveUI(); }), null, null, null];
    case "FX:RACK": return [fxK("reverb", "REVERB"), fxK("delay", "ECHO"), fxK("chorus", "CHORUS"), fxK("distortion", "DRIVE")];
    case "GLO:MIXER": return [0, 1, 2, 3].map(function (i) { return K("T" + (i + 1) + " LVL", function () { return String(Math.round(inst(i).level() * 100)); }, function () { return inst(i).level(); }, function (d) { inst(i).level(LIB.clamp(inst(i).level() + d * 0.02, 0, 1)); }); });
    case "GLO:GLOBAL": return [K("PALETTE", function () { return P().name; }, function () { return S.palette / 7; }, function (d) { S.palette = LIB.wrap(S.palette + d, PALETTES.length); saveUI(); }),
      K("LOOP SONG", function () { return S.loopSong ? "ON" : "OFF"; }, function () { return S.loopSong ? 1 : 0; }, function () { S.loopSong = !S.loopSong; saveUI(); applySong(); }), null, null];
    case "MENU:MENU": return [K("PALETTE", function () { return P().name; }, function () { return S.palette / 7; }, function (d) { S.palette = LIB.wrap(S.palette + d, PALETTES.length); saveUI(); }),
      K("AUTOSAVE", function () { return S.autosave ? "ON" : "OFF"; }, function () { return S.autosave ? 1 : 0; }, function () { S.autosave = !S.autosave; saveUI(); }), null, null];
    case "ENV:ENV": return t === DR || isMidi(t) ? stageKnobs(t) : E(t) === "fm" ? [PK(t, "op1.level", "OP1"), PK(t, "op2.level", "OP2"), PK(t, "op3.level", "OP3"), PK(t, "op4.level", "OP4")] : [PK(t, "a", "ATTACK"), PK(t, "d", "DECAY"), PK(t, "s", "SUSTAIN"), PK(t, "r", "RELEASE")];
    case "LFO:LFO": return E(t) === "va" ? [PK(t, "lforate", "RATE"), PK(t, "lfopitch", "PITCH"), PK(t, "lfocutoff", "FILTER"), PK(t, "lfopw", "PWM")] : E(t) === "pd" ? [PK(t, "vibrate", "RATE"), PK(t, "vib", "DEPTH"), null, null] : E(t) === "fm" ? [PK(t, "lfospeed", "SPEED"), PK(t, "lfopmd", "PMD"), PK(t, "lfoamd", "AMD"), null] : stageKnobs(t);
    case "EDIT:EDIT 1": return E(t) === "va" ? [PK(t, "wave1", "OSC A"), PK(t, "wave2", "OSC B"), PK(t, "semi2", "B SEMI", function (v) { return String(v - 24); }), PK(t, "polymod", "POLY-MOD")]
      : E(t) === "pd" ? [PK(t, "wave1", "WAVE 1", function (v) { return CZW[v]; }), PK(t, "wave2", "WAVE 2", function (v) { return CZW[v]; }), PK(t, "line", "LINE", function (v) { return ["1", "1+2", "1+1'", "1x2"][v]; }), PK(t, "dcwenv", "DCW ENV")]
      : E(t) === "fm" ? [PK(t, "algorithm", "ALGO"), PK(t, "feedback", "FB"), PK(t, "op1.coarse", "OP1 RAT"), PK(t, "op2.coarse", "OP2 RAT")] : stageKnobs(t);
    case "EDIT:EDIT 2": return E(t) === "va" ? [PK(t, "sync", "SYNC"), PK(t, "detune", "DETUNE"), PK(t, "mode", "VOICE", function (v) { return ["POLY", "MONO", "LEGATO", "UNISON"][v]; }), PK(t, "glide", "GLIDE")]
      : E(t) === "pd" ? [PK(t, "dd", "DCW DEC"), PK(t, "ds", "DCW SUS"), PK(t, "mode", "VOICE", function (v) { return ["POLY", "MONO", "LEGATO"][v]; }), PK(t, "glide", "GLIDE")] : stageKnobs(t);
  }
  return stageKnobs(t);
}
var fxState = fm.store.get("fx", { reverb: 28, delay: 0, chorus: 0, distortion: 0 });
function fxK(kind, label) {
  return K(label, function () { return fxState[kind] ? String(fxState[kind]) : "OFF"; }, function () { return fxState[kind] / 100; }, function (d) {
    fxState[kind] = LIB.clamp(fxState[kind] + d * 2, 0, 100); var v = fxState[kind];
    if (kind === "reverb") fm.fx("reverb", v > 0, 1, v, 25); else if (kind === "delay") fm.fx("delay", v > 0, -1, v, 30); else if (kind === "chorus") fm.fx("chorus", v > 0, 40, v, 50); else fm.fx("distortion", v > 0, v, v, 60);
    fm.store.set("fx", fxState);
  });
}
function browse(d) {
  var t = S.track, cat = CATS[browser.cat];
  if (t === DR) { loadSound(t, S.kit + d); return; }
  if (isMidi(t)) { say("MIDI TRACK · DEFAULT"); return; }
  if (E(t) === "fm") { loadSound(t, S.sound[t] + d); return; }
  var list = SOUNDS[E(t)], i = S.sound[t];
  if (cat === "RECENT") {
    var rec = S.recent.filter(function (x) { return x.indexOf(t + ":" + E(t) + ":") === 0; }).map(function (x) { return +x.split(":")[2]; });
    if (!rec.length) return;
    var at = rec.indexOf(i); loadSound(t, rec[LIB.wrap(at + d, rec.length)]); return;
  }
  for (var n = 1; n <= list.length; n++) { var j = LIB.wrap(i + d * n, list.length); if (cat === "ALL" || list[j].cat === cat) { loadSound(t, j); return; } }
  say("NO " + cat + " SOUNDS");
}

function onKnob(i, d) { var k = knobs()[i]; if (k) k.turn(d); }
function onEncoder(name, d) {
  if (name === "ALGORITHM") { selectTrack(LIB.clamp(S.track + d, 0, NT - 1)); return; }
  if (name === "PRESETS") {
    if (section === "SEQ" && page() === "NOTES" && !browser) { zoom = LIB.clamp(zoom * (d > 0 ? 0.5 : 2), 1, 16); return; }
    if (!browser) browser = { cat: 0, prev: S.track === DR || isMidi(S.track) ? S.kit : S.sound[S.track] };
    browse(d); return;
  }
  if (name === "SELECT") {
    if (B.isDown("SEQ")) { var t = S.track; fm.seq.select(t, LIB.clamp(fm.seq.select(t) + d, 0, NPAT - 1)); B.use("SEQ"); return; }
    if (layer === "GLO" || section === "HOME") { fm.seq.tempo(LIB.clamp(fm.seq.tempo() + d, 30, 300)); if (layer) B.use("GLO"); return; }
    pageIx = LIB.wrap(pageIx + d, PAGES[section].length); sheet = null;
  }
}
function onTick(ms) {
  var now = fm.now();
  // a pattern key held for a second opens its dialog
  if (heldPat >= 0 && !patDialog && now - heldPatT0 > 900) { patDialog = { p: heldPat }; }
  for (var i = pendingOff.length - 1; i >= 0; i--) if (now > pendingOff[i][0]) { inst(pendingOff[i][1]).off(pendingOff[i][2]); pendingOff.splice(i, 1); }
  if (fm.seq.playing()) {
    // armed while playing: recording starts at the track's next pattern start
    var lp = fm.seq.loop(S.track);
    if (recWait && armed && lp !== waitLoop && waitLoop >= 0) { recWait = false; recording = true; undo.push(S.track, pat(S.track)); }
    waitLoop = lp;
    // jam to song: every loop of track 1 logs the patterns of all tracks
    var l0 = fm.seq.loop(0);
    if (l0 !== lastLoop) { lastLoop = l0; jam.push([0, 1, 2, 3, 4, 5, 6, 7].map(pat)); if (jam.length > 64) jam.shift(); }
  } else waitLoop = -1;
}
var waitLoop = -1;

// ---- drawing ----
function header(g, label) {
  var p = P(), t = S.track;
  g.rect(0, 0, 240, 24, p.panel);
  g.rect(0, 0, 4, 24, TC(t));
  g.text(10, 4, label, { size: 12, weight: "bold", color: p.text });
  var playing = fm.seq.playing();
  g.text(234, 5, (recording ? "● " : armed ? "○ " : "") + (playing ? "▶ " : "■ ") + Math.round(fm.seq.tempo()), { size: 11, weight: "bold", align: "right", color: recording || armed ? "#ff4a3d" : (playing ? TC(t) : p.sub) });
}
function strip(g) {
  var p = P(), ks = knobs(), t = S.track;
  g.rect(0, 196, 240, 44, p.panel);
  for (var i = 0; i < 4; i++) {
    var k = ks[i], x = 4 + i * 59;
    if (!k) continue;
    var shade = LIB.hexA(TC(t), ["ff", "cc", "99", "77"][i]);
    g.text(x + 27, 199, k.label, { size: 8, weight: "bold", align: "center", color: shade });
    g.text(x + 27, 211, String(k.text()).slice(0, 11), { size: 12, weight: "bold", align: "center", color: p.text });
    g.rect(x + 6, 232, 43, 3, LIB.hexA(p.sub, "40"), 1.5);
    g.rect(x + 6, 232, 43 * LIB.clamp(k.frac() || 0, 0, 1), 3, shade, 1.5);
  }
}
function drawStage(g) {
  var p = P(), t = S.track;
  header(g, "T" + (t + 1) + " " + engineName(t) + " · " + soundName(t).slice(0, 14));
  // the notes and chord in front of the live waveform
  g.scope(8, 30, 224, 64, LIB.hexA(TC(t), "88"), 1.5);
  var names = lastChord.map(LIB.noteName).join(" ");
  if (t === DR) {
    for (var l = 0; l < 8; l++) { var hit = fm.now() - (sounding["d" + GM[l][1]] || 0) < 160; g.rect(14 + l * 27, 70, 22, 18, hit ? TC(t) : LIB.hexA(p.sub, "30"), 4); g.text(25 + l * 27, 74, GM[l][0].slice(0, 2), { size: 8, weight: "bold", align: "center", color: hit ? p.bg : p.sub }); }
  } else g.text(120, 46, names || " ", { size: 18, weight: "bold", align: "center", color: p.text });
  // a lane per track: its sound, its pattern (and the next one), every step as dots
  for (var tr = bank(t); tr < bank(t) + 4; tr++) {
    var y = 100 + (tr - bank(t)) * 24, pp = pat(tr), sel = fm.seq.select(tr), len = fm.seq.length(tr, pp), cur = fm.seq.step(tr);
    g.rect(4, y, 232, 21, tr === t ? LIB.hexA(TC(tr), "33") : p.panel, 4);
    if (tr === t && armed) g.frame(4, y, 232, 21, (recording && (fm.seq.beat() % 1) < 0.25) || (!recording && fm.now() % 1400 < 700) ? "#ff4a3d" : "#ff4a3d55", 1.5, 4);
    g.text(10, y + 4, String(tr + 1), { size: 10, weight: "bold", color: fm.seq.mute(tr) ? p.sub : TC(tr) });
    g.text(22, y + 4, soundName(tr).slice(0, 9), { size: 9, color: fm.seq.mute(tr) ? p.sub : p.text });
    g.text(96, y + 4, (pp + 1) + (sel !== pp ? "›" + (sel + 1) : ""), { size: 9, weight: "bold", color: TC(tr) });
    var rows = fm.seq.rows(tr), n = Math.min(len, 32), dx = 112 / Math.max(16, n);
    for (var s = 0; s < n; s++) {
      var on = false; for (var r = 0; r < rows && !on; r++) on = fm.seq.get(tr, pp, s, r).vel > 0;
      var x = 118 + s * dx + dx / 2, c = s === cur ? p.text : (on ? TC(tr) : LIB.hexA(p.sub, "40"));
      g.circle(x, y + 10, on || s === cur ? 2.4 : 1.4, c);
    }
  }
}
function drawWheel(g) {
  var p = P(), cx = 120, cy = 104, R = 62;
  header(g, "HOME · CHORD WHEEL");
  var fifths = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5], inKey = LIB.SCALES[S.scale][1];
  var pts = {};
  for (var i = 0; i < 12; i++) {
    var pc = (fifths[i] + S.root) % 12, a = (i / 12) * Math.PI * 2 - Math.PI / 2, x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R;
    pts[pc] = [x, y];
    var key = inKey.indexOf(LIB.wrap(pc - S.root, 12)) >= 0, lit = false;
    for (var n in sounding) if (sounding.hasOwnProperty(n) && n.charAt(0) !== "d" && (+n) % 12 === pc) lit = true;
    g.circle(x, y, 13, lit ? TC(S.track) : (key ? LIB.hexA(p.text, "30") : LIB.hexA(p.sub, "18")));
    g.text(x, y - 6, LIB.noteName(60 + pc).replace(/-?\d+$/, ""), { size: 10, weight: "bold", align: "center", color: lit ? p.bg : (key ? p.text : p.sub) });
  }
  var ch = lastChord.map(function (n) { return n % 12; });
  for (var j = 0; j < ch.length; j++) { var a1 = pts[ch[j]], a2 = pts[ch[(j + 1) % ch.length]]; if (a1 && a2 && ch.length > 1) g.line(a1[0], a1[1], a2[0], a2[1], TC(S.track), 2); }
  g.text(cx, cy - 8, lastChord.length ? LIB.noteName(lastChord[0]).replace(/-?\d+$/, "") : "", { size: 16, weight: "bold", align: "center", color: p.text });
  var corners = [[14, 32], [226, 32], [14, 180], [226, 180]];
  for (var t = 0; t < 4; t++) g.circle(corners[t][0], corners[t][1], 3 + 7 * Math.min(1, inst(t).meter()), TC(t));
}
function drawNotes(g) {
  var p = P(), t = S.track, pp = pat(t), len = fm.seq.length(t, pp), cur = fm.seq.step(t);
  header(g, "SEQ · NOTES · T" + (t + 1) + " · P" + (pp + 1));
  var span = zoom, start = Math.max(0, Math.min(Math.floor(cursor / span) * span, 64 - span)), w = 224 / span;
  if (t === DR) {
    for (var l = 0; l < 8; l++) for (var s = 0; s < span; s++) {
      var st = fm.seq.get(t, pp, start + s, GM[l][1]), x = 8 + s * w, y = 30 + l * 20;
      g.rect(x + 1, y, w - 2, 16, st.vel ? TC(t) : LIB.hexA(p.sub, start + s < len ? "22" : "0a"), 2);
      if (start + s === cursor && l === drumLane) g.frame(x, y - 1, w, 18, p.text, 1.5, 2);
    }
  } else {
    var lo = 127, hi = 0;
    for (var s2 = start; s2 < start + span; s2++) { var st2 = fm.seq.get(t, pp, s2); for (var n = 0; n < st2.notes.length; n++) { lo = Math.min(lo, st2.notes[n]); hi = Math.max(hi, st2.notes[n]); } }
    if (lo > hi) { lo = lastNote - 6; hi = lastNote + 6; }
    var range = Math.max(12, hi - lo + 3), top = hi + 2, rh = 160 / range;
    for (var s3 = 0; s3 < span; s3++) {
      var x2 = 8 + s3 * w;
      g.rect(x2, 30, w - 1, 160, LIB.hexA(p.sub, (start + s3) >= len ? "06" : ((start + s3) % 4 === 0 ? "1c" : "10")), 1);
      var st3 = fm.seq.get(t, pp, start + s3);
      for (var m = 0; m < st3.notes.length; m++) {
        var y2 = 30 + (top - st3.notes[m]) * rh, nw = Math.max(3, w * st3.len / 4 - 1);
        g.rect(x2, y2, nw, Math.max(3, rh - 1), st3.slide ? p.text : TC(t), 2);
        if (start + s3 === cursor) g.frame(x2 - 1, y2 - 1, nw + 2, Math.max(3, rh - 1) + 2, p.text, 1.5, 2);
      }
    }
    var cx = 8 + (cursor - start) * w;
    if (cursor >= start && cursor < start + span) g.frame(cx, 30, w - 1, 160, LIB.hexA(p.text, "55"), 1, 1);
  }
  if (cur >= start && cur < start + span) g.rect(8 + (cur - start) * w, 30, 2, 160, TC(t));
  if (sheet) {
    g.rect(40, 60, 160, 100, LIB.hexA(p.panel, "f2"), 8); g.frame(40, 60, 160, 100, TC(t), 1.5, 8);
    for (var i = 0; i < SHEET.length; i++) g.text(52, 68 + i * 17, (i === sheet.i ? "▶ " : "  ") + SHEET[i], { size: 11, weight: i === sheet.i ? "bold" : "regular", color: i === sheet.i ? p.text : p.sub });
  }
}
function drawPatterns(g) {
  var p = P();
  header(g, "PATTERNS" + (bank(S.track) ? " · T5–8 MIDI" : ""));
  for (var t = bank(S.track); t < bank(S.track) + 4; t++) {
    var y = 30 + (t - bank(S.track)) * 34;
    g.text(8, y + 8, String(t + 1), { size: 11, weight: "bold", color: TC(t) });
    var playing = pat(t), queued = fm.seq.select(t);
    for (var i = 0; i < NPAT; i++) {
      var x = 22 + (i % 8) * 27 + (i >= 8 ? 0 : 0), yy = y + (i >= 8 ? 15 : 0), has = fm.seq.has(t, i);
      var c = i === playing && fm.seq.playing() ? TC(t) : (has ? LIB.hexA(TC(t), "66") : LIB.hexA(p.sub, "18"));
      g.rect(x, yy, 24, 13, c, 3);
      if (i === queued && queued !== playing) g.frame(x, yy, 24, 13, p.text, 1.2, 3);
      if (t === S.track) g.text(x + 12, yy + 1, String(i + 1), { size: 8, weight: "bold", align: "center", color: i === playing ? p.bg : p.text });
    }
  }
  var letters = song.map(function (s, i) { return String.fromCharCode(65 + (i % 26)); }).join("");
  g.text(8, 170, "SONG " + (letters || "(jam: " + jam.length + " loops)"), { size: 10, color: p.sub });
  if (patDialog) {
    g.rect(30, 60, 180, 90, LIB.hexA(p.panel, "f4"), 8); g.frame(30, 60, 180, 90, TC(S.track), 1.5, 8);
    g.text(120, 68, "PATTERN " + (patDialog.p + 1) + " · LEN " + fm.seq.length(S.track, patDialog.p), { size: 12, weight: "bold", align: "center", color: p.text });
    g.text(120, 90, "same key: delete · other: copy", { size: 10, align: "center", color: p.sub });
    g.text(120, 106, "C# halve · D# double · OCT− leave", { size: 10, align: "center", color: p.sub });
  }
}
function drawSong(g) {
  var p = P();
  header(g, "SEQ · SONG" + (fm.seq.songOn() ? " · PLAYING " + (fm.seq.songSection() + 1) : ""));
  if (!song.length) { g.text(120, 80, "No song yet", { size: 14, weight: "bold", align: "center", color: p.text }); g.text(120, 104, "OCT+ add a section · hold REC: take the jam", { size: 10, align: "center", color: p.sub }); return; }
  var start = Math.max(0, songCur - 6), beatsTotal = 0;
  var sb = bank(songTrack);
  for (var t = sb; t < sb + 4; t++) g.text(6, 46 + (t - sb) * 30, String(t + 1), { size: 10, weight: "bold", color: TC(t) });
  for (var i = 0; i < 8 && start + i < song.length; i++) {
    var s = song[start + i], x = 18 + i * 27;
    g.text(x + 12, 30, String.fromCharCode(65 + ((start + i) % 26)), { size: 10, weight: "bold", align: "center", color: start + i === songCur ? p.text : p.sub });
    for (var t2 = sb; t2 < sb + 4; t2++) {
      var v = s.p[t2] === undefined ? -1 : s.p[t2], r2 = t2 - sb;
      g.rect(x, 42 + r2 * 30, 24, 24, v < 0 ? LIB.hexA(p.sub, "12") : LIB.hexA(TC(t2), "bb"), 3);
      g.text(x + 12, 47 + r2 * 30, v < 0 ? "–" : String(v + 1), { size: 10, weight: "bold", align: "center", color: v < 0 ? p.sub : p.bg });
    }
    g.text(x + 12, 164, "x" + s.r, { size: 8, align: "center", color: p.sub });
    if (start + i === songCur) g.frame(x - 2, 40, 28, 120, p.text, 1.5, 4);
    if (fm.seq.songOn() && fm.seq.songSection() === start + i) g.rect(x, 176, 24, 3, TC(0), 1);
  }
  for (var j = 0; j < song.length; j++) beatsTotal += song[j].r * fm.seq.length(0, Math.max(0, song[j].p[0])) / 4;
  var secs = Math.round(beatsTotal * 60 / fm.seq.tempo());
  g.text(234, 30, Math.floor(secs / 60) + ":" + ("0" + secs % 60).slice(-2), { size: 9, align: "right", color: p.sub });
}
function drawBrowser(g) {
  var p = P(), t = S.track;
  header(g, "SOUNDS · T" + (t + 1) + " " + engineName(t) + " · " + CATS[browser.cat]);
  var list = [];
  if (t === DR) list = KITS.map(function (k, i) { return [i, k.name + " KIT", "DRUM"]; });
  else if (isMidi(t)) list = [[0, "DEFAULT", "MIDI"]];
  else if (E(t) === "fm") for (var i = -5; i <= 5; i++) { var ix = LIB.wrap(S.sound[t] + i, 128); list.push([ix, fm.presetName(ix), "FM6"]); }
  else list = SOUNDS[E(t)].map(function (s, i) { return [i, s.name, s.cat]; }).filter(function (x) { return CATS[browser.cat] === "ALL" || CATS[browser.cat] === "RECENT" || x[2] === CATS[browser.cat]; });
  var cur = t === DR ? S.kit : (isMidi(t) ? 0 : S.sound[t]);
  for (var j = 0; j < list.length && j < 10; j++) {
    var sel = list[j][0] === cur, y = 30 + j * 16;
    if (sel) g.rect(4, y - 1, 232, 16, LIB.hexA(TC(t), "44"), 3);
    g.text(10, y, list[j][1], { size: 11, weight: sel ? "bold" : "regular", color: sel ? p.text : p.sub });
    g.text(230, y + 2, list[j][2], { size: 8, align: "right", color: p.sub });
  }
  g.text(120, 182, "OCT+ keep · OCT− back to the previous sound", { size: 9, align: "center", color: p.sub });
}
function drawSimple(g, title, lines) {
  var p = P();
  header(g, title);
  for (var i = 0; i < lines.length; i++) g.text(12, 34 + i * 17, lines[i], { size: 11, color: i ? p.sub : p.text });
  g.scope(10, 130, 220, 56, LIB.hexA(TC(S.track), "77"), 1.2);
}
function render(g) {
  var p = P();
  g.clear(p.bg);
  if (browser) drawBrowser(g);
  else if (B.isDown("SEQ")) drawPatterns(g);
  else if (layer === "GLO") drawSimple(g, "GLO" + (latched ? " · LOCKED" : ""), ["F3–B3 mute T1–4 · C4–F4 solo", "G4 fill (held) · G5 tap tempo", "KNOB 1–4 track levels · SELECT BPM"]);
  else if (layer === "SCL") drawSimple(g, "SCL", ["white key: ROOT", "ROOT " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "") + " " + LIB.SCALES[S.scale][0], "CHORD " + CHORD_MODES[S.chord]]);
  else switch (section + ":" + page()) {
    case "HOME:STAGE": drawStage(g); break;
    case "HOME:WHEEL": drawWheel(g); break;
    case "SEQ:NOTES": drawNotes(g); break;
    case "SEQ:SONG": drawSong(g); break;
    case "SEQ:PATTERN": drawSimple(g, "SEQ · PATTERN", ["T" + (S.track + 1) + " pattern " + (pat(S.track) + 1), "LEN " + fm.seq.length(S.track, pat(S.track)) + " · DIV " + fm.seq.divNames[fm.seq.div(S.track, pat(S.track))]]); break;
    case "SEQ:TEMPO": drawSimple(g, "SEQ · TEMPO", [Math.round(fm.seq.tempo()) + " BPM", "SWING " + Math.round(fm.seq.swing()) + "%"]); break;
    case "SCL:SCALE": drawSimple(g, "SCL · SCALE", ["ROOT " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "") + "  " + LIB.SCALES[S.scale][0], "KEYS " + ["CHROMATIC", "SNAP", "WHITE KEYS"][S.qnt]]); break;
    case "SCL:CHORD": drawSimple(g, "SCL · CHORD", [CHORD_MODES[S.chord], S.chord === 1 ? "in-key chords, smooth voice leading" : S.chord === 2 ? "your melody on top, harmony below" : ""]); break;
    case "FX:RACK": drawSimple(g, "FX · SHARED RACK", ["REVERB · ECHO · CHORUS · DRIVE", "(per-track note FX: not in this port)"]); break;
    case "GLO:MIXER": drawSimple(g, "GLO · MIXER", [0, 1, 2, 3].map(function (t) { return "T" + (t + 1) + " " + engineName(t) + "  " + Math.round(inst(t).level() * 100) + (fm.seq.mute(t) ? " MUTE" : ""); }).join("  ").match(/.{1,34}/g)); break;
    case "MENU:MENU": drawSimple(g, "MENU", ["PALETTE " + P().name, "AUTOSAVE " + (S.autosave ? "ON" : "OFF"), "Melodee 1.6.1 for FM Pocket", "re-implemented from its manual"]); break;
    case "ARP:ARP": case "ARP:ARP 2": drawSimple(g, page() + " · T" + (S.track + 1), S.track === DR ? ["no arpeggiator on the drum track"] : LIB.arpLines(inst(S.track))); break;
    default: drawSimple(g, section + " · " + page(), ["T" + (S.track + 1) + " " + engineName(S.track) + " · " + soundName(S.track)]);
  }
  strip(g);
  if (flash && fm.now() < flashUntil) { g.rect(20, 92, 200, 30, LIB.hexA(p.panel, "f0"), 8); g.frame(20, 92, 200, 30, TC(S.track), 1.5, 8); g.text(120, 99, flash, { size: 12, weight: "bold", align: "center", color: p.text }); }
  leds();
}
var arpLastStep = 0, arpFlashUntil = 0;
function arpBeat() {
  if (S.track === DR) return false;
  var s = inst(S.track).arp();
  if (!s.on || s.step === 0) return false;
  if (s.step !== arpLastStep) { arpLastStep = s.step; arpFlashUntil = fm.now() + 110; }
  return fm.now() < arpFlashUntil;
}
function leds() {
  var t = S.track, playing = fm.seq.playing();
  for (var i = 0; i < 16; i++) {
    var k = fm.keyOfWhite(i), c = null;
    if (B.isDown("SEQ")) {
      var has = fm.seq.has(t, i), pl = pat(t) === i, q = fm.seq.select(t) === i && !pl;
      c = pl ? TC(t) : (q ? (fm.now() % 1000 < 500 ? TC(t) : null) : (has ? LIB.hexA(TC(t), "55") : null));
    }
    fm.led.key(k, c);
  }
  for (var b = 0; b < NT; b++) if (B.isDown("SEQ")) fm.led.key(fm.keyOfBlack(b), b === t ? TC(b) : (armed && b === t ? "#ff4a3d" : null));
  fm.led.button("PLAY", playing ? "green" : "off");
  fm.led.button("REC", recording ? "red" : (armed && fm.now() % 1000 < 500 ? "red" : "off"));
  var names = ["SEQ", "SAVE", "FX", "ENV", "LFO", "EDIT", "ARP", "HOME"];
  for (var n = 0; n < names.length; n++) fm.led.button(names[n], section === names[n] ? "on" : "off");
  if (section !== "ARP") fm.led.button("ARP", arpBeat() ? "on" : "off");   // beat LED while an arp runs
  fm.led.button("SEL", section === "SCL" || layer === "SCL" ? "on" : "off");
  fm.led.button("GLO", layer === "GLO" ? (latched ? "blue" : "on") : (section === "GLO" ? "on" : "off"));
}
function onShutdown() { saveUI(); fm.store.set("song", song); }

// Incoming MIDI: notes play the selected track (GM drum map on the drum track) and record while REC runs.
function onMidi(kind, n, v, ch) {
  if (kind !== "on" && kind !== "off") return;
  var t = S.track;
  LIB.midiNote(t, inst(t), t === DR, kind, n, v, recording && fm.seq.playing());
}
