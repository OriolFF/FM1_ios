// Felucca for FM Pocket — a re-implementation of the behaviour documented in the Felucca 1.8
// wiki manual (github.com/hugelton/Felucca/wiki, GPL-3.0). No Felucca code is used; see
// ../README.md and research/FIRMWARES.md for what is ported and what is approximated.

var PAL = { bg: "#14161b", card: "#23262e", card2: "#2c3039", text: "#eef0f4", sub: "#9aa1af", acc: "#f2c14e", rec: "#ff5a4a", play: "#64d68a" };
var TCOL = ["#6fb7ff", "#9b8cff", "#ff8fb0", "#f2c14e"];
var INST = ["t1", "t2", "t3", "drums"];
var ENGINE = ["ANALOG", "FM6", "PHASE", "DRUM"];
var DR = 3;
// Felucca DRUM: 8 lanes on the GM map → this host's 11-voice kit
var LANE_NAMES = ["KICK", "SNARE", "CL HAT", "OP HAT", "CLAP", "LO TOM", "HI TOM", "CYMBAL"];
var LANE_HOST = [0, 1, 10, 9, 6, 2, 4, 8];
var HOSTN = ["BD", "SD", "LT", "MT", "HT", "RM", "CP", "CB", "CY", "OH", "CH"];
var SLOTS = "ABCD";

var SOUNDS = {
  t1: [
    { name: "INIT", cat: "OTHER" },
    { name: "DEEP BASS", cat: "BASS", wave1: 0, osc2: 0.6, semi2: 12, sub: 0.5, cutoff: 0.32, res: 0.25, envamt: 0.7, fd: 0.4, fs: 0.1, a: 0, d: 0.5, s: 0.8, r: 0.3, mode: 1 },
    { name: "SYNC LEAD", cat: "LEAD", wave1: 0, wave2: 0, semi2: 31, osc1: 0.3, osc2: 1, sync: 1, cutoff: 0.72, res: 0.2, envamt: 0.6, a: 0.01, d: 0.5, s: 0.8, r: 0.3, mode: 2, glide: 0.15 },
    { name: "WARM PAD", cat: "PAD", wave1: 0, wave2: 1, osc2: 0.7, detune: 0.56, cutoff: 0.5, res: 0.1, envamt: 0.5, fa: 0.6, a: 0.65, d: 0.7, s: 0.9, r: 0.72 },
    { name: "PLUCKY", cat: "PLUCK", wave1: 1, osc2: 0.4, cutoff: 0.34, res: 0.35, envamt: 0.95, fd: 0.36, fs: 0, a: 0, d: 0.45, s: 0, r: 0.3 },
    { name: "BRASSY", cat: "KEYS", wave1: 0, wave2: 0, osc2: 0.8, detune: 0.53, cutoff: 0.42, res: 0.15, envamt: 0.75, fa: 0.3, fd: 0.5, fs: 0.5, a: 0.2, d: 0.5, s: 0.85, r: 0.35 },
    { name: "HP NOISE", cat: "FX", wave1: 3, osc1: 0, osc2: 0, noise: 1, ftype: 2, cutoff: 0.7, res: 0.5, envamt: 0.6, a: 0.3, d: 0.6, s: 0.4, r: 0.6 }
  ],
  t3: [
    { name: "INIT", cat: "OTHER" },
    { name: "PD BASS", cat: "BASS", wave1: 1, dcw: 0.1, dcwenv: 0.85, dd: 0.4, ds: 0.05, a: 0, d: 0.5, s: 0.4, r: 0.3, mode: 1 },
    { name: "PD BELL", cat: "KEYS", wave1: 3, wave2: 5, line: 1, semi2: 43, dcw: 0.25, dcwenv: 0.5, dd: 0.55, ds: 0.1, a: 0, d: 0.65, s: 0, r: 0.6 },
    { name: "FOLD LEAD", cat: "LEAD", wave1: 0, dcw: 0.5, dcwenv: 0.3, fold: 0.55, a: 0.01, d: 0.5, s: 0.8, r: 0.3, mode: 2, glide: 0.12 },
    { name: "RESO SWEEP", cat: "PLUCK", wave1: 6, dcw: 0.1, dcwenv: 0.9, dd: 0.5, ds: 0, a: 0, d: 0.5, s: 0.1, r: 0.4 },
    { name: "PD STRINGS", cat: "PAD", wave1: 0, line: 2, detune: 0.62, dcw: 0.2, dcwenv: 0.35, da: 0.6, dd: 0.7, ds: 0.5, a: 0.6, d: 0.7, s: 0.9, r: 0.72, vib: 0.12 }
  ]
};
var KITS = [
  { name: "STD", p: {} },
  { name: "80", p: { "BD.decay": 0.85, "BD.tone": 0.3, "SD.tone": 0.75, "CH.tone": 0.55 } },
  { name: "10", p: { "BD.tune": 0.6, "BD.decay": 0.45, "SD.tone": 0.85, "CP.decay": 0.8, "CY.level": 0.9 } },
  { name: "66", p: { "BD.tone": 0.2, "BD.decay": 0.4, "SD.tone": 0.85, "CH.tone": 0.7, "LT.tune": 0.75, "HT.tune": 0.8 } },
  { name: "55", p: { "BD.tune": 0.45, "BD.decay": 0.55, "CH.tune": 0.8, "OH.tune": 0.8, "CY.tune": 0.75, "CB.level": 0.9 } },
  { name: "77", p: { "BD.decay": 0.7, "CP.decay": 0.75, "RM.tune": 0.8, "CY.decay": 0.8 } },
  { name: "DEEP", p: { "BD.tune": 0.35, "BD.decay": 0.95, "CY.decay": 0.95 } },
  { name: "TIGHT", p: { "BD.decay": 0.25, "SD.decay": 0.25, "CH.decay": 0.15, "OH.decay": 0.3, "CP.decay": 0.3 } },
  { name: "PERC", p: { "LT.tune": 0.8, "HT.tune": 0.9, "RM.tune": 0.85, "CB.tune": 0.6, "BD.decay": 0.35 } }
];

// pages by button (taps go round)
var PAGES = {
  HOME: ["HOME", "MIXER", "CLOCK"], SEQ: ["STEP", "DETAIL", "AUTOMATION"], GLO: ["SONG"],
  SAVE: ["PRESETS", "PROJECT"], LFO: ["LFO", "LFO 2"], EDIT: ["EDIT 1", "EDIT 2", "VOICE"],
  FX: ["FX", "SENDS"], SEL: ["SCL", "CHORD"], ENV: ["ENV"], ARP: ["ARP", "ARP 2"]
};
var LAYERS = { FX: 1, GLO: 1, SEL: 1, EDIT: 1, REC: 1, SEQ: 1 };

var B = new LIB.Buttons();
var undo = new LIB.Undo(1);              // Felucca: one-step undo (SAVE held)
var S = fm.store.get("ui", null) || { track: 0, sound: [1, 0, 1], kit: 0, slot: 0, octave: 0, qnt: 0, root: 0, scale: 0, trn: 0, chord: 0, voic: 0, quantize: [true, true, true, true], countIn: 1, palette: 0 };
var button = "HOME", pageIx = 0;         // open page
var layer = null, latched = null;
var cursor = 0;                          // SEQ step cursor
var heldStep = -1, heldUsed = false;
var recArmed = false, recording = false, countUntil = -1;
var stepEntryNotes = [];
var flash = "", flashUntil = 0;
var edited = [false, false, false, false];
var momentary = {};                      // LFO held: param → original value
var heldKeys = {};
var autoScroll = 0, songCursor = 0, songTrack = 0;
var song = fm.store.get("song", []);
var tapTimes = [];
var layerSnap = null;

