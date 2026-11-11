// lib.js — small helpers shared by the FM Pocket ports (each package carries its own copy).
// Plain ES5 so it runs on any JavaScriptCore.

var LIB = (function () {
  var NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
  function noteName(n) { return NOTE[((n % 12) + 12) % 12] + (Math.floor(n / 12) - 1); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function wrap(v, n) { return ((v % n) + n) % n; }
  function pct(v) { return Math.round(v * 100) + "%"; }

  // Buttons: held state, hold time, "used while held" (a layer was used), double-tap latch.
  function Buttons() { this.down = {}; this.t0 = {}; this.used = {}; this.lastTap = {}; this.latched = null; }
  Buttons.prototype.press = function (name) { this.down[name] = true; this.t0[name] = fm.now(); this.used[name] = false; };
  // returns "tap", "double" or "hold"
  Buttons.prototype.release = function (name) {
    var held = fm.now() - (this.t0[name] || 0);
    var was = this.down[name]; this.down[name] = false;
    if (!was) return "none";
    if (this.used[name] || held > 450) return "hold";
    var last = this.lastTap[name] || 0;
    this.lastTap[name] = fm.now();
    return fm.now() - last < 350 ? "double" : "tap";
  };
  Buttons.prototype.heldFor = function (name) { return this.down[name] ? fm.now() - this.t0[name] : 0; };
  Buttons.prototype.isDown = function (name) { return !!this.down[name]; };
  Buttons.prototype.use = function (name) { this.used[name] = true; };

  // Undo: snapshots of one track/pattern (all rows and steps).
  function snapshot(t, p) {
    var rows = fm.seq.rows(t), out = { t: t, p: p, len: fm.seq.length(t, p), div: fm.seq.div(t, p), rows: [] };
    for (var r = 0; r < rows; r++) {
      var row = [];
      for (var s = 0; s < 64; s++) row.push(fm.seq.get(t, p, s, r));
      out.rows.push(row);
    }
    return out;
  }
  function restore(snap) {
    for (var r = 0; r < snap.rows.length; r++)
      for (var s = 0; s < 64; s++) {
        var st = snap.rows[r][s];
        if (st.vel === 0) fm.seq.clear(snap.t, snap.p, s, r); else fm.seq.set(snap.t, snap.p, s, st, r);
      }
    fm.seq.length(snap.t, snap.p, snap.len);
    fm.seq.div(snap.t, snap.p, snap.div);
  }
  function Undo(depth) { this.stack = []; this.redo = []; this.depth = depth || 8; }
  Undo.prototype.push = function (t, p) { this.stack.push(snapshot(t, p)); if (this.stack.length > this.depth) this.stack.shift(); this.redo = []; };
  Undo.prototype.undo = function () { var s = this.stack.pop(); if (!s) return false; this.redo.push(snapshot(s.t, s.p)); restore(s); return true; };
  Undo.prototype.redoOne = function () { var s = this.redo.pop(); if (!s) return false; this.stack.push(snapshot(s.t, s.p)); restore(s); return true; };

  // Pattern tools
  function euclid(hits, steps, rot) {
    var out = [];
    for (var j = 0; j < steps; j++) out.push(false);
    for (var k = 0; k < steps; k++) out[wrap(k + rot, steps)] = hits > 0 && ((k * hits) % steps) < hits;
    return out;
  }
  function shift(t, p, dir) {
    var len = fm.seq.length(t, p), rows = fm.seq.rows(t);
    for (var r = 0; r < rows; r++) {
      var a = [];
      for (var s = 0; s < len; s++) a.push(fm.seq.get(t, p, s, r));
      for (var s2 = 0; s2 < len; s2++) {
        var src = a[wrap(s2 - dir, len)];
        if (src.vel === 0) fm.seq.clear(t, p, s2, r); else fm.seq.set(t, p, s2, src, r);
      }
    }
  }
  function reverse(t, p) {
    var len = fm.seq.length(t, p), rows = fm.seq.rows(t);
    for (var r = 0; r < rows; r++) {
      var a = [];
      for (var s = 0; s < len; s++) a.push(fm.seq.get(t, p, s, r));
      for (var s2 = 0; s2 < len; s2++) {
        var src = a[len - 1 - s2];
        if (src.vel === 0) fm.seq.clear(t, p, s2, r); else fm.seq.set(t, p, s2, src, r);
      }
    }
  }
  function double(t, p) {
    var len = fm.seq.length(t, p), rows = fm.seq.rows(t);
    if (len > 32) return;
    for (var r = 0; r < rows; r++)
      for (var s = 0; s < len; s++) {
        var st = fm.seq.get(t, p, s, r);
        if (st.vel === 0) fm.seq.clear(t, p, s + len, r); else fm.seq.set(t, p, s + len, st, r);
      }
    fm.seq.length(t, p, len * 2);
  }

  // Scales (semitone sets)
  var SCALES = [
    ["CHR", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]], ["MAJ", [0, 2, 4, 5, 7, 9, 11]], ["MIN", [0, 2, 3, 5, 7, 8, 10]],
    ["DOR", [0, 2, 3, 5, 7, 9, 10]], ["MIX", [0, 2, 4, 5, 7, 9, 10]], ["PEN", [0, 2, 4, 7, 9]], ["MPEN", [0, 3, 5, 7, 10]],
    ["HARM", [0, 2, 3, 5, 7, 8, 11]], ["PHRY", [0, 1, 3, 5, 7, 8, 10]], ["LYD", [0, 2, 4, 6, 7, 9, 11]],
    ["LOC", [0, 1, 3, 5, 6, 8, 10]], ["MEL", [0, 2, 3, 5, 7, 9, 11]], ["BLUES", [0, 3, 5, 6, 7, 10]],
    ["WHOLE", [0, 2, 4, 6, 8, 10]], ["DIMHW", [0, 1, 3, 4, 6, 7, 9, 10]], ["DIMWH", [0, 2, 3, 5, 6, 8, 9, 11]]
  ];
  // the n-th degree (can be negative) of a scale above root (MIDI)
  function degree(root, scale, n) {
    var s = SCALES[scale][1], o = Math.floor(n / s.length);
    return root + o * 12 + s[wrap(n, s.length)];
  }
  function snap(note, root, scale) {
    var s = SCALES[scale][1], rel = wrap(note - root, 12), best = s[0];
    for (var i = 0; i < s.length; i++) if (s[i] <= rel) best = s[i];
    return note - rel + best;
  }

  // Chords: one-key chord shapes (scale triads/sevenths are built from degrees)
  var CHORDS = ["OFF", "TRIAD", "7TH", "9TH", "SUS4", "POWER"];
  function chordNotes(note, kind, root, scale) {
    if (kind === 0) return [note];
    if (kind === 5) return [note, note + 7, note + 12];
    if (kind === 4) return [note, note + 5, note + 7];
    // diatonic stacks of thirds from the note's scale degree
    var s = SCALES[scale][1], n0 = snap(note, root, scale), rel = wrap(n0 - root, 12), d = 0;
    for (var i = 0; i < s.length; i++) if (s[i] === rel) d = i;
    var D = Math.floor((n0 - root) / 12) * s.length + d;
    var count = kind === 1 ? 3 : (kind === 2 ? 4 : 5), out = [];
    for (var k = 0; k < count; k++) out.push(degree(root, scale, D + 2 * k));
    return out;
  }

  // Arpeggiator pages (host block PkgArp via inst.arp): knob cards {label,text,frac,turn} and summary lines.
  // MODE's first value is OFF; the rest are fm.arpModes.
  function arpKnobs(i, page2) {
    function K(l, t, f, u) { return { label: l, text: t, frac: f, turn: u }; }
    function a() { return i.arp(); }
    var M = fm.arpModes, R = fm.arpRates;
    if (page2) return [K("LATCH", function () { return a().latch ? "ON" : "OFF"; }, function () { return a().latch ? 1 : 0; }, function (d) { i.arp({ latch: d > 0 }); }), null, null, null];
    return [
      K("MODE", function () { var s = a(); return s.on ? s.modeName : "OFF"; }, function () { var s = a(); return s.on ? (s.mode + 1) / M.length : 0; },
        function (d) { var s = a(), v = clamp((s.on ? s.mode + 1 : 0) + d, 0, M.length); i.arp(v === 0 ? { on: false } : { on: true, mode: v - 1 }); }),
      K("RATE", function () { return a().rateName; }, function () { return a().rate / (R.length - 1); }, function (d) { i.arp({ rate: clamp(a().rate + d, 0, R.length - 1) }); }),
      K("OCT", function () { return String(a().octaves); }, function () { return (a().octaves - 1) / 3; }, function (d) { i.arp({ octaves: clamp(a().octaves + d, 1, 4) }); }),
      K("GATE", function () { return Math.round(a().gate * 100) + "%"; }, function () { return a().gate; }, function (d) { i.arp({ gate: clamp(a().gate + d * 0.05, 0.05, 1) }); })
    ];
  }
  function arpLines(i) {
    var s = i.arp();
    return [s.on ? "ARP " + s.modeName + " · " + s.rateName + " · " + s.octaves + " OCT" : "ARP OFF",
      "GATE " + Math.round(s.gate * 100) + "% · LATCH " + (s.latch ? "ON" : "OFF"),
      "hold keys to arpeggiate; follows PLAY's beat"];
  }

  // General MIDI drum note -> host drum lane (BD SD LT MT HT RM CP CB CY OH CH), or -1.
  var GM_LANES = { 35: 0, 36: 0, 37: 5, 38: 1, 40: 1, 39: 6, 41: 2, 43: 2, 45: 3, 47: 3, 48: 4, 50: 4,
    42: 10, 44: 10, 46: 9, 49: 8, 51: 8, 52: 8, 55: 8, 57: 8, 59: 8, 56: 7, 54: 7, 75: 5, 76: 5 };
  function gmLane(n) { return GM_LANES.hasOwnProperty(n) ? GM_LANES[n] : -1; }
  // Plays an incoming MIDI note on track t (instrument i) and records it while `rec`.
  // Returns the drum lane or note played, or -1.
  function midiNote(t, i, isDrum, kind, n, v, rec) {
    if (isDrum) {
      var lane = gmLane(n);
      if (lane < 0 || kind !== "on") return -1;
      i.hit(lane, v);
      if (rec) fm.seq.recordHit(t, lane, v);
      return lane;
    }
    if (kind === "on") { i.note(n, v); if (rec && n > 0) fm.seq.record(t, n, v); } else i.off(n);   // step note 0 means "empty"
    return n;
  }

  // Drawing helpers
  function knob(g, x, y, r, frac, col, bg) {
    g.arc(x, y, r, -135, 135, bg || "#ffffff30", 4);
    if (frac > 0.001) g.arc(x, y, r, -135, -135 + 270 * clamp(frac, 0, 1), col, 4);
  }
  function hexA(c, a) { return c.length === 7 ? c + a : c; }

  return {
    noteName: noteName, clamp: clamp, wrap: wrap, pct: pct, Buttons: Buttons, Undo: Undo,
    snapshot: snapshot, restore: restore, euclid: euclid, shift: shift, reverse: reverse, double: double,
    SCALES: SCALES, degree: degree, snap: snap, CHORDS: CHORDS, chordNotes: chordNotes, knob: knob, hexA: hexA, arpKnobs: arpKnobs, arpLines: arpLines, gmLane: gmLane, midiNote: midiNote
  };
})();
