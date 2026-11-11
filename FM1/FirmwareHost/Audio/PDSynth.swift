import Foundation

/// Native phase-distortion polysynth block (`"type": "pd"`), after Casio's CZ method as
/// documented in the CZ-101/1000 manuals: a cosine read through a warped phase, the warp
/// amount (DCW) swept by its own envelope. Eight waveforms (saw, square, pulse, double sine,
/// saw-pulse, resonance 1–3), line modes 1, 1+2, 1+1' (detuned) and 1×2 (ring), a
/// wavefolder (Felucca PHASE's FOLD), vibrato. DCW and DCA use ADSR envelopes where the
/// CZ has eight-point envelopes (an approximation, see Firmwares/README.md).
final class PDSynth: PkgInstrument {
    let kind = "pd"
    static let waveNames = ["SAW", "SQUARE", "PULSE", "DBL SINE", "SAW-PULSE", "RESO 1", "RESO 2", "RESO 3"]
    static let table: [PkgParam] = [
        PkgParam("wave1", 0, count: 8), PkgParam("wave2", 1, count: 8), PkgParam("line", 0, count: 4),
        PkgParam("semi2", 24, count: 49), PkgParam("detune", 0.55),
        PkgParam("dcw", 0.3), PkgParam("dcwenv", 0.6),
        PkgParam("da", 0.02), PkgParam("dd", 0.5), PkgParam("ds", 0.3), PkgParam("dr", 0.4),
        PkgParam("a", 0.02), PkgParam("d", 0.55), PkgParam("s", 0.7), PkgParam("r", 0.4),
        PkgParam("fold", 0), PkgParam("vib", 0), PkgParam("vibrate", 0.55),
        PkgParam("level", 0.8), PkgParam("vel", 0.5), PkgParam("glide", 0), PkgParam("mode", 0, count: 3),
    ]
    enum P: Int { case wave1, wave2, line, semi2, detune, dcw, dcwenv, da, dd, ds, dr, a, d, s, r, fold, vib, vibrate, level, vel, glide, mode }
    var paramTable: [PkgParam] { PDSynth.table }
    let params = PkgParamStore(PDSynth.table)
    func setParam(_ i: Int, _ v: Float) { params.set(i, v) }
    func param(_ i: Int) -> Float { params.base[i] }
    func applyLock(_ i: Int, _ v: UInt8) { params.applyLock(i, v) }
    func clearLocks() { params.clearLocks() }
    @inline(__always) private func pv(_ p: P) -> Float { params.v(p.rawValue) }
    @inline(__always) private func pi(_ p: P) -> Int { params.idx(p.rawValue) }

    private struct Voice {
        var note = 60, keyDown = false, age = 0
        var vel: Float = 0, accent: Float = 0
        var pitch: Float = 60, target: Float = 60
        var p1: Float = 0, p2: Float = 0
        var amp = PkgEnv(), dcw = PkgEnv()
        var dcwLevel: Float = 0
    }
    private let maxVoices: Int
    private let voices: UnsafeMutablePointer<Voice>
    private let sr: Float
    private var ageCounter = 0
    private var stack = PkgNoteStack()
    private var vibPhase: Float = 0
    private(set) var meter: Float = 0

    init(sampleRate: Float, voices n: Int) {
        sr = sampleRate
        maxVoices = min(max(n, 1), 12)
        voices = .allocate(capacity: maxVoices)
        voices.initialize(repeating: Voice(), count: maxVoices)
    }
    deinit { voices.deinitialize(count: maxVoices); voices.deallocate() }

    private func allocate() -> Int {
        for v in 0..<maxVoices where !voices[v].amp.active { return v }
        var best = 0, bestAge = Int.max
        for v in 0..<maxVoices where !voices[v].keyDown && voices[v].age < bestAge { best = v; bestAge = voices[v].age }
        if bestAge != Int.max { return best }
        for v in 0..<maxVoices where voices[v].age < bestAge { best = v; bestAge = voices[v].age }
        return best
    }