function inst(t) { return fm.inst(INST[t]); }
function pat(t) { return fm.seq.pattern(t); }
function say(m, ms) { flash = m; flashUntil = fm.now() + (ms || 1100); }
function saveUI() { fm.store.set("ui", S); }
function page() { return PAGES[button][pageIx % PAGES[button].length]; }
function soundName(t) {
  if (t === DR) return "KIT " + KITS[S.kit].name;
  if (t === 1) return fm.presetName(S.sound[1]);
  return SOUNDS[INST[t]][S.sound[t]].name;
}
var DEF = { wave1: 0, wave2: 1, pw: 0.5, semi2: 24, detune: 0.5, osc1: 1, osc2: 0.7, sub: 0, noise: 0, sync: 0, polymod: 0, cutoff: 0.55, res: 0.2, ftype: 0, envamt: 0.7, keytrack: 0.5, fa: 0.05, fd: 0.45, fs: 0.3, fr: 0.4, a: 0.02, d: 0.5, s: 0.8, r: 0.35, drive: 0.2, glide: 0, mode: 0, lforate: 0.5, lfowave: 0, lfopitch: 0, lfocutoff: 0, lfopw: 0, level: 0.8, vel: 0.5, spread: 0.3, line: 0, dcw: 0.3, dcwenv: 0.6, da: 0.02, dd: 0.5, ds: 0.3, dr: 0.4, fold: 0, vib: 0, vibrate: 0.55 };
function loadSound(t, i) {
  if (t === DR) {
    S.kit = LIB.wrap(i, KITS.length);
    var d = fm.inst("drums");
    for (var l = 0; l < HOSTN.length; l++) { d.set(HOSTN[l] + ".level", 100 / 127); d.set(HOSTN[l] + ".tune", 0.5); d.set(HOSTN[l] + ".decay", 0.5); d.set(HOSTN[l] + ".tone", 0.5); }
    var p = KITS[S.kit].p; for (var k in p) if (p.hasOwnProperty(k)) d.set(k, p[k]);
    return;
  }
  if (t === 1) { S.sound[1] = LIB.wrap(i, 128); fm.inst("t2").preset(S.sound[1]); return; }
  var list = SOUNDS[INST[t]]; S.sound[t] = LIB.wrap(i, list.length);
  var s = list[S.sound[t]], names = inst(t).params();
  for (var n = 0; n < names.length; n++) inst(t).set(names[n], s[names[n]] !== undefined ? s[names[n]] : (DEF[names[n]] !== undefined ? DEF[names[n]] : 0));
}

function onBoot() {
  if (!fm.store.get("init", false)) {
    loadSound(0, S.sound[0]); loadSound(2, S.sound[2]); loadSound(DR, 0); fm.inst("t2").preset(0);
    fm.seq.tempo(120);
    fm.store.set("init", true);
  } else fm.inst("t2").preset(S.sound[1]);
  for (var t = 0; t < 4; t++) fm.seq.select(t, S.slot);
  fm.fx("reverb", true, 0, 30, 20);
}

// ---- notes ----
function keyNotes(k) {
  var n;
  if (S.qnt === 2) { var w = fm.whiteIndex(k); if (w < 0) return null; n = LIB.degree(60 + S.root, S.scale, w - 4); }   // WHITE: C4 = ROOT
  else { n = 53 + k; if (S.qnt === 1 || S.qnt === 3) n = LIB.snap(n, S.root, S.scale); }
  n += (S.octave + fm.octave()) * 12 + S.trn;
  if (S.chord > 0) return LIB.chordNotes(n, S.chord, 60 + S.root, S.scale);
  return [n];
}
function isStepPage() { return button === "SEQ" && page() === "STEP" && !layer; }

function onKey(k, down, vel) {
  if (layer) { layerKey(k, down); return; }
  var t = S.track, w = fm.whiteIndex(k), b = fm.blackIndex(k);
  // SEQ > STEP: white keys are the steps, black keys pick drum lanes (stopped step entry uses the keys as notes)
  if (isStepPage() && !(recArmed && !fm.seq.playing() && t !== DR)) {
    if (t === DR && b >= 0) { if (down && b < 8) { cursorLane = b; fm.inst("drums").hit(LANE_HOST[b], 100); } return; }
    if (w < 0) return;
    var s = Math.floor(cursor / 16) * 16 + w;
    if (down) { heldStep = s; heldUsed = false; cursor = s; }
    else if (heldStep === s) { if (!heldUsed) toggleStep(s); heldStep = -1; }
    return;
  }
  if (t === DR) {
    if (!down) return;
    var lane = w >= 0 ? w % 8 : (b >= 0 ? b % 8 : -1); if (lane < 0) return;
    fm.inst("drums").hit(LANE_HOST[lane], vel);
    if (recording) { var st = fm.seq.recordHit(DR, LANE_HOST[lane], vel); if (st >= 0 && S.quantize[DR]) fm.seq.set(DR, pat(DR), st, { nudge: 0 }, LANE_HOST[lane]); markEdited(DR); }
    return;
  }
  if (down) {
    var notes = keyNotes(k); if (!notes) return;
    heldKeys[k] = notes;
    for (var i = 0; i < notes.length; i++) inst(t).note(notes[i], vel);
    if (recArmed && !fm.seq.playing()) {
      // step recording at the cursor, one chord at a time
      for (var j = 0; j < notes.length; j++) if (stepEntryNotes.indexOf(notes[j]) < 0 && stepEntryNotes.length < 4) stepEntryNotes.push(notes[j]);
      fm.seq.set(t, pat(t), cursor, { vel: vel, notes: stepEntryNotes.slice(), len: 3 }); markEdited(t);
    } else if (recording) {
      for (var m = 0; m < notes.length; m++) { var st2 = fm.seq.record(t, notes[m], vel); if (st2 >= 0 && S.quantize[t]) fm.seq.set(t, pat(t), st2, { nudge: 0 }); }
      markEdited(t);
    }
    lastNote = notes[0];
  } else if (heldKeys[k]) {
    for (var x = 0; x < heldKeys[k].length; x++) inst(t).off(heldKeys[k][x]);
    delete heldKeys[k];
    if (recArmed && !fm.seq.playing() && Object.keys(heldKeys).length === 0 && stepEntryNotes.length) {
      stepEntryNotes = []; cursor = (cursor + 1) % fm.seq.length(t, pat(t));
    }
  }
}
var lastNote = 60, cursorLane = 0;
function markEdited(t) { edited[t] = true; }
function toggleStep(s) {
  var t = S.track, p = pat(t);
  undo.push(t, p); markEdited(t);
  if (t === DR) {
    var lane = LANE_HOST[cursorLane], st = fm.seq.get(t, p, s, lane);
    if (st.vel) fm.seq.clear(t, p, s, lane); else { fm.seq.set(t, p, s, { vel: 100 }, lane); fm.inst("drums").hit(lane, 100); }
  } else {
    var st2 = fm.seq.get(t, p, s);
    if (st2.vel) fm.seq.clear(t, p, s); else fm.seq.set(t, p, s, { vel: 100, notes: [lastNote], len: 3 });
  }
}

// ---- layers ----
var FX_KEYS = [["REPEAT 1/4", "REPEAT", 1], ["REPEAT 1/8", "REPEAT", 0.5], ["REPEAT 1/16", "REPEAT", 0.25], ["REVERSE", "REVERSE", 1],
  ["FILTER LP", "LP SWEEP", 1], ["FILTER HP", "HP SWEEP", 1], ["TAPE STOP", "TAPE STOP", 1], ["FREEZE", "REPEAT", 2],
  ["OCT UP", null], ["OCT DN", null], ["FLANGER", null], ["PHASER", "phaser"], ["REV THROW", "reverb"], ["ECHO THROW", "ECHO", 1], ["STUTTER", "STUTTER", 0.0625], ["CRUSH", "CRUSH", 1]];
