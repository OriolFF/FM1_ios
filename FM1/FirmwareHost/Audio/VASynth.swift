import Foundation

/// Native virtual-analog polysynth block (`"type": "va"`): two PolyBLEP oscillators
/// (saw / pulse / triangle / sine), sub square, noise, hard sync, Poly-Mod (osc 2 → osc 1
/// FM), a 4-pole zero-delay ladder low-pass or a 2-pole SVF band/high-pass, filter and amp
/// envelopes, glide, POLY / MONO / LEGATO / UNISON, one LFO.
/// Covers SLOOP's and Felucca's ANALOG engine and Melodee's PROPHET in this host.
final class VASynth: PkgInstrument {
    let kind = "va"
    static let table: [PkgParam] = [
        PkgParam("wave1", 0, count: 4), PkgParam("wave2", 1, count: 4),
        PkgParam("pw", 0.5), PkgParam("semi2", 24, count: 49), PkgParam("detune", 0.55),
        PkgParam("osc1", 1), PkgParam("osc2", 0.7), PkgParam("sub", 0), PkgParam("noise", 0),
        PkgParam("sync", 0, count: 2), PkgParam("polymod", 0),
        PkgParam("cutoff", 0.55), PkgParam("res", 0.2), PkgParam("ftype", 0, count: 3),
        PkgParam("envamt", 0.7), PkgParam("keytrack", 0.5),
        PkgParam("fa", 0.05), PkgParam("fd", 0.45), PkgParam("fs", 0.3), PkgParam("fr", 0.4),
        PkgParam("a", 0.02), PkgParam("d", 0.5), PkgParam("s", 0.8), PkgParam("r", 0.35),
        PkgParam("drive", 0.2), PkgParam("glide", 0), PkgParam("mode", 0, count: 4),
        PkgParam("lforate", 0.5), PkgParam("lfowave", 0, count: 4),
        PkgParam("lfopitch", 0), PkgParam("lfocutoff", 0), PkgParam("lfopw", 0),
        PkgParam("level", 0.8), PkgParam("vel", 0.5), PkgParam("spread", 0.3),
    ]
    enum P: Int {
        case wave1, wave2, pw, semi2, detune, osc1, osc2, sub, noise, sync, polymod
        case cutoff, res, ftype, envamt, keytrack, fa, fd, fs, fr, a, d, s, r
        case drive, glide, mode, lforate, lfowave, lfopitch, lfocutoff, lfopw, level, vel, spread
    }
    var paramTable: [PkgParam] { VASynth.table }
    let params = PkgParamStore(VASynth.table)
    func setParam(_ i: Int, _ v: Float) { params.set(i, v) }
    func param(_ i: Int) -> Float { params.base[i] }
    func applyLock(_ i: Int, _ v: UInt8) { params.applyLock(i, v) }
    func clearLocks() { params.clearLocks() }
    @inline(__always) private func pv(_ p: P) -> Float { params.v(p.rawValue) }
    @inline(__always) private func pi(_ p: P) -> Int { params.idx(p.rawValue) }

    private struct Voice {
        var note = 60
        var vel: Float = 0
        var keyDown = false
        var age = 0
        var pitch: Float = 60          // current (gliding) semitone pitch
        var target: Float = 60
        var offset: Float = 0          // unison detune, semitones
        var drift: Float = 0
        var p1: Float = 0, p2: Float = 0, ps: Float = 0
        var amp = PkgEnv(), filt = PkgEnv()
        var s1: Float = 0, s2: Float = 0, s3: Float = 0, s4: Float = 0   // ladder states
        var ic1: Float = 0, ic2: Float = 0                               // SVF states
        var accent: Float = 0
    }
    private let maxVoices: Int
    private let voices: UnsafeMutablePointer<Voice>
    private let sr: Float
    private var ageCounter = 0
    private var stack = PkgNoteStack()
    private var lfoPhase: Float = 0
    private var lfoHold: Float = 0
    private var rng: UInt32 = 0x9E37_79B9
    private(set) var meter: Float = 0

    init(sampleRate: Float, voices n: Int) {
        sr = sampleRate
        maxVoices = min(max(n, 1), 12)
        voices = .allocate(capacity: maxVoices)
        voices.initialize(repeating: Voice(), count: maxVoices)
        for v in 0..<maxVoices { voices[v].drift = Float(v % 5) * 0.004 - 0.008 }
    }
    deinit { voices.deinitialize(count: maxVoices); voices.deallocate() }

    // MARK: notes (audio thread)

    private func allocate() -> Int {
        for v in 0..<maxVoices where !voices[v].amp.active { return v }
        var best = 0, bestAge = Int.max
        for v in 0..<maxVoices where !voices[v].keyDown && voices[v].age < bestAge { best = v; bestAge = voices[v].age }
        if bestAge != Int.max { return best }
        for v in 0..<maxVoices where voices[v].age < bestAge { best = v; bestAge = voices[v].age }
        return best
    }

