/// JavaScript that runs before a package's scripts: the `fm` API and the drawing object
/// `g`, built on the native `__host` bridge (PackageHost.swift). Documented in
/// Firmwares/README.md — keep both in step.
enum ScriptPrelude {
    static let source = #"""
var __cmds = [];
var __keys = [];
var __buttons = {};
var g = {
  W: 240, H: 240,
  clear: function (c) { __cmds.push(["clear", c || "#000000"]); },
  rect: function (x, y, w, h, c, r) { __cmds.push(["rect", x, y, w, h, c, r || 0]); },
  frame: function (x, y, w, h, c, lw, r) { __cmds.push(["frame", x, y, w, h, c, lw || 1, r || 0]); },
  line: function (x1, y1, x2, y2, c, lw) { __cmds.push(["line", x1, y1, x2, y2, c, lw || 1]); },
  circle: function (x, y, r, c) { __cmds.push(["circle", x, y, r, c]); },
  ring: function (x, y, r, c, lw) { __cmds.push(["ring", x, y, r, c, lw || 1]); },
  arc: function (x, y, r, a0, a1, c, lw) { __cmds.push(["arc", x, y, r, a0, a1, c, lw || 2]); },
  text: function (x, y, s, o) {
    o = o || {};
    __cmds.push(["text", x, y, String(s), o.size || 12, o.color || "#ffffff", o.align || "left", o.weight || "regular", o.font || "sans"]);
  },
  scope: function (x, y, w, h, c, lw) { __cmds.push(["scope", x, y, w, h, c, lw || 1.5]); }
};

var fm = (function () {
  var WHITE = [0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18, 19, 21, 23, 24, 26];
  var BLACK = [1, 3, 5, 8, 10, 13, 15, 17, 20, 22, 25];
  var instCache = {};
  function Inst(id) {
    this.id = id;
    this.index = __host.instIndex(id);
    if (this.index < 0) throw new Error("unknown instrument " + id);
  }
  // the sounding engine's type (a slot changes it with engine())
  Object.defineProperty(Inst.prototype, "type", { get: function () { return __host.instType(this.index); } });
  Inst.prototype.engine = function (name) { return __host.instEngine(this.index, name === undefined ? "" : String(name)); };
  Inst.prototype.engines = function () { return __host.instEngines(this.index); };
  Inst.prototype.sets = function () { return __host.instSets(this.index); };
  Inst.prototype.note = function (n, v) { __host.noteOn(this.index, n, v === undefined ? 100 : v); };
  Inst.prototype.off = function (n) { __host.noteOff(this.index, n); };
  Inst.prototype.hit = function (lane, v) { __host.hit(this.index, lane, v === undefined ? 100 : v); };
  Inst.prototype.set = function (p, v) { __host.setParam(this.index, p, v); };
  Inst.prototype.get = function (p) { return __host.getParam(this.index, p); };
  Inst.prototype.setAll = function (o) { for (var k in o) if (o.hasOwnProperty(k)) __host.setParam(this.index, k, o[k]); };
  Inst.prototype.params = function () { return __host.paramNames(this.index); };
  Inst.prototype.paramIndex = function (name) { return __host.paramIndex(this.index, name); };
  Inst.prototype.level = function (v) { return __host.instLevel(this.index, v === undefined ? -1 : v); };
  Inst.prototype.mute = function (b) { __host.instMute(this.index, !!b); };
  Inst.prototype.meter = function () { return __host.meter(this.index); };
  Inst.prototype.arp = function (o) { return __host.arp(this.index, o || {}); };
  Inst.prototype.allOff = function () { __host.allOff(this.index); };
  Inst.prototype.preset = function (i) { return __host.fmPreset(this.index, i); };

  var tracks = __host.trackIDs();
  function T(t) { if (typeof t === "number") return t; var i = tracks.indexOf(t); if (i < 0) throw new Error("unknown track " + t); return i; }

  var seq = {
    tracks: tracks,
    patterns: __host.patternCount(),
    rows: function (t) { return __host.trackRows(T(t)); },
    get: function (t, p, s, row) { return __host.seqGet(T(t), p, row || 0, s); },
    set: function (t, p, s, o, row) { __host.seqSet(T(t), p, row || 0, s, o); },
    clear: function (t, p, s, row) { __host.seqClear(T(t), p, row === undefined ? -1 : row, s === undefined ? -1 : s); },
    copy: function (t, from, to) { __host.seqCopy(T(t), from, to); },
    has: function (t, p) { return __host.seqHas(T(t), p); },
    length: function (t, p, n) { return __host.seqLength(T(t), p, n === undefined ? -1 : n); },
    div: function (t, p, d) { return __host.seqDiv(T(t), p, d === undefined ? -1 : d); },
    divNames: __host.divNames(),
    play: function () { __host.transport("play"); },
    stop: function () { __host.transport("stop"); },
    playing: function () { return __host.transport("state"); },
    tempo: function (v) { return __host.tempo(v === undefined ? -1 : v); },
    swing: function (v) { return __host.swing(v === undefined ? -1 : v); },
    fill: function (b) { return __host.fill(b === undefined ? -1 : (b ? 1 : 0)); },
    mute: function (t, b) { return __host.trackMute(T(t), b === undefined ? -1 : (b ? 1 : 0)); },
    laneMute: function (t, lane, b) { return __host.laneMute(T(t), lane, b === undefined ? -1 : (b ? 1 : 0)); },
    select: function (t, p) { return __host.select(T(t), p === undefined ? -1 : p); },
    pattern: function (t) { return __host.playingPattern(T(t)); },
    step: function (t) { return __host.stepNow(T(t)); },
    loop: function (t) { return __host.loopCount(T(t)); },
    beat: function () { return __host.beatPos(); },
    record: function (t, note, vel) { return __host.record(T(t), note, vel === undefined ? 100 : vel, -1); },
    recordHit: function (t, lane, vel) { return __host.record(T(t), -1, vel === undefined ? 100 : vel, lane); },
    song: function (sections, loop) { __host.song(sections || [], loop === undefined ? true : !!loop); },
    songOn: function (b) { return __host.songOn(b === undefined ? -1 : (b ? 1 : 0)); },
    songSection: function () { return __host.songSection(); }
  };

  return {
    KEYS: 27, WHITE: WHITE, BLACK: BLACK,
    isWhite: function (k) { return WHITE.indexOf(k) >= 0; },
    whiteIndex: function (k) { return WHITE.indexOf(k); },
    blackIndex: function (k) { return BLACK.indexOf(k); },
    keyOfWhite: function (i) { return WHITE[i]; },
    keyOfBlack: function (i) { return BLACK[i]; },
    inst: function (id) { return instCache[id] || (instCache[id] = new Inst(id)); },
    seq: seq,
    master: function (o) { __host.master(o || {}); },
    punch: function (name, beats) { __host.punch(name || "OFF", beats || 0.25); },
    fx: function (kind, on, a, b, c) { __host.fx(kind, !!on, a === undefined ? -1 : a, b === undefined ? -1 : b, c === undefined ? -1 : c); },
    presetName: function (i) { return __host.fmPresetName(i); },
    arpModes: __host.arpModes(),
    arpRates: __host.arpRates(),
    octave: function () { return __host.octave(); },
    velocity: function () { return __host.velocity(); },
    now: function () { return __host.now(); },
    log: function () { __host.log(Array.prototype.slice.call(arguments).join(" ")); },
    store: {
      get: function (k, d) { var v = __host.storeGet(k); return v === undefined || v === null ? d : JSON.parse(v); },
      set: function (k, v) { __host.storeSet(k, JSON.stringify(v)); }
    },
    led: {
      key: function (k, c) { __keys[k] = c || null; },
      button: function (name, state) { __buttons[name] = state; }
    }
  };
})();

function __event(type, a, b, c) {
  switch (type) {
    case "boot": if (typeof onBoot === "function") onBoot(); break;
    case "button": if (typeof onButton === "function") onButton(a, b); break;
    case "key": if (typeof onKey === "function") onKey(a, b, c); break;
    case "knob": if (typeof onKnob === "function") onKnob(a, b); break;
    case "encoder": if (typeof onEncoder === "function") onEncoder(a, b); break;
    case "tick": if (typeof onTick === "function") onTick(a); break;
    case "midi":
      if (typeof onMidi === "function") {
        var kind = a & 0xF0, ch = (a & 15) + 1;
        if (kind === 0x90 && c > 0) onMidi("on", b, c, ch);
        else if (kind === 0x80 || kind === 0x90) onMidi("off", b, 0, ch);
        else if (kind === 0xB0) onMidi("cc", b, c, ch);
        else if (kind === 0xC0) onMidi("program", b, 0, ch);
      }
      break;
    case "shutdown": if (typeof onShutdown === "function") onShutdown(); break;
  }
}
function __frame() {
  __cmds = []; __keys = []; __buttons = {};
  for (var i = 0; i < 27; i++) __keys.push(null);
  if (typeof render === "function") render(g);
  return { cmds: __cmds, keys: __keys, buttons: __buttons };
}
"""#
}