var fxHeld = -1;
function layerKey(k, down) {
  var w = fm.whiteIndex(k), b = fm.blackIndex(k), t = S.track;
  B.use(layer);
  if (layer === "FX") {
    if (b >= 0) { if (down && b < 4) { var m = !fm.seq.mute(b); fm.seq.mute(b, m); say("T" + (b + 1) + (m ? " MUTE" : " ON")); } return; }
    var d = FX_KEYS[w];
    if (down) {
      fxHeld = w;
      if (d[1] === "phaser") fm.fx("phaser", true, 60, 60, 50);
      else if (d[1] === "reverb") fm.fx("reverb", true, 0, 100, 20);
      else if (d[1]) fm.punch(d[1], d[2]);
      say(d[0] + (d[1] ? "" : " · n/a here"));
    } else if (fxHeld === w) { endFx(); }
    return;
  }
  if (!down) { if (layer === "GLO" && k === 11) fm.seq.fill(false); return; }
  if (layer === "GLO") {
    if (w >= 0 && w < 4) { var mm = !fm.seq.mute(w); fm.seq.mute(w, mm); say("T" + (w + 1) + (mm ? " MUTE" : " ON")); }
    else if (b >= 0 && b < 4) { solo(b); }
    else if (k === 11) fm.seq.fill(true);                  // E4: FILL
    else if (k === 9) say("MIDI LEARN · n/a here");         // D4
    else if (k === 26) tap();
    return;
  }
  if (layer === "SEQ") { seqTool(w, b); return; }
  if (layer === "EDIT") {
    if (t === DR && b >= 0 && b < 8) { var lm = !fm.seq.laneMute(DR, LANE_HOST[b]); fm.seq.laneMute(DR, LANE_HOST[b], lm); say(LANE_NAMES[b] + (lm ? " MUTE" : " ON")); }
    else if (w >= 0 && w < 4) { S.track = w; saveUI(); say("TRACK " + (w + 1) + " " + ENGINE[w]); }
    return;
  }
  if (layer === "SEL") { if (w >= 0) { S.root = LIB.wrap(53 + k, 12); saveUI(); say("ROOT " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "")); } return; }
  if (layer === "REC") {
    if (w === 0) { undo.push(t, pat(t)); fm.seq.clear(t, pat(t)); say("CLEAR T" + (t + 1)); }
    else if (w === 1) say("CLICK · n/a here");
    else if (w === 2) { S.countIn = (S.countIn + 1) % 3; saveUI(); say("COUNT-IN " + ["OFF", "1 BAR", "2 BARS"][S.countIn]); }
    else if (w === 3) { S.quantize[t] = !S.quantize[t]; saveUI(); say("QUANTIZE " + (S.quantize[t] ? "ON" : "OFF")); }
  }
}
function endFx() {
  var d = FX_KEYS[fxHeld];
  if (d && d[1] === "phaser") fm.fx("phaser", false);
  else if (d && d[1] === "reverb") fm.fx("reverb", true, 0, 30, 20);
  else fm.punch("OFF");
  fxHeld = -1;
}
var soloT = -1;
function solo(t) { soloT = soloT === t ? -1 : t; for (var i = 0; i < 4; i++) fm.seq.mute(i, soloT >= 0 && i !== soloT); say(soloT >= 0 ? "SOLO T" + (t + 1) : "SOLO OFF"); }
function tap() {
  var now = fm.now(); tapTimes = tapTimes.filter(function (x) { return now - x < 2500; }); tapTimes.push(now);
  if (tapTimes.length > 1) fm.seq.tempo(Math.round(60000 * (tapTimes.length - 1) / (tapTimes[tapTimes.length - 1] - tapTimes[0])));
  say("TAP " + Math.round(fm.seq.tempo()));
}
var TOOLS = ["CLEAR", "REVERSE", "SHIFT <", "SHIFT >", "RANDOM", "COOK", "EUCLID", "DOUBLE", "HALF"];
var DRUM_TOOLS = ["BEAT", "LANE CLR", "LANE REV", "LANE FILL", "LANE RND"];
var euclidHits = 4;
function seqTool(w, b) {
  var t = S.track, p = pat(t);
  if (b >= 0 && t === DR && b < 8) { cursorLane = b; say("LANE " + LANE_NAMES[b]); return; }
  var all = TOOLS.concat(t === DR ? DRUM_TOOLS : []);
  if (w < 0 || w >= all.length) return;
  undo.push(t, p); markEdited(t);
  var name = all[w], len = fm.seq.length(t, p), lane = LANE_HOST[cursorLane];
  switch (name) {
    case "CLEAR": fm.seq.clear(t, p); break;
    case "REVERSE": LIB.reverse(t, p); break;
    case "SHIFT <": LIB.shift(t, p, -1); break;
    case "SHIFT >": LIB.shift(t, p, 1); break;
    case "RANDOM":
      if (t === DR) beat(p, true);
      else {
        // new notes in the scale on the same rhythm (or a new rhythm if empty)
        var hasAny = fm.seq.has(t, p);
        for (var s = 0; s < len; s++) {
          var st = fm.seq.get(t, p, s);
          if (st.vel || (!hasAny && Math.random() < 0.4)) fm.seq.set(t, p, s, { vel: st.vel || 100, notes: [LIB.degree(48 + S.root + 12 * (t === 0 ? 0 : 1), S.scale, Math.floor(Math.random() * 8))], len: 3 });
        }
      }
      break;
    case "COOK":
      for (var c = 0; c < 2; c++) {
        var s2 = Math.floor(Math.random() * len), row = t === DR ? lane : 0, st2 = fm.seq.get(t, p, s2, row);
        if (t === DR) { if (st2.vel) fm.seq.clear(t, p, s2, row); else fm.seq.set(t, p, s2, { vel: 70 + Math.floor(Math.random() * 50) }, row); }
        else if (st2.vel) fm.seq.set(t, p, s2, { notes: [LIB.snap(st2.notes[0] + (Math.random() < 0.5 ? -2 : 2), S.root, S.scale)] });
      }
      break;
    case "EUCLID": {
      var pattern = LIB.euclid(euclidHits, len, 0), row2 = t === DR ? lane : 0;
      for (var e = 0; e < len; e++) { if (pattern[e]) fm.seq.set(t, p, e, t === DR ? { vel: 100 } : { vel: 100, notes: [lastNote], len: 3 }, row2); else fm.seq.clear(t, p, e, row2); }
      say("EUCLID " + euclidHits + "/" + len); euclidHits = euclidHits % 9 + 1; return;
    }
    case "DOUBLE": LIB.double(t, p); break;
    case "HALF": fm.seq.length(t, p, Math.max(1, len >> 1)); break;
    case "BEAT": beat(p, false); break;
    case "LANE CLR": fm.seq.clear(t, p, -1, lane); break;
    case "LANE REV": { var a = []; for (var r = 0; r < len; r++) a.push(fm.seq.get(t, p, r, lane)); for (var r2 = 0; r2 < len; r2++) { var src = a[len - 1 - r2]; if (src.vel) fm.seq.set(t, p, r2, src, lane); else fm.seq.clear(t, p, r2, lane); } break; }
    case "LANE FILL": for (var f = 0; f < len; f++) fm.seq.set(t, p, f, { vel: f % 4 === 0 ? 110 : 80 }, lane); break;
    case "LANE RND": for (var q = 0; q < len; q++) if (Math.random() < 0.3) fm.seq.set(t, p, q, { vel: 60 + Math.floor(Math.random() * 60) }, lane); else fm.seq.clear(t, p, q, lane); break;
  }
  say(name);
}
function beat(p, random) {
  var len = fm.seq.length(DR, p);
  fm.seq.clear(DR, p);
  for (var s = 0; s < len; s++) {
    if (s % 4 === 0 || (random && Math.random() < 0.12)) fm.seq.set(DR, p, s, { vel: 110 }, 0);
    if (s % 8 === 4 || (random && Math.random() < 0.08)) fm.seq.set(DR, p, s, { vel: 105 }, 1);
    if (s % 2 === 0 || (random && Math.random() < 0.3)) fm.seq.set(DR, p, s, { vel: s % 4 === 2 ? 95 : 70 }, 10);
  }
}