    private func start(_ v: Int, _ note: Int, _ vel: Int, legato: Bool, accent: Bool) {
        ageCounter += 1
        voices[v].note = note; voices[v].keyDown = true; voices[v].age = ageCounter
        voices[v].vel = Float(vel) / 127; voices[v].accent = accent ? 1 : 0
        voices[v].target = Float(note)
        if pv(.glide) <= 0.001 || !voices[v].amp.active { voices[v].pitch = Float(note) }
        if !legato {
            if !voices[v].amp.active { voices[v].p1 = 0; voices[v].p2 = 0 }
            voices[v].amp.gate(true); voices[v].dcw.gate(true)
        }
    }

    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) {
        let mode = pi(.mode)
        if mode == 0 { start(allocate(), note, vel, legato: false, accent: accent); return }
        let held = stack.count > 0
        stack.push(note)
        start(0, note, vel, legato: ((mode == 2 && held) || slide) && voices[0].amp.active, accent: accent)
    }

    func noteOff(_ note: Int) {
        if pi(.mode) != 0 {
            stack.remove(note)
            if let back = stack.top {
                voices[0].note = back; voices[0].target = Float(back)
                if pv(.glide) <= 0.001 { voices[0].pitch = Float(back) }
            } else {
                voices[0].keyDown = false; voices[0].amp.gate(false); voices[0].dcw.gate(false)
            }
            return
        }
        for v in 0..<maxVoices where voices[v].keyDown && voices[v].note == note {
            voices[v].keyDown = false; voices[v].amp.gate(false); voices[v].dcw.gate(false)
        }
    }

    func hit(_ lane: Int, vel: Int) {}
    func allOff() {
        stack.count = 0
        for v in 0..<maxVoices { voices[v].keyDown = false; voices[v].amp.gate(false); voices[v].dcw.gate(false) }
    }

    /// One CZ waveform: phase `p` 0..<1 warped by `w` 0...1 (DCW), cosine read.
    @inline(__always) private func wave(_ kind: Int, _ p: Float, _ w: Float) -> Float {
        let w = min(max(w, 0), 0.98)
        switch kind {
        case 0: // saw: knee moves from 0.5 towards 0
            let d = 0.5 - 0.5 * w
            let ph = p < d ? 0.5 * p / max(d, 0.001) : 0.5 + 0.5 * (p - d) / (1 - d)
            return -pkgCos2pi(ph)
        case 1: // square: each half rises then holds
            let h = p < 0.5 ? p * 2 : (p - 0.5) * 2
            let seg = min(1, h / max(1 - w, 0.02))
            return -pkgCos2pi((p < 0.5 ? 0 : 0.5) + 0.5 * seg)
        case 2: // pulse
            let d = 1 - w * 0.96
            return -pkgCos2pi(min(1, p / d))
        case 3: // double sine: saw warp in each half, second half inverted
            let q = p < 0.5 ? p * 2 : (p - 0.5) * 2
            let d = 0.5 - 0.5 * w
            let ph = q < d ? 0.5 * q / max(d, 0.001) : 0.5 + 0.5 * (q - d) / (1 - d)
            let c = -pkgCos2pi(ph)
            return p < 0.5 ? c : -c
        case 4: // saw-pulse: saw first half, held second half
            if p < 0.5 {
                let d = 0.5 - 0.5 * w
                let q = p * 2
                let ph = q < d ? 0.5 * q / max(d, 0.001) : 0.5 + 0.5 * (q - d) / (1 - d)
                return -pkgCos2pi(ph * 0.5 + 0.0)
            }
            return -pkgCos2pi(0.5 + min(1, (p - 0.5) * 2 / max(1 - w, 0.02)) * 0.5)
        default: // resonance: a synced cosine, windowed (5 saw, 6 triangle, 7 trapezoid)
            let r = 1 + w * 14
            let win: Float
            switch kind {
            case 5: win = 1 - p
            case 6: win = 1 - abs(2 * p - 1)
            default: win = min(1, 2 * (1 - p))
            }
            return (1 - pkgCos2pi(p * r)) * win - 0.5 * win
        }
    }

    func render(frames n: Int, out: UnsafeMutablePointer<Float>) {
        let w1 = pi(.wave1), w2 = pi(.wave2), line = pi(.line)
        let semi2 = Float(pi(.semi2) - 24), det = (pv(.detune) - 0.5) * 0.5
        let dcwBase = pv(.dcw), dcwEnvAmt = pv(.dcwenv)
        let da = pkgTime(pv(.da)), dd = pkgTime(pv(.dd)), ds = pv(.ds), dr = pkgTime(pv(.dr))
        let aa = pkgTime(pv(.a)), ad = pkgTime(pv(.d)), asus = pv(.s), ar = pkgTime(pv(.r))
        let fold = pv(.fold)
        let level = pv(.level) * pv(.level) * 0.3
        let velAmt = pv(.vel)
        let glide = pv(.glide) * pv(.glide) * 2
        let glideCoef: Float = glide > 0.001 ? expf(-Float(n) / (glide * sr * 0.35)) : 0
        vibPhase += (0.5 * powf(20, pv(.vibrate))) * Float(n) / sr
        vibPhase -= floorf(vibPhase)
        let vib = pkgSin2pi(vibPhase) * pv(.vib) * 0.6
        let foldGain = 1 + fold * 5
        var peak: Float = 0
        for v in 0..<maxVoices where voices[v].amp.active {
            var vo = voices[v]
            vo.pitch = vo.target + (vo.pitch - vo.target) * glideCoef
            let pitch = vo.pitch + vib
            let dt1 = min(0.45, 440 * exp2f((pitch - 69) / 12) / sr)
            let pitch2 = line == 2 ? pitch + det + 0.08 : pitch + semi2 + det
            let dt2 = min(0.45, 440 * exp2f((pitch2 - 69) / 12) / sr)
            let ampL = vo.amp.tick(n: n, a: aa, d: ad, s: asus, r: ar, sr: sr)
            let dEnv = vo.dcw.tick(n: n, a: da, d: dd, s: ds, r: dr, sr: sr)
            let velG = 1 - velAmt + velAmt * vo.vel
            let target = min(1, dcwBase + dcwEnvAmt * dEnv * (0.5 + 0.5 * velG) + vo.accent * 0.15)
            let w0 = vo.dcwLevel
            let dw = (target - w0) / Float(n)
            let amp = ampL * velG * level
            var p1 = vo.p1, p2 = vo.p2
            for i in 0..<n {
                let w = w0 + dw * Float(i)
                var x = wave(w1, p1, w)
                switch line {
                case 1: x = 0.6 * (x + wave(w2, p2, w))
                case 2: x = 0.6 * (x + wave(w1, p2, w))
                case 3: x = x * wave(w2, p2, w)
                default: break
                }
                if fold > 0.001 { x = pkgSin2pi(x * foldGain * 0.25) }
                p1 += dt1; if p1 >= 1 { p1 -= 1 }
                p2 += dt2; if p2 >= 1 { p2 -= 1 }
                let o = x * amp
                out[i] += o
                let ao = abs(o); if ao > peak { peak = ao }
            }
            vo.p1 = p1; vo.p2 = p2; vo.dcwLevel = target
            voices[v] = vo
        }
        meter = max(peak * 3, meter * 0.9)
    }
}