    private func start(_ v: Int, note: Int, vel: Int, offset: Float, legato: Bool, accent: Bool) {
        ageCounter += 1
        let glide = pv(.glide)
        voices[v].note = note
        voices[v].vel = Float(vel) / 127
        voices[v].keyDown = true
        voices[v].age = ageCounter
        voices[v].offset = offset
        voices[v].target = Float(note)
        voices[v].accent = accent ? 1 : 0
        if glide <= 0.001 || !voices[v].amp.active { voices[v].pitch = Float(note) }
        if !legato {
            voices[v].amp.gate(true)
            voices[v].filt.gate(true)
            if !voices[v].amp.active || voices[v].amp.level < 0.001 { voices[v].p1 = 0; voices[v].p2 = 0; voices[v].ps = 0 }
        }
    }

    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) {
        let mode = pi(.mode)
        switch mode {
        case 1, 2: // mono, legato
            let wasHeld = stack.count > 0
            stack.push(note)
            let legato = (mode == 2 && wasHeld) || slide
            start(0, note: note, vel: vel, offset: 0, legato: legato && voices[0].amp.active, accent: accent)
        case 3: // unison: three voices stacked
            let sp = pv(.spread) * 0.3
            let n = min(3, maxVoices)
            for i in 0..<n {
                let v = allocate()
                start(v, note: note, vel: vel, offset: (Float(i) - Float(n - 1) / 2) * sp, legato: false, accent: accent)
            }
        default:
            start(allocate(), note: note, vel: vel, offset: 0, legato: false, accent: accent)
        }
    }

    func noteOff(_ note: Int) {
        let mode = pi(.mode)
        if mode == 1 || mode == 2 {
            stack.remove(note)
            if let back = stack.top {
                voices[0].note = back
                voices[0].target = Float(back)
                if pv(.glide) <= 0.001 { voices[0].pitch = Float(back) }
            } else {
                voices[0].keyDown = false
                voices[0].amp.gate(false); voices[0].filt.gate(false)
            }
            return
        }
        for v in 0..<maxVoices where voices[v].keyDown && voices[v].note == note {
            voices[v].keyDown = false
            voices[v].amp.gate(false); voices[v].filt.gate(false)
        }
    }

    func hit(_ lane: Int, vel: Int) {}

    func allOff() {
        stack.count = 0
        for v in 0..<maxVoices { voices[v].keyDown = false; voices[v].amp.gate(false); voices[v].filt.gate(false) }
    }

    // MARK: render (audio thread)

    @inline(__always) private func noise() -> Float {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / 2147483648
    }

    @inline(__always) private func osc(_ wave: Int, _ p: Float, _ dt: Float, _ pw: Float) -> Float {
        switch wave {
        case 0: return 2 * p - 1 - pkgBlep(p, dt)
        case 1:
            var q = p - pw; if q < 0 { q += 1 }
            return (p < pw ? 1 : -1) + pkgBlep(p, dt) - pkgBlep(q, dt)
        case 2: return 1 - 4 * abs(p - 0.5)
        default: return pkgSin2pi(p)
        }
    }

    func render(frames: Int, out: UnsafeMutablePointer<Float>) {
        let n = frames
        // block-rate controls
        let w1 = pi(.wave1), w2 = pi(.wave2)
        let semi2 = Float(pi(.semi2) - 24)
        let det = (pv(.detune) - 0.5) * 1.0             // ±0.5 semitone
        let l1 = pv(.osc1), l2 = pv(.osc2), lsub = pv(.sub), lnoise = pv(.noise)
        let sync = pi(.sync) == 1
        let pm = pv(.polymod) * pv(.polymod) * 4
        let cutoffV = pv(.cutoff), res = pv(.res), ftype = pi(.ftype)
        let envAmt = pv(.envamt) * 2 - 1, keyTrack = pv(.keytrack)
        let fa = pkgTime(pv(.fa)), fd = pkgTime(pv(.fd)), fs = pv(.fs), fr = pkgTime(pv(.fr))
        let aa = pkgTime(pv(.a)), ad = pkgTime(pv(.d)), asus = pv(.s), ar = pkgTime(pv(.r))
        let drive = 1 + pv(.drive) * 6
        let glide = pv(.glide) * pv(.glide) * 2
        let level = pv(.level) * pv(.level) * 0.32
        let velAmt = pv(.vel)
        // LFO
        let lfoHz = 0.05 * powf(400, pv(.lforate))
        lfoPhase += lfoHz * Float(n) / sr
        if lfoPhase >= 1 { lfoPhase -= floorf(lfoPhase); lfoHold = noise() }
        let lfo: Float
        switch pi(.lfowave) {
        case 0: lfo = 1 - 4 * abs(lfoPhase - 0.5)
        case 1: lfo = pkgSin2pi(lfoPhase)
        case 2: lfo = lfoPhase < 0.5 ? 1 : -1
        default: lfo = lfoHold
        }
        let lfoPitch = lfo * pv(.lfopitch) * 2
        let lfoCut = lfo * pv(.lfocutoff) * 3
        let pw = min(0.95, max(0.05, 0.5 + (pv(.pw) - 0.5) * 0.9 + lfo * pv(.lfopw) * 0.4))
        let glideCoef: Float = glide > 0.001 ? expf(-Float(n) / (glide * sr * 0.35)) : 0

        var peak: Float = 0
        for v in 0..<maxVoices where voices[v].amp.active {
            var vo = voices[v]
            // glide
            vo.pitch = vo.target + (vo.pitch - vo.target) * glideCoef
            let pitch = vo.pitch + vo.offset + vo.drift + lfoPitch
            let f1 = 440 * exp2f((pitch - 69) / 12)
            let f2 = 440 * exp2f((pitch + semi2 + det - 69) / 12)
            let dt1 = min(0.45, f1 / sr), dt2 = min(0.45, f2 / sr), dts = dt1 * 0.5
            let ampL = vo.amp.tick(n: n, a: aa, d: ad, s: asus, r: ar, sr: sr)
            let fEnv = vo.filt.tick(n: n, a: fa, d: fd, s: fs, r: fr, sr: sr)
            let velG = 1 - velAmt + velAmt * vo.vel
            // cutoff in octaves around 20 Hz … 20 kHz
            let oct = cutoffV * 10 + envAmt * fEnv * 6 * (0.6 + 0.4 * vo.vel * velAmt + 0.3 * vo.accent)
                + keyTrack * (pitch - 60) / 12 + lfoCut
            let fc = min(sr * 0.45, 20 * exp2f(min(max(oct, 0), 10)))
            let g = tanf(Float.pi * fc / sr)
            let G = g / (1 + g)
            let k = res * 4.1
            // SVF coefficients
            let ks = 2 - 1.98 * res
            let a1 = 1 / (1 + g * (g + ks)), a2 = g * a1, a3 = g * a2
            let amp = ampL * velG * level * (1 + vo.accent * 0.35)
            var p1 = vo.p1, p2 = vo.p2, ps = vo.ps
            var s1 = vo.s1, s2 = vo.s2, s3 = vo.s3, s4 = vo.s4, ic1 = vo.ic1, ic2 = vo.ic2
            for i in 0..<n {
                // osc 2 first (Poly-Mod source / sync master is osc 1 in Prophet; here osc 1 resets osc 2)
                let o2 = osc(w2, p2, dt2, pw)
                let mdt1 = max(0, dt1 * (1 + pm * o2))
                let o1 = osc(w1, p1, mdt1, pw)
                let sub: Float = ps < 0.5 ? 1 : -1
                var x = o1 * l1 + o2 * l2 + sub * lsub + noise() * lnoise
                p1 += mdt1
                if p1 >= 1 { p1 -= 1; if sync { p2 = p1 * dt2 / max(mdt1, 1e-6) } }
                p2 += dt2; if p2 >= 1 { p2 -= 1 }
                ps += dts; if ps >= 1 { ps -= 1 }
                x = pkgTanh(x * drive * 0.5)
                var y: Float
                if ftype == 0 {
                    let b = 1 / (1 + g)
                    let S = G * G * G * s1 * b + G * G * s2 * b + G * s3 * b + s4 * b
                    let G4 = G * G * G * G
                    var u = (x - k * S) / (1 + k * G4)
                    u = pkgTanh(u)
                    var vv = (u - s1) * G; let y1 = vv + s1; s1 = y1 + vv
                    vv = (y1 - s2) * G; let y2 = vv + s2; s2 = y2 + vv
                    vv = (y2 - s3) * G; let y3 = vv + s3; s3 = y3 + vv
                    vv = (y3 - s4) * G; let y4 = vv + s4; s4 = y4 + vv
                    y = y4 * (1 + res * 0.8)
                } else {
                    let v3 = x - ic2
                    let v1 = a1 * ic1 + a2 * v3
                    let v2 = ic2 + a2 * ic1 + a3 * v3
                    ic1 = 2 * v1 - ic1; ic2 = 2 * v2 - ic2
                    y = ftype == 1 ? v1 * ks : x - ks * v1 - v2
                }
                let o = y * amp
                out[i] += o
                let ao = abs(o); if ao > peak { peak = ao }
            }
            vo.p1 = p1; vo.p2 = p2; vo.ps = ps
            vo.s1 = s1; vo.s2 = s2; vo.s3 = s3; vo.s4 = s4; vo.ic1 = ic1; vo.ic2 = ic2
            if !vo.amp.active { vo.s1 = 0; vo.s2 = 0; vo.s3 = 0; vo.s4 = 0; vo.ic1 = 0; vo.ic2 = 0 }
            voices[v] = vo
        }
        meter = max(peak * 3, meter * 0.9)
    }
}