// ---- buttons ----
function onButton(name, down) {
  if (down) {
    B.press(name);
    if (name === "OCT-" || name === "OCT+") { octave(name); return; }
    if (name === "LFO") momentary = {};
    if (LAYERS[name] && latched !== name) { layer = name; layerSnap = LIB.snapshot(S.track, pat(S.track)); }
    return;
  }
  var kind = B.release(name);
  if (name === "OCT-" || name === "OCT+") return;
  if (name === "LFO") {
    // MOMENTARY: values turned with LFO held jump back (OCT+ while holding keeps them)
    var restored = false;
    for (var key in momentary) if (momentary.hasOwnProperty(key)) { var mm = momentary[key]; inst(mm.t).set(mm.p, mm.v); restored = true; }
    momentary = {};
    if (restored) return;
  }
  if (LAYERS[name] && layer === name) {
    if (kind === "double") { latched = name; say(name + " LAYER LATCHED"); return; }
    if (latched !== name) layer = null;
    if (name === "FX" && fxHeld >= 0) endFx();
    if (name === "GLO") fm.seq.fill(false);
    if (kind === "hold") return;
  } else if (latched === name) { latched = null; layer = null; say(name + " LAYER CLOSED"); return; }
  if (kind === "hold") {
    if (name === "SAVE") { if (undo.undo()) say("UNDO"); else say("NOTHING TO UNDO"); }
    else if (name === "HOME") say("MENU · n/a here");
    return;
  }
  // taps (page buttons act when let go)
  if (name === "PLAY") { togglePlay(); return; }
  if (name === "REC") { recButton(); return; }
  var target = name === "SEL" ? "SEL" : name;
  if (!PAGES[target]) return;
  if (button === target) pageIx = (pageIx + 1) % PAGES[target].length; else { button = target; pageIx = 0; }
  if (target === "HOME" && pageIx === 0) layer = null;
}
function octave(name) {
  var up = name === "OCT+";
  // action pages: OCT+ does it, OCT− goes back
  if (B.isDown("LFO") && up) { momentary = {}; say("KEPT"); B.use("LFO"); return; }
  if (layer === "SEQ") { if (!up && layerSnap) { LIB.restore(layerSnap); say("PUT BACK"); } B.use("SEQ"); return; }
  if (button === "GLO" && page() === "SONG") { if (up) { var on = !fm.seq.songOn(); applySong(); fm.seq.songOn(on); say(on ? "SONG ON" : "SONG OFF"); } else if (song.length) { song.splice(songCursor, 1); songCursor = Math.max(0, songCursor - 1); applySong(); } return; }
  if (button === "SAVE" && page() === "PROJECT") { if (up) loadSlot(projCursor); return; }
  if (isStepPage() && heldStep >= 0) { heldUsed = true; return; }
  if (B.isDown(up ? "OCT-" : "OCT+")) { S.octave = 0; saveUI(); say("OCTAVE 0"); return; }
  S.octave = LIB.clamp(S.octave + (up ? 1 : -1), -3, 3); saveUI(); say("OCTAVE " + S.octave);
}
function togglePlay() {
  if (fm.seq.playing()) { fm.seq.stop(); recording = false; for (var t = 0; t < 3; t++) inst(t).allOff(); return; }
  if (recArmed) { recArmed = false; recording = true; undo.push(S.track, pat(S.track)); countUntil = S.countIn ? fm.now() + S.countIn * 4 * 60000 / fm.seq.tempo() : -1; }
  fm.seq.play();
}
function recButton() {
  if (fm.seq.playing()) { recording = !recording; if (recording) undo.push(S.track, pat(S.track)); say(recording ? "REC" : "REC OFF"); return; }
  recArmed = !recArmed; stepEntryNotes = [];
  say(recArmed ? (isStepPage() ? "STEP REC AT CURSOR" : "ARMED T" + (S.track + 1)) : "DISARMED");
}
var projCursor = 0;
function loadSlot(i) {
  S.slot = i; saveUI();
  for (var t = 0; t < 4; t++) { fm.seq.select(t, i); edited[t] = false; }
  say("PROJECT " + SLOTS[i]);
}
function applySong() {
  fm.seq.song(song.map(function (s) { return { patterns: s.slots, repeats: s.rep }; }), true);
  fm.store.set("song", song);
}

