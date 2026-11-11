/* FM-1 tutorial: theme toggle, nav, and diagram/mock-up renderers. No dependencies. */
(function () {
  'use strict';
  var NS = 'http://www.w3.org/2000/svg';
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  /* ---------- theme + nav ---------- */
  function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) {} return null; }
  var saved = store('fm1-theme');
  if (saved === 'light' || saved === 'dark') document.documentElement.setAttribute('data-theme', saved);
  function initChrome() {
    var tb = $('#theme-btn');
    if (tb) tb.addEventListener('click', function () {
      var cur = document.documentElement.getAttribute('data-theme');
      if (!cur) cur = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      var next = cur === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next); store('fm1-theme', next);
    });
    var mb = $('#menu-btn'), nav = $('#main-nav');
    if (mb && nav) mb.addEventListener('click', function () {
      var o = nav.classList.toggle('open'); mb.setAttribute('aria-expanded', o ? 'true' : 'false');
    });
  }

  /* ---------- the 32 algorithms (edges are [modulator, target]) ---------- */
  /* Same routing table as the app's Algorithms.swift, which was checked against M-VAVE's fm1_open dx7core.c. */
  var A = [
    [[[2,1],[4,3],[5,4],[6,5]],[1,3],6,6],[[[2,1],[4,3],[5,4],[6,5]],[1,3],2,2],
    [[[2,1],[3,2],[5,4],[6,5]],[1,4],6,6],[[[2,1],[3,2],[5,4],[6,5]],[1,4],6,4],
    [[[2,1],[4,3],[6,5]],[1,3,5],6,6],[[[2,1],[4,3],[6,5]],[1,3,5],6,5],
    [[[2,1],[4,3],[5,3],[6,5]],[1,3],6,6],[[[2,1],[4,3],[5,3],[6,5]],[1,3],4,4],
    [[[2,1],[4,3],[5,3],[6,5]],[1,3],2,2],[[[2,1],[3,2],[5,4],[6,4]],[1,4],3,3],
    [[[2,1],[3,2],[5,4],[6,4]],[1,4],6,6],[[[2,1],[4,3],[5,3],[6,3]],[1,3],2,2],
    [[[2,1],[4,3],[5,3],[6,3]],[1,3],6,6],[[[2,1],[4,3],[5,4],[6,4]],[1,3],6,6],
    [[[2,1],[4,3],[5,4],[6,4]],[1,3],2,2],[[[2,1],[3,1],[4,3],[5,1],[6,5]],[1],6,6],
    [[[2,1],[3,1],[4,3],[5,1],[6,5]],[1],2,2],[[[2,1],[3,1],[4,1],[5,4],[6,5]],[1],3,3],
    [[[2,1],[3,2],[6,4],[6,5]],[1,4,5],6,6],[[[3,1],[3,2],[5,4],[6,4]],[1,2,4],3,3],
    [[[3,1],[3,2],[6,4],[6,5]],[1,2,4,5],3,3],[[[2,1],[6,3],[6,4],[6,5]],[1,3,4,5],6,6],
    [[[3,2],[6,4],[6,5]],[1,2,4,5],6,6],[[[6,3],[6,4],[6,5]],[1,2,3,4,5],6,6],
    [[[6,4],[6,5]],[1,2,3,4,5],6,6],[[[3,2],[5,4],[6,4]],[1,2,4],6,6],
    [[[3,2],[5,4],[6,4]],[1,2,4],3,3],[[[2,1],[4,3],[5,4]],[1,3,6],5,5],
    [[[4,3],[6,5]],[1,2,3,5],6,6],[[[4,3],[5,4]],[1,2,3,6],5,5],
    [[[6,5]],[1,2,3,4,5],6,6],[[],[1,2,3,4,5,6],6,6]
  ];
  function algoLayout(n) {
    var d = A[n - 1], edges = d[0], car = d[1];
    var depth = {}, op;
    for (op = 1; op <= 6; op++) depth[op] = car.indexOf(op) >= 0 ? 0 : -1;
    var changed = true;
    while (changed) {
      changed = false;
      edges.forEach(function (e) {
        if (depth[e[1]] >= 0 && depth[e[0]] < depth[e[1]] + 1) { depth[e[0]] = depth[e[1]] + 1; changed = true; }
      });
    }
    for (op = 1; op <= 6; op++) if (depth[op] < 0) depth[op] = 0;
    var rows = 0; for (op = 1; op <= 6; op++) rows = Math.max(rows, depth[op]);
    var byRow = []; for (var r = 0; r <= rows; r++) byRow.push([]);
    for (op = 1; op <= 6; op++) byRow[depth[op]].push(op);
    var W = 6, x = {};
    byRow[0].sort(function (a, b) { return a - b; });
    byRow[0].forEach(function (o, i) { x[o] = (i + 0.5) * W / byRow[0].length; });
    for (r = 1; r <= rows; r++) {
      var list = byRow[r];
      list.forEach(function (o) {
        var t = edges.filter(function (e) { return e[0] === o; }).map(function (e) { return x[e[1]]; });
        x[o] = t.reduce(function (a, b) { return a + b; }, 0) / t.length;
      });
      list.sort(function (a, b) { return x[a] - x[b] || a - b; });
      for (var i = 1; i < list.length; i++) if (x[list[i]] - x[list[i - 1]] < 0.95) x[list[i]] = x[list[i - 1]] + 0.95;
      var mid = (x[list[0]] + x[list[list.length - 1]]) / 2, shift = 0;
      var want = list.map(function (o) { return edges.filter(function (e) { return e[0] === o; }).map(function (e) { return x[e[1]]; }); });
      if (list.length > 1) { /* keep the group centred on its targets */
        var tm = want.reduce(function (a, w) { return a.concat(w); }, []);
        shift = tm.reduce(function (a, b) { return a + b; }, 0) / tm.length - mid;
        list.forEach(function (o) { x[o] += shift; });
      }
    }
    var mn = 1e9, mx = -1e9; for (op = 1; op <= 6; op++) { mn = Math.min(mn, x[op]); mx = Math.max(mx, x[op]); }
    mn = Math.min(mn, 0.5); mx = Math.max(mx, W - 0.5);
    for (op = 1; op <= 6; op++) x[op] -= mn - 0.5;
    W = mx - mn + 1;
    return { depth: depth, rows: rows, x: x, W: W, edges: edges, car: car, fb: d[2], fbFrom: d[3] };
  }
  function algoSVG(n, opts) {
    opts = opts || {};
    var L = algoLayout(n), cw = 66, bw = 30, rowH = 52, top = 14;
    var w = L.W * cw + 20, h = top + (L.rows + 1) * rowH + 40;
    var px = function (o) { return 10 + L.x[o] * cw; };
    var py = function (o) { return top + (L.rows - L.depth[o]) * rowH + bw / 2; };
    var s = '<svg class="algo-svg diag" viewBox="0 0 ' + w + ' ' + h + '" role="img" aria-label="Algorithm ' + n + ' diagram">';
    L.edges.forEach(function (e) {
      s += '<line x1="' + px(e[0]) + '" y1="' + (py(e[0]) + bw / 2) + '" x2="' + px(e[1]) + '" y2="' + (py(e[1]) - bw / 2) + '"/>';
    });
    var outY = top + (L.rows + 1) * rowH + 4;
    var minx = 1e9, maxx = -1e9;
    L.car.forEach(function (o) {
      s += '<line x1="' + px(o) + '" y1="' + (py(o) + bw / 2) + '" x2="' + px(o) + '" y2="' + outY + '"/>';
      minx = Math.min(minx, px(o)); maxx = Math.max(maxx, px(o));
    });
    s += '<rect class="out" x="' + (minx - 22) + '" y="' + outY + '" width="' + (maxx - minx + 44) + '" height="16" rx="6"/><text class="outt" x="' + ((minx + maxx) / 2) + '" y="' + (outY + 8) + '">OUT</text>';
    for (var o = 1; o <= 6; o++) {
      var car = L.car.indexOf(o) >= 0;
      s += '<rect class="' + (car ? 'car' : 'op') + '" x="' + (px(o) - bw / 2) + '" y="' + (py(o) - bw / 2) + '" width="' + bw + '" height="' + bw + '" rx="5"/><text x="' + px(o) + '" y="' + py(o) + '">' + o + '</text>';
    }
    /* feedback */
    var fx = px(L.fb) + bw / 2, fy = py(L.fb);
    if (L.fbFrom === L.fb) {
      var bx0 = px(L.fb) + bw / 2, by0 = py(L.fb);
      s += '<path class="fb" d="M' + bx0 + ' ' + (by0 - 7) + ' h 9 v 14 h -9"/><path class="fb" d="M' + (bx0 + 1) + ' ' + (by0 + 7) + ' l 6 -4 v 8z" style="fill:#d75f51"/>';
    } else {
      var sx = px(L.fbFrom) + bw / 2, sy = py(L.fbFrom), ex = px(L.fb) + bw / 2, ey = py(L.fb);
      var bx = Math.max(sx, ex) + 14;
      s += '<path class="fb" d="M' + sx + ' ' + sy + ' H ' + bx + ' V ' + ey + ' H ' + (ex + 4) + '"/><path class="fb" d="M' + ex + ' ' + ey + ' l 7 -4 v 8z" style="fill:#d75f51"/>';
    }
    return s + '</svg>';
  }

  /* ---------- envelope shapes ---------- */
  function envSVG(r, l, o) {
    o = o || {}; var W = 420, H = 190, ml = 34, mr = 14, mt = 14, mb = 34;
    var t = r.map(function (x) { return 18 + (99 - x) * 1.1; });
    var y = function (v) { return mt + (H - mt - mb) * (1 - v / 99); };
    var xs = [ml], i; var acc = ml;
    var pts = [[ml, y(l[3])]];
    for (i = 0; i < 3; i++) { acc += t[i]; pts.push([acc, y(l[i])]); }
    var holdX = acc + 40, relX = holdX + t[3];
    var sc = (W - ml - mr) / relX;
    var P = pts.map(function (p) { return [ml + (p[0] - ml) * sc, p[1]]; });
    var hx = ml + (holdX - ml) * sc, rx = W - mr;
    var d = 'M' + P.map(function (p) { return p[0].toFixed(1) + ' ' + p[1].toFixed(1); }).join(' L') + ' L' + hx.toFixed(1) + ' ' + P[3][1].toFixed(1) + ' L' + rx + ' ' + y(l[3]).toFixed(1);
    var s = '<svg class="diag envd" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' + esc(o.label || 'Envelope shape') + '">';
    s += '<line class="axis" x1="' + ml + '" y1="' + mt + '" x2="' + ml + '" y2="' + (H - mb) + '"/><line class="axis" x1="' + ml + '" y1="' + (H - mb) + '" x2="' + (W - mr) + '" y2="' + (H - mb) + '"/>';
    s += '<line class="grid" x1="' + hx.toFixed(1) + '" y1="' + mt + '" x2="' + hx.toFixed(1) + '" y2="' + (H - mb) + '"/>';
    s += '<text x="' + (hx + 4) + '" y="' + (mt + 10) + '">key released</text><text x="' + (ml + 4) + '" y="' + (H - 10) + '">key pressed → time →</text>';
    s += '<path class="area" d="' + d + ' L' + rx + ' ' + (H - mb) + ' L' + ml + ' ' + (H - mb) + 'z"/><path class="curve" d="' + d + '"/>';
    var names = ['L1', 'L2', 'L3'];
    for (i = 1; i <= 3; i++) s += '<circle class="pt" cx="' + P[i][0].toFixed(1) + '" cy="' + P[i][1].toFixed(1) + '" r="4"/><text x="' + (P[i][0] - 6).toFixed(1) + '" y="' + (P[i][1] - 8).toFixed(1) + '">' + names[i - 1] + '</text>';
    s += '<circle class="pt" cx="' + rx + '" cy="' + y(l[3]).toFixed(1) + '" r="4"/><text x="' + (rx - 20) + '" y="' + (y(l[3]) - 8).toFixed(1) + '">L4</text>';
    var mids = [(P[0][0] + P[1][0]) / 2, (P[1][0] + P[2][0]) / 2, (P[2][0] + P[3][0]) / 2, (hx + rx) / 2];
    ['R1', 'R2', 'R3', 'R4'].forEach(function (n, k) { s += '<text x="' + (mids[k] - 8).toFixed(1) + '" y="' + (H - mb + 16) + '" style="font-weight:700">' + n + '</text>'; });
    return s + '</svg>';
  }
  function adsrSVG(a, d, sPct, r) {
    var W = 420, H = 170, ml = 30, mt = 16, mb = 32, bh = H - mt - mb;
    var ta = 20 + a * 1.6, td = 20 + d * 1.4, tr = 20 + r * 1.6, hold = 50;
    var tot = ta + td + hold + tr, sc = (W - ml - 14) / tot;
    var x0 = ml, x1 = x0 + ta * sc, x2 = x1 + td * sc, x3 = x2 + hold * sc, x4 = x3 + tr * sc;
    var yb = H - mb, yt = mt, ys = mt + bh * (1 - sPct / 100);
    var dd = 'M' + x0 + ' ' + yb + ' L' + x1.toFixed(1) + ' ' + yt + ' L' + x2.toFixed(1) + ' ' + ys.toFixed(1) + ' L' + x3.toFixed(1) + ' ' + ys.toFixed(1) + ' L' + x4.toFixed(1) + ' ' + yb;
    var s = '<svg class="diag envd" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Global ADSR envelope shape">';
    s += '<line class="axis" x1="' + ml + '" y1="' + mt + '" x2="' + ml + '" y2="' + yb + '"/><line class="axis" x1="' + ml + '" y1="' + yb + '" x2="' + (W - 14) + '" y2="' + yb + '"/>';
    s += '<line class="grid" x1="' + x3.toFixed(1) + '" y1="' + mt + '" x2="' + x3.toFixed(1) + '" y2="' + yb + '"/><text x="' + (x3 + 4) + '" y="' + (mt + 10) + '">key released</text>';
    s += '<path class="area" d="' + dd + 'z"/><path class="curve" d="' + dd + '"/>';
    [['Attack', (x0 + x1) / 2], ['Decay', (x1 + x2) / 2], ['Sustain', (x2 + x3) / 2], ['Release', (x3 + x4) / 2]].forEach(function (a) {
      s += '<text x="' + (a[1] - 18).toFixed(1) + '" y="' + (yb + 18) + '" style="font-weight:700">' + a[0] + '</text>';
    });
    return s + '</svg>';
  }
  function lfoSVG(kind) {
    var W = 120, H = 56, p = '';
    var f = {
      Triangle: 'M4 44 L34 12 L64 44 L94 12 L116 36',
      'Saw Down': 'M4 12 L34 44 L34 12 L64 44 L64 12 L94 44 L94 12 L116 30',
      'Saw Up': 'M4 44 L34 12 L34 44 L64 12 L64 44 L94 12 L94 44 L116 26',
      Square: 'M4 44 V12 H34 V44 H64 V12 H94 V44 H116',
      Sine: 'M4 28 C 14 -2, 24 -2, 34 28 S 54 58, 64 28 S 84 -2, 94 28 S 110 52 116 40',
      'S&Hold': 'M4 30 H22 V14 H40 V40 H58 V22 H76 V46 H94 V18 H116'
    };
    return '<svg class="diag envd" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' + kind + ' wave"><path class="curve" d="' + f[kind] + '"/></svg>';
  }

  /* ---------- TFT mock-ups ---------- */
  var FXN = ['Filter', 'Reverb', 'Delay', 'Distortion', 'Chorus', 'Phaser'];
  function batt() { return '<span class="bat"></span>'; }
  function tftHTML(c) {
    var cls = 'tft' + (c.kind === 'osc' ? ' osc' : '');
    var h = '<div class="' + cls + '" role="img" aria-label="' + esc(c.alt || ('FM-1 screen: ' + (c.foot || c.hdr))) + '">';
    h += '<div class="hd"><span>' + esc(c.hdr || '001 PIANO 1') + '</span>' + batt() + '</div>';
    var k = c.kind || 'tiles';
    if (k === 'tiles') {
      h += '<div class="bd"><div class="tiles">';
      (c.tiles || []).forEach(function (t, i) {
        if (!t) { h += '<div class="tile empty"></div>'; return; }
        var hot = (c.hot || []).indexOf(i + 1) >= 0;
        h += '<div class="tile' + (hot ? ' hot' : '') + '"><span class="kb">K' + (i + 1) + '</span><span class="nm">' + esc(t[0]) + '</span>';
        if (t[2] === 'bars') {
          h += '<span class="bars">'; for (var b = 0; b < 10; b++) h += '<i class="' + (b < Math.round(t[1] / 10) ? 'on' : '') + '"></i>'; h += '</span>';
        } else if (t[1] !== '') h += '<span class="vl">' + esc(t[1]) + '</span>';
        h += '</div>';
      });
      h += '</div></div>';
    } else if (k === 'fx') {
      var on = c.on || [1, 1, 1, 0, 0, 0], sel = c.sel == null ? 0 : c.sel;
      h += '<div class="bd"><div class="fxg">';
      for (var i = 0; i < 6; i++) {
        var nm = (c.order || FXN)[i];
        h += '<div class="fxc' + (i === sel ? ' sel' : '') + '"><div class="fxb' + (on[i] ? '' : ' off') + (c.grab === i ? ' grab' : '') + '">' + esc(nm === 'Distortion' ? 'Distort-ion'.replace('-', '') : nm) + '</div><span class="dot"></span>' + (c.num ? '<span class="po">' + (i + 1) + '</span>' : '') + '</div>';
      }
      h += '</div></div>';
    } else if (k === 'osc') {
      h += '<svg class="scope" viewBox="0 0 240 240" preserveAspectRatio="none"><path d="' + (c.wave ? 'M0 125 C 15 70, 30 70, 45 125 S 75 180, 90 125 S 120 70, 135 125 S 165 180, 180 125 S 210 70, 225 125 L240 125' : 'M0 125 H240') + '" fill="none" stroke="var(--scr-trace)" stroke-width="2.5"/></svg>';
    } else if (k === 'algo') {
      h += '<span class="abadge">' + ('0' + c.algo).slice(-2) + '</span>' + algoSVG(c.algo);
    } else if (k === 'list') {
      h += '<div class="big"><ul class="plist">' + c.items.map(function (t, i) { return '<li class="' + (i === c.cur ? 'cur' : '') + '">' + esc(t) + '</li>'; }).join('') + '</ul></div>';
    } else if (k === 'popup') {
      if (c.back) { h = h.replace('class="' + cls + '"', 'class="' + cls + '"'); }
      h += '<div class="pop">' + c.lines.map(function (l, i) { return i ? '<small>' + esc(l) + '</small>' : '<b>' + esc(l) + '</b>'; }).join('') + (c.letters ? '<div class="ltr">' + c.letters.map(function (x) { return '<b>' + x + '</b>'; }).join('') + '</div>' : '') + '</div>';
    } else if (k === 'dialog') {
      h += '<div class="big">' + c.lines.map(function (l, i) { return i === 0 ? '<b>' + esc(l) + '</b>' : '<span>' + esc(l) + '</span>'; }).join('') + (c.letters ? '<div class="ltr">' + c.letters.map(function (x) { return '<b>' + x + '</b>'; }).join('') + '</div>' : '') + '</div>';
    } else if (k === 'rename') {
      h += '<div class="big"><span>' + esc(c.cls) + '</span><div class="nm10">' + c.name.split('').map(function (x, i) { return '<span class="' + (i === c.cur ? 'cur' : '') + '">' + esc(x === ' ' ? ' ' : x) + '</span>'; }).join('') + '</div><span>' + esc(c.hint || '') + '</span></div>';
    } else if (k === 'shape') {
      h += '<div class="shape">' + c.svg + '</div>';
    }
    h += '<div class="ft">' + esc(c.foot || 'OSC') + '</div></div>';
    return h;
  }

  /* ---------- panel figure ---------- */
  function panelSVG(hl, opt) {
    opt = opt || {};
    var H = {}; (hl || '').split(',').forEach(function (p) { p = p.trim(); if (!p) return; var q = p.split(':'); H[q[0]] = q[1] || ''; });
    var s = '<svg class="panel" viewBox="0 0 1000 600" role="img" aria-label="' + esc(opt.alt || 'FM-1 front panel') + '">';
    s += '<rect class="body" x="0" y="0" width="1000" height="600" rx="42"/>';
    var coords = {
      master: [80, 92], select: [185, 92], presets: [80, 200], algorithm: [185, 200],
      k1: [568, 92], k2: [678, 92], k3: [790, 92], k4: [901, 92]
    };
    var names = { master: 'MASTER', select: 'SELECT', presets: 'PRESETS', algorithm: 'ALGORITHM', k1: 'KNOB1', k2: 'KNOB2', k3: 'KNOB3', k4: 'KNOB4' };
    var marks = [];
    function mark(id, cx, cy, r, dx, dy, rect) {
      if (H[id] === undefined) return;
      if (rect) marks.push('<rect class="hl" x="' + (cx - rect[0] / 2) + '" y="' + (cy - rect[1] / 2) + '" width="' + rect[0] + '" height="' + rect[1] + '" rx="11"/>');
      else marks.push('<circle class="hl" cx="' + cx + '" cy="' + cy + '" r="' + r + '"/>');
      if (H[id]) marks.push('<g class="co"><circle cx="' + (cx + (dx || 0)) + '" cy="' + (cy + (dy || 0)) + '" r="14"/><text x="' + (cx + (dx || 0)) + '" y="' + (cy + (dy || 0) + 1) + '">' + H[id] + '</text></g>');
    }
    Object.keys(coords).forEach(function (id) {
      var c = coords[id];
      s += '<text class="lbl" x="' + c[0] + '" y="' + (c[1] - 44) + '">' + names[id] + '</text>';
      s += '<circle class="knob" cx="' + c[0] + '" cy="' + c[1] + '" r="27"/><line class="tick" x1="' + c[0] + '" y1="' + (c[1] - 8) + '" x2="' + c[0] + '" y2="' + (c[1] - 22) + '"/>';
      mark(id, c[0], c[1], 35, 32, -30);
    });
    /* OCT tray */
    s += '<rect class="well" x="51" y="256" width="160" height="48" rx="12"/>';
    [['oct-', 'OCT−', 84], ['oct+', 'OCT+', 178]].forEach(function (b) {
      s += '<rect class="rbtn" x="' + (b[2] - 31) + '" y="262" width="62" height="36" rx="8"/><text class="btn-t" x="' + b[2] + '" y="280">' + b[1] + '</text>';
      mark(b[0], b[2], 280, 40, 30, -26, [70, 44]);
    });
    /* screen */
    s += '<rect class="scr" x="257" y="41" width="237" height="240" rx="30"/><rect class="scr-in" x="283" y="64" width="185" height="185" rx="6"/>';
    s += '<text x="375" y="160" text-anchor="middle" font-family="Arial" font-size="15" fill="#1e3446" font-weight="700">240×240 TFT</text>';
    mark('screen', 375, 160, 0, 118, -108, [245, 248]);
    /* function pad */
    s += '<rect class="well" x="535" y="170" width="430" height="140" rx="20"/>';
    var cols = [576, 638, 699, 760, 822, 883];
    var rowA = ['FX', 'SEL', 'ENV', 'LFO', 'EDIT', 'GLO'], rowB = ['HOME', 'SAVE', 'ARP', 'SEQ', 'PLAY|STOP', 'REC'];
    rowA.forEach(function (t, i) { fbtn(t.toLowerCase(), t, cols[i], 204); });
    rowB.forEach(function (t, i) { fbtn(t === 'PLAY|STOP' ? 'play' : t.toLowerCase(), t, cols[i], 267); });
    function fbtn(id, t, cx, cy) {
      s += '<rect class="rbtn" x="' + (cx - 28) + '" y="' + (cy - 26) + '" width="56" height="52" rx="9"/>';
      if (t === 'PLAY|STOP') s += '<text class="btn-t" x="' + cx + '" y="' + (cy - 8) + '" style="font-size:10px">PLAY</text><line x1="' + (cx - 16) + '" y1="' + cy + '" x2="' + (cx + 16) + '" y2="' + cy + '" stroke="#999"/><text class="btn-t" x="' + cx + '" y="' + (cy + 10) + '" style="font-size:10px">STOP</text>';
      else s += '<text class="btn-t" x="' + cx + '" y="' + cy + '">' + t + '</text>';
      mark(id, cx, cy, 36, 28, -26, [60, 56]);
    }
    /* keyboard */
    s += '<rect class="well" x="34" y="341" width="933" height="223" rx="26"/>';
    var wx = function (i) { return 88 + 56.7 * i; };
    var blackAfter = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14];
    var edit = ['OP1', 'OP2', 'OP3', 'OP4', 'OP5', 'OP6', 'PIT', 'GLO', 'MONO', 'POLY', ''];
    var lit = (opt.lit || '').split(',');
    var stepMode = H.steps !== undefined;
    for (var i = 0; i < 16; i++) {
      var on = stepMode && (opt.stepOn || []).indexOf(i) >= 0, play = stepMode && opt.playhead === i;
      s += '<rect class="key" x="' + (wx(i) - 24) + '" y="' + 463 + '" width="48" height="80" rx="22"/><rect class="stripe" style="' + (on || play ? 'fill:#67e8f9' : '') + '" x="' + (wx(i) - 2.5) + '" y="478" width="5" height="50" rx="2.5"/>';
      if (play) s += '<rect x="' + (wx(i) - 26) + '" y="461" width="52" height="84" rx="23" fill="none" stroke="#67e8f9" stroke-width="3" stroke-dasharray="6 5"/>';
    }
    blackAfter.forEach(function (w, j) {
      var cx = (wx(w) + wx(w + 1)) / 2, lab = edit[j];
      var lt = lit.indexOf(String(j)) >= 0 || (H.editkeys !== undefined && lab);
      s += '<rect class="key" x="' + (cx - 22) + '" y="372" width="44" height="68" rx="20"/><rect class="stripe" style="' + (lt && H.editkeys !== undefined ? 'fill:#67e8f9' : '') + '" x="' + (cx - 2.5) + '" y="382" width="5" height="34" rx="2.5"/>';
      if (H.editkeys !== undefined && lab) s += '<text class="sub" x="' + cx + '" y="432">' + lab + '</text>';
    });
    if (H.keys !== undefined) { marks.push('<rect class="hl" x="40" y="347" width="921" height="211" rx="22"/>'); if (H.keys) marks.push('<g class="co"><circle cx="60" cy="362" r="14"/><text x="60" y="363">' + H.keys + '</text></g>'); }
    if (H.editkeys) marks.push('<g class="co"><circle cx="60" cy="362" r="14"/><text x="60" y="363">' + H.editkeys + '</text></g>');
    if (H.steps) marks.push('<g class="co"><circle cx="60" cy="362" r="14"/><text x="60" y="363">' + H.steps + '</text></g>');
    return s + marks.join('') + '</svg>';
  }

  /* ---------- FM scope demo ---------- */
  function initDemo(root) {
    var cv = $('canvas', root), rat = $('[data-r]', root), idx = $('[data-i]', root), fb = $('[data-f]', root);
    var rv = $('[data-rv]', root), iv = $('[data-iv]', root), fv = $('[data-fv]', root), pb = $('[data-play]', root);
    var ctx = cv.getContext('2d'), audio = null;
    var ratios = [0.5, 1, 1.5, 2, 3, 3.5, 4, 5, 7, 14];
    function params() { return { r: ratios[+rat.value], i: +idx.value / 10, f: +fb.value / 7 }; }
    function sample(p, ph, st) {
      /* two-operator FM: carrier phase modulated by a modulator of ratio r; modulator has optional self feedback */
      var m = Math.sin(ph * p.r * 2 * Math.PI + p.f * 1.6 * st.prev);
      st.prev = m;
      return Math.sin(ph * 2 * Math.PI + p.i * m);
    }
    function draw() {
      var p = params(); rv.textContent = p.r + ' : 1'; iv.textContent = Math.round(p.i * 10); fv.textContent = fb.value;
      var w = cv.width = cv.clientWidth * (devicePixelRatio || 1), h = cv.height = 150 * (devicePixelRatio || 1);
      ctx.clearRect(0, 0, w, h); ctx.strokeStyle = '#a8c070'; ctx.lineWidth = 2 * (devicePixelRatio || 1); ctx.beginPath();
      var st = { prev: 0 }, cycles = 2;
      for (var x = 0; x < w; x++) { var ph = x / w * cycles, v = sample(p, ph, st); var y = h / 2 - v * h * 0.4; if (x) ctx.lineTo(x, y); else ctx.moveTo(x, y); }
      ctx.stroke();
      if (audio && audio.osc) { audio.osc.frequency.value = 220; audio.mod.frequency.value = 220 * p.r; audio.g.gain.value = 220 * p.i * 2; }
    }
    [rat, idx, fb].forEach(function (e) { e.addEventListener('input', draw); });
    window.addEventListener('resize', draw);
    pb.addEventListener('click', function () {
      try {
        if (audio) { audio.osc.stop(); audio.mod.stop(); audio.ctx.close(); audio = null; pb.textContent = '▶ Hear it'; return; }
        var AC = window.AudioContext || window.webkitAudioContext, c = new AC();
        var osc = c.createOscillator(), mod = c.createOscillator(), g = c.createGain(), out = c.createGain();
        out.gain.value = 0.15; mod.connect(g); g.connect(osc.frequency); osc.connect(out); out.connect(c.destination);
        osc.start(); mod.start(); audio = { ctx: c, osc: osc, mod: mod, g: g }; pb.textContent = '■ Stop'; draw();
      } catch (e) { pb.textContent = 'Audio not available'; }
    });
    draw();
  }

  /* ---------- hydrate ---------- */
  function hydrate() {
    $$('[data-tft]').forEach(function (el) {
      try { el.innerHTML = tftHTML(JSON.parse(el.getAttribute('data-tft'))); } catch (e) { el.textContent = 'Screen mock-up failed to render'; }
    });
    $$('[data-algo]').forEach(function (el) { el.innerHTML = algoSVG(+el.getAttribute('data-algo')); });
    $$('[data-env]').forEach(function (el) {
      var v = JSON.parse(el.getAttribute('data-env')); el.innerHTML = envSVG(v.r, v.l, v);
    });
    $$('[data-adsr]').forEach(function (el) { var v = JSON.parse(el.getAttribute('data-adsr')); el.innerHTML = adsrSVG(v[0], v[1], v[2], v[3]); });
    $$('[data-lfo]').forEach(function (el) { el.innerHTML = lfoSVG(el.getAttribute('data-lfo')); });
    $$('[data-panel]').forEach(function (el) {
      var o = {}; try { o = JSON.parse(el.getAttribute('data-opt') || '{}'); } catch (e) {}
      el.innerHTML = panelSVG(el.getAttribute('data-panel'), o);
    });
    $$('.agrid[data-all]').forEach(function (g) {
      var h = ''; for (var n = 1; n <= 32; n++) h += '<figure><div>' + algoSVG(n) + '</div><figcaption>Algorithm ' + n + '</figcaption></figure>';
      g.innerHTML = h;
    });
    $$('.demo[data-demo]').forEach(initDemo);
  }
  document.addEventListener('DOMContentLoaded', function () { initChrome(); hydrate(); });
})();