// ---- knobs ----
function knobFor(t, name, label) {
  var i = inst(t), disc = ["wave1", "wave2", "semi2", "sync", "ftype", "mode", "lfowave", "line"].indexOf(name) >= 0;
  var WN = { wave1: ["SAW", "PULSE", "TRI", "SINE"], wave2: ["SAW", "PULSE", "TRI", "SINE"], ftype: ["LP", "BP", "HP"], mode: ["POLY", "MONO", "LEGATO", "UNISON"], lfowave: ["TRI", "SINE", "SQR", "S&H"], line: ["1", "1+2", "1+1'", "1x2"] };
  if (t === 2) WN.wave1 = WN.wave2 = ["SAW", "SQR", "PULSE", "DSIN", "SAWP", "RES1", "RES2", "RES3"], WN.mode = ["POLY", "MONO", "LEGATO"];
  return {
    label: label, t: t, p: name,
    text: function () { var v = i.get(name); if (WN[name]) return WN[name][v] || String(v); if (name === "semi2") return String(v - 24); if (t === 1) return String(Math.round(v)); return String(Math.round(v * 100)); },
    frac: function () { var v = i.get(name); return disc ? 0.5 : (t === 1 ? v / 127 : v); },
    turn: function (d) {
      var v = i.get(name);
      if (B.isDown("LFO") && momentary[t + ":" + name] === undefined) { momentary[t + ":" + name] = { t: t, p: name, v: v }; B.use("LFO"); }
      if (t === 1) i.set(name, LIB.clamp(v + d, 0, name === "algorithm" ? 31 : (name === "feedback" ? 7 : 99)));
      else i.set(name, disc ? v + d : LIB.clamp(v + d * 0.01, 0, 1));
    }
  };
}
function simple(label, text, frac, turn) { return { label: label, text: text, frac: frac, turn: turn }; }
function drumKnob(laneIx, p, label) {
  var key = HOSTN[LANE_HOST[laneIx]] + "." + p;
  var k = simple(label, function () { return String(Math.round(fm.inst("drums").get(key) * 127)); }, function () { return fm.inst("drums").get(key); },
    function (d) { fm.inst("drums").set(key, LIB.clamp(fm.inst("drums").get(key) + d / 127, 0, 1)); });
  k.p = key;
  return k;
}
function mainKnobs(t) {
  if (t === 0) return [knobFor(0, "cutoff", "CUTOFF"), knobFor(0, "res", "RESO"), knobFor(0, "envamt", "ENV AMT"), knobFor(0, "r", "RELEASE")];
  if (t === 1) return [knobFor(1, "op1.level", "OP1 LVL"), knobFor(1, "op2.level", "OP2 LVL"), knobFor(1, "feedback", "FEEDBACK"), knobFor(1, "algorithm", "ALGO")];
  if (t === 2) return [knobFor(2, "dcw", "DCW"), knobFor(2, "dcwenv", "DCW ENV"), knobFor(2, "fold", "FOLD"), knobFor(2, "r", "RELEASE")];
  return [drumKnob(cursorLane, "level", LANE_NAMES[cursorLane].slice(0, 6) + " LV"), drumKnob(cursorLane, "tune", "TUNE"), drumKnob(cursorLane, "decay", "DECAY"), drumKnob(cursorLane, "tone", "TONE")];
}
function tempoKnob() { return simple("BPM", function () { return String(Math.round(fm.seq.tempo())); }, function () { return (fm.seq.tempo() - 40) / 200; }, function (d) { fm.seq.tempo(LIB.clamp(fm.seq.tempo() + d, 30, 300)); }); }
function swingKnob() { return simple("SWING", function () { return Math.round(fm.seq.swing()) + "%"; }, function () { return (fm.seq.swing() - 50) / 25; }, function (d) { fm.seq.swing(LIB.clamp(fm.seq.swing() + d, 50, 75)); }); }
function levelKnob(t) { return simple("T" + (t + 1) + " LEVEL", function () { return String(Math.round(inst(t).level() * 100)); }, function () { return inst(t).level(); }, function (d) { inst(t).level(LIB.clamp(inst(t).level() + d * 0.02, 0, 1)); }); }
function stepField(field, label, lo, hi, fmt) {
  return simple(label, function () { var t = S.track, st = fm.seq.get(t, pat(t), cursor, t === DR ? LANE_HOST[cursorLane] : 0); return st.vel ? (fmt ? fmt(st[field]) : String(st[field])) : "--"; },
    function () { var t = S.track, st = fm.seq.get(t, pat(t), cursor, t === DR ? LANE_HOST[cursorLane] : 0); return (st[field] - lo) / (hi - lo); },
    function (d) { var t = S.track, row = t === DR ? LANE_HOST[cursorLane] : 0, st = fm.seq.get(t, pat(t), cursor, row); if (!st.vel) return; var o = {}; o[field] = LIB.clamp(st[field] + d, lo, hi); fm.seq.set(t, pat(t), cursor, o, row); markEdited(t); });
}
function knobs() {
  var t = S.track;
  if (layer === "SEQ") return [simple("LEN", function () { return String(fm.seq.length(t, pat(t))); }, function () { return fm.seq.length(t, pat(t)) / 64; }, function (d) { fm.seq.length(t, pat(t), LIB.clamp(fm.seq.length(t, pat(t)) + d, 1, 64)); }),
    simple("DIV", function () { return fm.seq.divNames[fm.seq.div(t, pat(t))]; }, function () { return fm.seq.div(t, pat(t)) / 9; }, function (d) { fm.seq.div(t, pat(t), LIB.clamp(fm.seq.div(t, pat(t)) - d, 0, 9)); }),
    swingKnob(), simple("GATE", function () { return gateOf(t) + "%"; }, function () { return gateOf(t) / 100; }, function (d) { setGate(t, d); })];
  if (layer === "GLO") return [levelKnob(0), levelKnob(1), levelKnob(2), levelKnob(3)];
  if (layer === "SEL") return sclKnobs();
  if (isStepPage() && heldStep >= 0) return mainKnobs(t).map(function (k) { return lockKnob(k); });
  var pg = page();
  switch (button + ":" + pg) {
    case "HOME:MIXER": return [levelKnob(0), levelKnob(1), levelKnob(2), levelKnob(3)];
    case "HOME:CLOCK": return [tempoKnob(), swingKnob(), simple("CLOCK", function () { return "INT"; }, function () { return 0; }, function () {}), simple("QUANTIZE", function () { return S.quantize[t] ? "ON" : "OFF"; }, function () { return S.quantize[t] ? 1 : 0; }, function () { S.quantize[t] = !S.quantize[t]; saveUI(); })];
    case "SEQ:STEP": return t === DR ? [simple("STEP", function () { return String(cursor + 1); }, function () { return cursor / 63; }, function (d) { cursor = LIB.clamp(cursor + d, 0, fm.seq.length(t, pat(t)) - 1); }), simple("LANE", function () { return LANE_NAMES[cursorLane]; }, function () { return cursorLane / 7; }, function (d) { cursorLane = LIB.clamp(cursorLane + d, 0, 7); }), stepField("vel", "VEL", 1, 127), stepField("ratchet", "RATCH", 1, 4, function (v) { return "x" + v; })]
      : [simple("STEP", function () { return String(cursor + 1); }, function () { return cursor / 63; }, function (d) { cursor = LIB.clamp(cursor + d, 0, fm.seq.length(t, pat(t)) - 1); }), noteKnob(), stepField("len", "LENGTH", 1, 64, function (v) { return (v / 4).toFixed(2); }), stepField("vel", "VEL", 1, 127)];
    case "SEQ:DETAIL": return [stepField("chance", "CHANCE", 0, 100, function (v) { return v + "%"; }), stepField("ratchet", "RATCH", 1, 4, function (v) { return "x" + v; }), stepField("nudge", "NUDGE", -8, 7, function (v) { return (v > 0 ? "+" : "") + v + "/16"; }), stepField("vel", "VEL", 1, 127)];
    case "SEQ:AUTOMATION": return [simple("RECORD", function () { return String(autoScroll + 1); }, function () { return 0; }, function (d) { autoScroll = Math.max(0, autoScroll + d); }), stepField("cond", "COND", 0, 2, function (v) { return ["PLAY", "FILL", "!FILL"][v] || String(v); }), null, null];
    case "GLO:SONG": return songKnobs();
    case "SAVE:PRESETS": return [simple("CATEGORY", function () { return t === DR ? "DRUM" : catOf(t); }, function () { return 0; }, function (d) { jumpCategory(t, d); }), simple("SOUND", function () { return soundName(t).slice(0, 8); }, function () { return 0; }, function (d) { loadSound(t, (t === DR ? S.kit : S.sound[t]) + d); saveUI(); }), null, null];
    case "SAVE:PROJECT": return [simple("SLOT", function () { return SLOTS[projCursor]; }, function () { return projCursor / 3; }, function (d) { projCursor = LIB.clamp(projCursor + d, 0, 3); }), simple("COPY TO", function () { return SLOTS[projCursor]; }, function () { return 0; }, function (d) { if (d > 0) { for (var tt = 0; tt < 4; tt++) fm.seq.copy(tt, pat(tt), projCursor); say("COPIED TO " + SLOTS[projCursor]); } }), null, null];
    case "EDIT:EDIT 1": return t === DR ? mainKnobs(t) : t === 0 ? [knobFor(0, "wave1", "WAVE 1"), knobFor(0, "wave2", "WAVE 2"), knobFor(0, "semi2", "SEMI 2"), knobFor(0, "detune", "DETUNE")]
      : t === 1 ? [knobFor(1, "algorithm", "ALGO"), knobFor(1, "feedback", "FEEDBACK"), knobFor(1, "op1.coarse", "OP1 RATIO"), knobFor(1, "op2.coarse", "OP2 RATIO")] : [knobFor(2, "wave1", "WAVE 1"), knobFor(2, "wave2", "WAVE 2"), knobFor(2, "line", "LINE"), knobFor(2, "semi2", "SEMI 2")];
    case "EDIT:EDIT 2": return t === 0 ? [knobFor(0, "cutoff", "CUTOFF"), knobFor(0, "res", "RESO"), knobFor(0, "ftype", "FILTER"), knobFor(0, "drive", "DRIVE")] : t === 1 ? [knobFor(1, "op3.level", "OP3 LVL"), knobFor(1, "op4.level", "OP4 LVL"), knobFor(1, "op5.level", "OP5 LVL"), knobFor(1, "op6.level", "OP6 LVL")] : t === 2 ? [knobFor(2, "dcw", "DCW"), knobFor(2, "fold", "FOLD"), knobFor(2, "detune", "DETUNE"), knobFor(2, "vel", "VELO")] : mainKnobs(t);
    case "EDIT:VOICE": return t === DR ? [drumKnob(0, "level", "KICK LV"), drumKnob(1, "level", "SNARE LV"), drumKnob(2, "level", "HAT LV"), simple("KIT", function () { return KITS[S.kit].name; }, function () { return S.kit / 8; }, function (d) { loadSound(DR, S.kit + d); saveUI(); })]
      : t === 1 ? [knobFor(1, "transpose", "TRANSP"), knobFor(1, "lfospeed", "LFO SPD"), null, null] : [knobFor(t, "mode", "VOICE"), knobFor(t, "glide", "GLIDE"), knobFor(t, "vel", "VELO"), knobFor(t, "level", "LEVEL")];
    case "ENV:ENV": return t === 0 || t === 2 ? [knobFor(t, "a", "ATTACK"), knobFor(t, "d", "DECAY"), knobFor(t, "s", "SUSTAIN"), knobFor(t, "r", "RELEASE")] : mainKnobs(t);
    case "LFO:LFO": return t === 0 ? [knobFor(0, "lforate", "RATE"), knobFor(0, "lfowave", "WAVE"), knobFor(0, "lfopitch", "PITCH"), knobFor(0, "lfocutoff", "CUTOFF")] : t === 2 ? [knobFor(2, "vibrate", "RATE"), knobFor(2, "vib", "DEPTH"), null, null] : t === 1 ? [knobFor(1, "lfospeed", "SPEED"), knobFor(1, "lfopmd", "PMD"), knobFor(1, "lfoamd", "AMD"), knobFor(1, "lfowave", "WAVE")] : [null, null, null, null];
    case "LFO:LFO 2": return t === 0 ? [knobFor(0, "lfopw", "PW MOD"), knobFor(0, "pw", "PW"), knobFor(0, "polymod", "POLYMOD"), null] : [null, null, null, null];
    case "FX:FX": return [master("filter", "FILTER", -1, 1), master("dust", "CRUSH", 0, 1), fxKnob("distortion", "DRIVE"), fxKnob("phaser", "PHASER")];
    case "FX:SENDS": return [fxKnob("chorus", "CHORUS"), fxKnob("delay", "DELAY"), fxKnob("reverb", "REVERB"), tempoKnob()];
    case "SEL:SCL": return sclKnobs();
    case "SEL:CHORD": return [simple("CHRD", function () { return LIB.CHORDS[S.chord]; }, function () { return S.chord / 5; }, function (d) { S.chord = LIB.clamp(S.chord + d, 0, 5); saveUI(); }), simple("VOIC", function () { return ["CLOSE", "OPEN"][S.voic]; }, function () { return S.voic; }, function (d) { S.voic = LIB.clamp(S.voic + d, 0, 1); saveUI(); }), null, null];
    case "ARP:ARP": return t === DR ? [null, null, null, null] : LIB.arpKnobs(inst(t), false);
    case "ARP:ARP 2": return t === DR ? [null, null, null, null] : LIB.arpKnobs(inst(t), true);
  }
  return mainKnobs(t);
}
function noteKnob() {
  return simple("NOTE", function () { var t = S.track, st = fm.seq.get(t, pat(t), cursor); return st.vel ? LIB.noteName(st.notes[0]) : "--"; }, function () { return 0.5; },
    function (d) { var t = S.track, st = fm.seq.get(t, pat(t), cursor); if (st.vel) { fm.seq.set(t, pat(t), cursor, { notes: st.notes.map(function (n) { return LIB.clamp(n + d, 12, 120); }) }); markEdited(t); } });
}
function lockKnob(k) {
  if (!k || !k.p) return k;
  return simple("LOCK " + k.label, function () {
    var t = S.track, st = fm.seq.get(t, pat(t), heldStep, t === DR ? LANE_HOST[cursorLane] : 0);
    for (var i = 0; i < st.locks.length; i++) if (st.locks[i][0] === inst(t).paramIndex(k.p)) return String(Math.round(st.locks[i][1] / 2.55));
    return k.text();
  }, k.frac, function (d) {
    var t = S.track, p = pat(t), row = t === DR ? LANE_HOST[cursorLane] : 0, st = fm.seq.get(t, p, heldStep, row), idx = inst(t).paramIndex(k.p), locks = st.locks.slice(), found = -1;
    for (var i = 0; i < locks.length; i++) if (locks[i][0] === idx) found = i;
    var base = found >= 0 ? locks[found][1] : Math.round((k.frac() || 0) * 255);
    var v = LIB.clamp(base + d * 3, 0, 255);
    if (found >= 0) locks[found] = [idx, v]; else if (locks.length < 2) locks.push([idx, v]); else { say("2 LOCKS PER STEP"); return; }
    if (!st.vel) { say("NO NOTE ON STEP"); return; }
    fm.seq.set(t, p, heldStep, { locks: locks }, row); heldUsed = true; markEdited(t);
  });
}
function gateOf(t) { var st = fm.seq.get(t, pat(t), 0); return Math.round(st.len * 25); }
function setGate(t, d) {
  var p = pat(t), len = fm.seq.length(t, p);
  for (var s = 0; s < len; s++) { var st = fm.seq.get(t, p, s); if (st.vel) fm.seq.set(t, p, s, { len: LIB.clamp(st.len + d, 1, 4) }); }
  fm.seq.set(t, p, 0, { len: LIB.clamp(fm.seq.get(t, p, 0).len + d, 1, 4) });
}
function sclKnobs() {
  return [simple("QNT", function () { return ["OFF", "SNAP", "WHITE", "SEQ"][S.qnt]; }, function () { return S.qnt / 3; }, function (d) { S.qnt = LIB.clamp(S.qnt + d, 0, 3); saveUI(); }),
    simple("ROOT", function () { return LIB.noteName(60 + S.root).replace(/-?\d+$/, ""); }, function () { return S.root / 11; }, function (d) { S.root = LIB.wrap(S.root + d, 12); saveUI(); }),
    simple("SCALE", function () { return LIB.SCALES[S.scale][0]; }, function () { return S.scale / 15; }, function (d) { S.scale = LIB.wrap(S.scale + d, 16); saveUI(); }),
    simple("TRN", function () { return String(S.trn); }, function () { return (S.trn + 12) / 24; }, function (d) { S.trn = LIB.clamp(S.trn + d, -12, 12); saveUI(); })];
}
function songKnobs() {
  function cur() { if (!song.length) song.push({ slots: [S.slot, S.slot, S.slot, S.slot], rep: 1 }); songCursor = Math.min(songCursor, song.length - 1); return song[songCursor]; }
  return [simple("SECTION", function () { return (songCursor + 1) + "/" + Math.max(1, song.length); }, function () { return songCursor / 15; }, function (d) {
      if (d > 0 && songCursor >= song.length - 1 && song.length < 16) song.push(JSON.parse(JSON.stringify(cur())));
      songCursor = LIB.clamp(songCursor + d, 0, Math.max(0, song.length - 1)); applySong(); }),
    simple("TRACK", function () { return "T" + (songTrack + 1); }, function () { return songTrack / 3; }, function (d) { songTrack = LIB.clamp(songTrack + d, 0, 3); }),
    simple("SLOT", function () { var v = cur().slots[songTrack]; return v < 0 ? "-" : SLOTS[v]; }, function () { return (cur().slots[songTrack] + 1) / 4; }, function (d) { var s = cur(); s.slots[songTrack] = LIB.clamp(s.slots[songTrack] + d, -1, 3); applySong(); }),
    simple("REPEAT", function () { return "x" + cur().rep; }, function () { return cur().rep / 16; }, function (d) { var s = cur(); s.rep = LIB.clamp(s.rep + d, 1, 16); applySong(); })];
}
function catOf(t) { return t === 1 ? "FM6 BANK" : SOUNDS[INST[t]][S.sound[t]].cat; }
function jumpCategory(t, d) {
  if (t === 1 || t === DR) { loadSound(t, (t === DR ? S.kit : S.sound[1]) + d * (t === 1 ? 8 : 1)); saveUI(); return; }
  var list = SOUNDS[INST[t]], cur = list[S.sound[t]].cat;
  for (var i = 1; i <= list.length; i++) { var j = LIB.wrap(S.sound[t] + d * i, list.length); if (list[j].cat !== cur) { loadSound(t, j); saveUI(); return; } }
}
var masterState = fm.store.get("master", { filter: 0, dust: 0, duck: 0 });
function master(key, label, lo, hi) {
  return simple(label, function () { return String(Math.round(masterState[key] * 100)); }, function () { return (masterState[key] - lo) / (hi - lo); },
    function (d) { masterState[key] = LIB.clamp(masterState[key] + d * 0.02, lo, hi); fm.master(masterState); fm.store.set("master", masterState); });
}
var fxState = fm.store.get("fx", { reverb: 30, delay: 0, chorus: 0, distortion: 0, phaser: 0 });
function fxKnob(kind, label) {
  return simple(label, function () { return fxState[kind] ? String(fxState[kind]) : "OFF"; }, function () { return fxState[kind] / 100; }, function (d) {
    fxState[kind] = LIB.clamp(fxState[kind] + d * 2, 0, 100); var v = fxState[kind], on = v > 0;
    if (kind === "reverb") fm.fx("reverb", on, 0, v, 20); else if (kind === "delay") fm.fx("delay", on, -1, v, 30);
    else if (kind === "chorus") fm.fx("chorus", on, 40, v, 50); else fm.fx(kind, on, v, v, 50);
    fm.store.set("fx", fxState);
  });
}

function onKnob(i, d) {
  var k = knobs()[i];
  if (layer) B.use(layer);
  if (!k) return;
  k.turn(d);
  if (isStepPage() && heldStep >= 0) heldUsed = true;
}
function onEncoder(name, d) {
  if (name === "ALGORITHM") { for (var t = 0; t < 3; t++) inst(t).allOff(); S.track = LIB.clamp(S.track + d, 0, 3); saveUI(); return; }
  if (name === "PRESETS") {
    if (isStepPage() && heldStep >= 0) { var st = fm.seq.get(S.track, pat(S.track), heldStep, S.track === DR ? LANE_HOST[cursorLane] : 0); if (st.vel) fm.seq.set(S.track, pat(S.track), heldStep, { nudge: LIB.clamp(st.nudge + d, -8, 7) }, S.track === DR ? LANE_HOST[cursorLane] : 0); heldUsed = true; return; }
    loadSound(S.track, (S.track === DR ? S.kit : S.sound[S.track]) + d); saveUI(); say(soundName(S.track)); return;
  }
  if (name === "SELECT") {
    if (layer) { B.use(layer); fm.seq.tempo(LIB.clamp(fm.seq.tempo() + d, 30, 300)); return; }
    pageIx = LIB.wrap(pageIx + d, PAGES[button].length);
  }
}
function onTick(ms) {
  if (countUntil > 0 && fm.now() > countUntil) countUntil = -1;
}

// ---- drawing ----
function header(g) {
  var t = S.track;
  g.rect(0, 0, 240, 26, PAL.card);
  g.rect(6, 5, 30, 16, TCOL[t], 4);
  g.text(21, 6, (t + 1) + " " + SLOTS[pat(t) % 4] + (edited[t] ? "*" : ""), { size: 11, weight: "bold", align: "center", color: "#111318" });
  g.text(42, 6, soundName(t).slice(0, 15), { size: 12, weight: "bold", color: PAL.text });
  var playing = fm.seq.playing();
  g.text(234, 6, (recording ? "● " : (recArmed ? "○ " : "")) + (playing ? "▶ " : "■ ") + Math.round(fm.seq.tempo()), { size: 11, weight: "bold", align: "right", color: recording || recArmed ? PAL.rec : (playing ? PAL.play : PAL.sub) });
}
function cards(g, ks) {
  for (var i = 0; i < 4; i++) {
    var x = 4 + i * 59, y = 186, k = ks[i];
    g.rect(x, y, 55, 50, k ? PAL.card : "#1b1d23", 6);
    if (!k) continue;
    g.text(x + 27, y + 5, k.label, { size: 8, weight: "bold", align: "center", color: PAL.sub });
    g.text(x + 27, y + 18, k.text(), { size: 14, weight: "bold", align: "center", color: PAL.text });
    var f = LIB.clamp(k.frac() || 0, 0, 1);
    g.rect(x + 6, y + 41, 43, 3, "#ffffff18", 1.5);
    g.rect(x + 6, y + 41, 43 * f, 3, TCOL[S.track], 1.5);
  }
}
function title(g, s) { g.text(10, 32, s, { size: 10, weight: "bold", color: PAL.acc }); }
function drawHome(g) {
  title(g, "HOME");
  g.scope(10, 56, 220, 110, TCOL[S.track], 1.8);
  g.text(230, 32, ENGINE[S.track], { size: 10, align: "right", color: PAL.sub });
}
function drawTracks(g, label) {
  title(g, label);
  for (var t = 0; t < 4; t++) {
    var y = 50 + t * 32, p = pat(t), len = fm.seq.length(t, p), cur = fm.seq.step(t);
    g.text(10, y, String(t + 1), { size: 13, weight: "bold", color: fm.seq.mute(t) ? PAL.sub : TCOL[t] });
    g.text(24, y + 2, ENGINE[t] + (fm.seq.mute(t) ? " · MUTE" : ""), { size: 8, color: PAL.sub });
    for (var s = 0; s < 16; s++) {
      var on = false, rows = fm.seq.rows(t), ss = (cur >= 0 ? Math.floor(cur / 16) * 16 : 0) + s;
      for (var r = 0; r < rows && !on; r++) on = fm.seq.get(t, p, ss, r).vel > 0;
      g.rect(24 + s * 13, y + 14, 11, 9, ss === cur ? PAL.text : (on ? TCOL[t] : (ss < len ? "#ffffff18" : "#ffffff08")), 2);
    }
  }
}
function drawStep(g) {
  var t = S.track, p = pat(t), len = fm.seq.length(t, p), base = Math.floor(cursor / 16) * 16, cur = fm.seq.step(t);
  title(g, "SEQ > STEP " + (base / 16 + 1) + "/" + Math.max(1, Math.ceil(len / 16)) + (recArmed && !fm.seq.playing() ? " · STEP REC" : ""));
  if (t === DR) {
    for (var l = 0; l < 8; l++) {
      var y = 48 + l * 16;
      g.text(8, y, LANE_NAMES[l].slice(0, 6), { size: 8, weight: l === cursorLane ? "bold" : "regular", color: l === cursorLane ? PAL.acc : PAL.sub });
      for (var s = 0; s < 16; s++) {
        var st = fm.seq.get(t, p, base + s, LANE_HOST[l]), x = 44 + s * 12;
        var c = st.vel ? (fm.seq.laneMute(DR, LANE_HOST[l]) ? PAL.sub : TCOL[t]) : ((base + s) % 4 === 0 ? "#ffffff20" : "#ffffff10");
        g.rect(x, y + 1, 10, 12, c, 2);
        if (base + s === cursor && l === cursorLane) g.frame(x - 1, y, 12, 14, PAL.text, 1.2, 2);
        if (base + s === cur) g.rect(x, y + 13, 10, 2, PAL.text, 1);
      }
    }
    return;
  }
  // piano roll around the notes of the page
  var lo = 127, hi = 0;
  for (var s2 = 0; s2 < 16; s2++) { var st2 = fm.seq.get(t, p, base + s2); for (var n = 0; n < st2.notes.length; n++) { lo = Math.min(lo, st2.notes[n]); hi = Math.max(hi, st2.notes[n]); } }
  if (lo > hi) { lo = lastNote - 6; hi = lastNote + 6; }
  var range = Math.max(12, hi - lo + 2), mid = (lo + hi) / 2, top = Math.round(mid + range / 2), rowH = 132 / range;
  for (var s3 = 0; s3 < 16; s3++) {
    var x2 = 10 + s3 * 14, st3 = fm.seq.get(t, p, base + s3);
    g.rect(x2, 48, 12, 132, (base + s3) >= len ? "#ffffff05" : ((base + s3) % 4 === 0 ? "#ffffff12" : "#ffffff08"), 2);
    for (var m = 0; m < st3.notes.length; m++) {
      var y2 = 48 + (top - st3.notes[m]) * rowH, w = Math.max(6, 14 * st3.len / 4 - 2);
      g.rect(x2, y2, w, Math.max(3, rowH - 1), st3.locks.length ? PAL.acc : TCOL[t], 2);
    }
    if (base + s3 === cursor) g.frame(x2 - 1, 47, 14, 134, base + s3 === heldStep ? PAL.acc : PAL.text, 1.2, 2);
    if (base + s3 === cur) g.rect(x2, 178, 12, 2, PAL.play, 1);
  }
  g.text(232, 34, LIB.noteName(top), { size: 8, align: "right", color: PAL.sub });
}
function drawDetail(g) {
  var t = S.track, p = pat(t), base = Math.floor(cursor / 16) * 16, row = t === DR ? LANE_HOST[cursorLane] : 0;
  title(g, "SEQ > DETAIL · STEP " + (cursor + 1));
  var lanes = [["CHANCE", "chance", 0, 100], ["RATCH", "ratchet", 1, 4], ["NUDGE", "nudge", -8, 7], ["VEL", "vel", 0, 127]];
  for (var l = 0; l < 4; l++) {
    var y = 50 + l * 32;
    g.text(8, y + 8, lanes[l][0], { size: 8, color: PAL.sub });
    for (var s = 0; s < 16; s++) {
      var st = fm.seq.get(t, p, base + s, row), v = st.vel ? (st[lanes[l][1]] - lanes[l][2]) / (lanes[l][3] - lanes[l][2]) : 0;
      var x = 48 + s * 11.5, h = 24 * v;
      g.rect(x, y + 26 - h, 9, Math.max(1, h), base + s === cursor ? PAL.acc : (st.vel ? TCOL[t] : "#ffffff10"), 1.5);
    }
  }
}
function drawAutomation(g) {
  var t = S.track, p = pat(t), rows = [];
  title(g, "SEQ > AUTOMATION · T" + (t + 1));
  var nr = fm.seq.rows(t);
  for (var s = 0; s < 64; s++) for (var r = 0; r < nr; r++) {
    var st = fm.seq.get(t, p, s, r); if (!st.vel) continue;
    if (st.chance < 100) rows.push((s + 1) + "  CHANCE " + st.chance + "%");
    if (st.ratchet > 1) rows.push((s + 1) + "  RATCH x" + st.ratchet);
    if (st.nudge) rows.push((s + 1) + "  NUDGE " + st.nudge + "/16");
    if (st.cond) rows.push((s + 1) + "  " + (["", "FILL", "!FILL"][st.cond] || "COND " + st.cond));
    for (var l = 0; l < st.locks.length; l++) rows.push((s + 1) + "  LOCK " + (inst(t).params()[st.locks[l][0]] || "#" + st.locks[l][0]) + " " + Math.round(st.locks[l][1] / 2.55));
  }
  if (!rows.length) rows.push("no records on this track");
  autoScroll = Math.min(autoScroll, Math.max(0, rows.length - 1));
  for (var i = 0; i < 8 && autoScroll + i < rows.length; i++) g.text(12, 50 + i * 16, rows[autoScroll + i], { size: 10, font: "mono", color: i === 0 ? PAL.text : PAL.sub });
}
function drawSong(g) {
  title(g, "GLO > SONG" + (fm.seq.songOn() ? " · PLAYING" : "") + "   OCT+ on/off");
  for (var t = 0; t < 4; t++) g.text(8, 52 + t * 28, String(t + 1), { size: 11, weight: "bold", color: TCOL[t] });
  var start = Math.max(0, songCursor - 5);
  for (var i = 0; i < 7 && start + i < Math.max(1, song.length); i++) {
    var sec = song[start + i], x = 22 + i * 30;
    if (!sec) { g.text(x, 52, "empty: turn K1", { size: 9, color: PAL.sub }); break; }
    for (var t2 = 0; t2 < 4; t2++) {
      var v = sec.slots[t2];
      g.rect(x, 48 + t2 * 28, 26, 22, v < 0 ? "#ffffff08" : TCOL[t2] + "aa", 3);
      g.text(x + 13, 52 + t2 * 28, v < 0 ? "-" : SLOTS[v], { size: 11, weight: "bold", align: "center", color: v < 0 ? PAL.sub : "#111318" });
    }
    g.text(x + 13, 162, "x" + sec.rep, { size: 8, align: "center", color: PAL.sub });
    if (start + i === songCursor) g.frame(x - 2, 46, 30, 126, PAL.acc, 1.5, 4);
    if (fm.seq.songOn() && fm.seq.songSection() === start + i) g.rect(x, 174, 26, 3, PAL.play, 1);
  }
}
function drawList(g, label) {
  var t = S.track; title(g, label);
  if (t === DR) { for (var i = 0; i < KITS.length; i++) g.text(14, 48 + i * 14, (i === S.kit ? "▶ " : "  ") + KITS[i].name, { size: 11, color: i === S.kit ? PAL.acc : PAL.sub }); return; }
  if (t === 1) { for (var j = -4; j <= 4; j++) { var ix = LIB.wrap(S.sound[1] + j, 128); g.text(14, 104 + j * 14, (j === 0 ? "▶ " : "  ") + "B" + (ix + 1) + " " + fm.presetName(ix), { size: 11, color: j === 0 ? PAL.acc : PAL.sub }); } return; }
  var list = SOUNDS[INST[t]];
  for (var k = 0; k < list.length; k++) g.text(14, 48 + k * 16, (k === S.sound[t] ? "▶ " : "  ") + list[k].name + "  " + list[k].cat, { size: 11, color: k === S.sound[t] ? PAL.acc : PAL.sub });
}
function drawLayer(g, name, lines) {
  g.rect(0, 26, 240, 158, "#0f1115");
  title(g, name + (latched === name ? " · LATCHED" : ""));
  for (var i = 0; i < lines.length; i++) g.text(12, 50 + i * 15, lines[i], { size: 10, color: i ? PAL.sub : PAL.text });
}
function render(g) {
  g.clear(PAL.bg);
  header(g);
  var pg = page();
  if (layer === "SEQ") { var tools = TOOLS.concat(S.track === DR ? DRUM_TOOLS : []); drawLayer(g, "SEQ TOOLS", ["white keys: " + tools.slice(0, 5).join(" · "), tools.slice(5).join(" · "), S.track === DR ? "black keys: lane (" + LANE_NAMES[cursorLane] + ")" : "", "EUCLID next: " + euclidHits + " hits", "OCT−: put the track back", "SAVE held: undo"]); }
  else if (layer === "GLO") drawLayer(g, "GLO LAYER", ["F3–B3 mute T1–4 · black 1–4 solo", "E4 fill (held) · G5 tap tempo", "D4 MIDI learn (n/a here)", "KNOB 1–4: track levels", "mutes: " + [0, 1, 2, 3].map(function (t) { return fm.seq.mute(t) ? "M" : "-"; }).join(" ")]);
  else if (layer === "FX") drawLayer(g, "FX LAYER", ["white: repeat 1/4 1/8 1/16, reverse,", "LP / HP sweep, tape stop, freeze,", "(oct up/down, flanger n/a), phaser,", "rev throw, echo throw, stutter, crush", "black 1–4: track mutes", fxHeld >= 0 ? "▶ " + FX_KEYS[fxHeld][0] : ""]);
  else if (layer === "EDIT") drawLayer(g, "EDIT LAYER", [S.track === DR ? "black keys: mute drum lanes" : "white 1–4: pick track", "engines: T1 ANALOG · T2 FM6 ·", "T3 PHASE · T4 DRUM (fixed here)"]);
  else if (layer === "SEL") drawLayer(g, "SCL LAYER", ["white key: ROOT", "KNOB: QNT · ROOT · SCALE · TRN", "ROOT " + LIB.noteName(60 + S.root).replace(/-?\d+$/, "") + " " + LIB.SCALES[S.scale][0]]);
  else if (layer === "REC") drawLayer(g, "REC LAYER", ["F3 CLEAR track · G3 CLICK (n/a)", "A3 COUNT-IN " + ["OFF", "1 BAR", "2 BARS"][S.countIn], "B3 QUANTIZE " + (S.quantize[S.track] ? "ON" : "OFF")]);
  else switch (button + ":" + pg) {
    case "HOME:HOME": drawHome(g); break;
    case "HOME:MIXER": drawTracks(g, "HOME > MIXER"); break;
    case "HOME:CLOCK": title(g, "HOME > CLOCK"); g.text(120, 70, Math.round(fm.seq.tempo()) + " BPM", { size: 30, weight: "bold", align: "center", color: PAL.text }); g.text(120, 112, "SWING " + Math.round(fm.seq.swing()) + "% · INT", { size: 12, align: "center", color: PAL.sub }); break;
    case "SEQ:STEP": drawStep(g); break;
    case "SEQ:DETAIL": drawDetail(g); break;
    case "SEQ:AUTOMATION": drawAutomation(g); break;
    case "GLO:SONG": drawSong(g); break;
    case "SAVE:PRESETS": drawList(g, "SAVE > PRESETS"); break;
    case "SAVE:PROJECT": title(g, "SAVE > PROJECT · OCT+ load"); for (var i = 0; i < 4; i++) { var x = 14 + i * 56; g.rect(x, 60, 48, 60, i === projCursor ? PAL.acc : PAL.card, 6); g.text(x + 24, 72, SLOTS[i], { size: 26, weight: "bold", align: "center", color: i === projCursor ? "#111318" : PAL.text }); if (i === S.slot) g.text(x + 24, 126, "LOADED", { size: 8, align: "center", color: PAL.play }); } break;
    case "ARP:ARP": case "ARP:ARP 2": drawArp(g, pg); break;
    default: title(g, button + " > " + pg); g.scope(10, 60, 220, 100, TCOL[S.track] + "88", 1.2);
  }
  cards(g, knobs());
  if (countUntil > 0) { g.rect(70, 90, 100, 40, "#000000cc", 8); g.text(120, 100, "COUNT-IN", { size: 13, weight: "bold", align: "center", color: PAL.rec }); }
  if (flash && fm.now() < flashUntil) { g.rect(16, 92, 208, 32, "#000000e6", 8); g.text(120, 100, flash, { size: 12, weight: "bold", align: "center", color: PAL.acc }); }
  leds();
}
function drawArp(g, pg) {
  title(g, pg + " · T" + (S.track + 1));
  if (S.track === DR) { g.text(120, 90, "no arpeggiator on the drum track", { size: 12, align: "center", color: PAL.sub }); return; }
  var lines = LIB.arpLines(inst(S.track)), s = inst(S.track).arp();
  for (var i = 0; i < lines.length; i++) g.text(14, 48 + i * 16, lines[i], { size: i ? 10 : 13, weight: i ? "regular" : "bold", color: i ? PAL.sub : PAL.text });
  // beat LED on screen too: one cell per step of the bar
  for (var c = 0; c < 8; c++) g.rect(14 + c * 27, 112, 22, 10, s.on && s.step > 0 && (s.step - 1) % 8 === c ? TCOL[S.track] : PAL.card, 3);
}
function arpBeat() {
  if (S.track === DR) return false;
  var s = inst(S.track).arp();
  if (!s.on || s.step === 0) return false;
  if (s.step !== arpLastStep) { arpLastStep = s.step; arpFlashUntil = fm.now() + 110; }
  return fm.now() < arpFlashUntil;
}
var arpLastStep = 0, arpFlashUntil = 0;
function leds() {
  var t = S.track, p = pat(t), cur = fm.seq.step(t);
  for (var i = 0; i < 16; i++) {
    var k = fm.keyOfWhite(i), c = null;
    if (isStepPage()) {
      var s = Math.floor(cursor / 16) * 16 + i, st = fm.seq.get(t, p, s, t === DR ? LANE_HOST[cursorLane] : 0);
      c = st.vel ? TCOL[t] : (i % 4 === 0 && t === DR ? "#ffffff28" : null);
      if (s === cur) c = PAL.text;
    } else if (layer && (fm.now() % 1600) < 800 && i < (layer === "SEQ" ? TOOLS.length + (t === DR ? DRUM_TOOLS.length : 0) : 4)) c = "#ffffff30"; // what can be pressed breathes
    fm.led.key(k, c);
  }
  var beat = fm.seq.beat();
  fm.led.button("PLAY", fm.seq.playing() ? "green" : "off");
  fm.led.button("REC", recording ? "red" : (recArmed && fm.now() % 600 < 300 ? "red" : "off"));
  for (var b in PAGES) if (PAGES.hasOwnProperty(b)) fm.led.button(b, button === b ? "on" : "off");
  if (layer) fm.led.button(layer, latched === layer ? "blue" : "on");
  if (button !== "ARP" && !layer) fm.led.button("ARP", arpBeat() ? "on" : "off");   // beat LED while an arp runs
}
function onShutdown() { saveUI(); fm.store.set("song", song); if (fxHeld >= 0) endFx(); }

// Incoming MIDI: notes play the selected track (GM drum map on the drum track) and record while REC runs.
function onMidi(kind, n, v, ch) {
  if (kind !== "on" && kind !== "off") return;
  var t = S.track;
  LIB.midiNote(t, inst(t), t === DR, kind, n, v, recording && fm.seq.playing());
}
