import Foundation

/// Master effects in the order Filter → Distortion → Chorus → Phaser → Delay → Reverb.
/// All parameters are plain stored floats (0...1 unless noted); the UI writes
/// them directly, the audio thread reads them once per buffer.
final class FXChain: @unchecked Sendable {
    enum Kind: Int, CaseIterable { case filter, reverb, delay, distortion, chorus, phaser
        var name: String { ["Filter", "Reverb", "Delay", "Distortion", "Chorus", "Phaser"][rawValue] }
        /// K1...K3 parameter names
        var paramNames: [String] {
            switch self {
            case .filter: return ["Type", "CutOff", "Q"]
            case .reverb: return ["Type", "Decay", "Mix"]
            case .delay: return ["Decay", "Rate", "Mix"]
            case .distortion: return ["Gain", "Tone", "Level"]
            case .chorus, .phaser: return ["Freq", "Depth", "Mix"]
            }
        }
        var typeNames: [String]? {
            switch self {
            case .filter: return ["Low Pass", "Band Pass", "High Pass"]
            case .reverb: return ["Room", "Hall", "Plate"]
            default: return nil
            }
        }
        func range(_ p: Int) -> ClosedRange<Int> { (p == 0 && typeNames != nil) ? 0...2 : 0...100 }
        var defaults: [Int] {
            switch self {
            case .filter: return [0, 60, 20]
            case .reverb: return [1, 50, 30]
            case .delay: return [40, 35, 30]
            case .distortion: return [40, 60, 70]
            case .chorus: return [30, 50, 50]
            case .phaser: return [25, 70, 50]
            }
        }
        func display(_ p: Int, _ v: Int) -> String {
            if p == 0, let t = typeNames { return t[min(t.count - 1, max(0, v))] }
            if self == .filter && p == 1 { return "\(Int(FXChain.cutoffHz(v)))Hz" }
            return "\(v)%"
        }
    }

    static func cutoffHz(_ v: Int) -> Float { 100 * powf(200, Float(v) / 100) }

    /// slot → effect kind raw value (chain order)
    let order: UnsafeMutablePointer<Int>
    /// per effect kind: on flag
    let enabled: UnsafeMutablePointer<Bool>
    /// per effect kind × 3 params (0...100 or type index)
    let params: UnsafeMutablePointer<Int>

    func param(_ k: Kind, _ p: Int) -> Int { params[k.rawValue * 3 + p] }
    func setParam(_ k: Kind, _ p: Int, _ v: Int) { let r = k.range(p); params[k.rawValue * 3 + p] = min(max(v, r.lowerBound), r.upperBound) }

    // derived values, refreshed per buffer
    private var filterType = 0
    private var filterFreq: Float = 1000
    private var filterRes: Float = 0.2
    private var reverbSize: Float = 0.6
    private var reverbDamp: Float = 0.4
    private var reverbMix: Float = 0.3
    private var delayTime: Float = 0.35
    private var delayFeedback: Float = 0.4
    private var delayMix: Float = 0.3
    private var delayTone: Float = 0.6
    private var driveAmount: Float = 0.4
    private var driveTone: Float = 0.6
    private var driveLevel: Float = 0.7
    private var chorusRate: Float = 0.3
    private var chorusDepth: Float = 0.5
    private var chorusMix: Float = 0.5
    private var phaserRate: Float = 0.25
    private var phaserDepth: Float = 0.7
    private var phaserFeedback: Float = 0.5
    private var phaserMix: Float = 0.5

    func resetDefaults() {
        for k in Kind.allCases {
            order[k.rawValue] = k.rawValue
            enabled[k.rawValue] = false
            for p in 0..<3 { params[k.rawValue * 3 + p] = k.defaults[p] }
        }
    }

    private func refresh() {
        func pv(_ k: Kind, _ p: Int) -> Float { Float(params[k.rawValue * 3 + p]) / 100 }
        filterType = params[0]
        filterFreq = FXChain.cutoffHz(params[1])
        filterRes = pv(.filter, 2)
        let rt = params[3]
        let decay = pv(.reverb, 1)
        reverbSize = [0.35, 0.65, 0.8][min(2, max(0, rt))] + decay * 0.2
        reverbDamp = [0.6, 0.4, 0.15][min(2, max(0, rt))]
        reverbMix = pv(.reverb, 2)
        delayFeedback = pv(.delay, 0) * 0.92
        delayTime = 0.03 + pv(.delay, 1) * 0.97
        delayMix = pv(.delay, 2)
        driveAmount = pv(.distortion, 0)
        driveTone = pv(.distortion, 1)
        driveLevel = pv(.distortion, 2)
        chorusRate = pv(.chorus, 0); chorusDepth = pv(.chorus, 1); chorusMix = pv(.chorus, 2)
        phaserRate = pv(.phaser, 0); phaserDepth = pv(.phaser, 1); phaserMix = pv(.phaser, 2)
    }

    private let sr: Float

    // filter state (stereo SVF)
    private var fLow: (Float, Float) = (0, 0), fBand: (Float, Float) = (0, 0)
    // distortion tone lowpass
    private var dLP: (Float, Float) = (0, 0)
    // chorus
    private let chLen = 4096
    private var chBufL: UnsafeMutablePointer<Float>, chBufR: UnsafeMutablePointer<Float>
    private var chW = 0
    private var chPhase: Float = 0
    // phaser
    private var phZ = [Float](repeating: 0, count: 12)
    private var phLast: (Float, Float) = (0, 0)
    private var phPhase: Float = 0
    // delay
    private let dlLen: Int
    private var dlL: UnsafeMutablePointer<Float>, dlR: UnsafeMutablePointer<Float>
    private var dlW = 0
    private var dlTone: (Float, Float) = (0, 0)
    private var dlTimeSmooth: Float = 0.35
    // reverb (Freeverb style)
    private var combs: [Comb] = []
    private var allpasses: [Allpass] = []

    init(sampleRate: Float) {
        sr = sampleRate
        func buf(_ n: Int) -> UnsafeMutablePointer<Float> { let p = UnsafeMutablePointer<Float>.allocate(capacity: n); p.initialize(repeating: 0, count: n); return p }
        order = .allocate(capacity: 6); order.initialize(repeating: 0, count: 6)
        enabled = .allocate(capacity: 6); enabled.initialize(repeating: false, count: 6)
        params = .allocate(capacity: 18); params.initialize(repeating: 0, count: 18)
        chBufL = buf(chLen); chBufR = buf(chLen)
        dlLen = Int(sampleRate * 1.3)
        dlL = buf(dlLen); dlR = buf(dlLen)
        let scale = sampleRate / 44100
        let combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let apTunings = [556, 441, 341, 225]
        for (i, t) in combTunings.enumerated() {
            combs.append(Comb(size: Int(Float(t) * scale)))
            combs.append(Comb(size: Int(Float(t + 23) * scale)))
            _ = i
        }
        for t in apTunings {
            allpasses.append(Allpass(size: Int(Float(t) * scale)))
            allpasses.append(Allpass(size: Int(Float(t + 23) * scale)))
        }
        resetDefaults()
    }

    final class Comb {
        let buf: UnsafeMutablePointer<Float>; let size: Int; var idx = 0; var store: Float = 0
        init(size: Int) { self.size = size; buf = .allocate(capacity: size); buf.initialize(repeating: 0, count: size) }
        @inline(__always) func process(_ x: Float, feedback: Float, damp: Float) -> Float {
            let y = buf[idx]
            store = y * (1 - damp) + store * damp
            buf[idx] = x + store * feedback
            idx += 1; if idx >= size { idx = 0 }
            return y
        }
    }
    final class Allpass {
        let buf: UnsafeMutablePointer<Float>; let size: Int; var idx = 0
        init(size: Int) { self.size = size; buf = .allocate(capacity: size); buf.initialize(repeating: 0, count: size) }
        @inline(__always) func process(_ x: Float) -> Float {
            let b = buf[idx]
            let y = -x + b
            buf[idx] = x + b * 0.5
            idx += 1; if idx >= size { idx = 0 }
            return y
        }
    }

    /// Mono input in `left`; writes stereo into left/right.
    func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        refresh()
        for i in 0..<frames { right[i] = left[i] }
        for slot in 0..<6 {
            let k = order[slot]
            guard k >= 0 && k < 6, enabled[k] else { continue }
            switch k {
            case 0: filter(left, right, frames)
            case 1: reverb(left, right, frames)
            case 2: delay(left, right, frames)
            case 3: distortion(left, right, frames)
            case 4: chorus(left, right, frames)
            default: phaser(left, right, frames)
            }
        }
        for i in 0..<frames {
            left[i] = max(-1, min(1, left[i]))
            right[i] = max(-1, min(1, right[i]))
        }
    }

    private func filter(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let hz = filterFreq
        let f = min(0.95, 2 * sinf(.pi * min(hz, sr * 0.24) / sr))
        let q = 1 - filterRes * 0.92
        for i in 0..<n {
            for ch in 0..<2 {
                let x = ch == 0 ? l[i] : r[i]
                var low = ch == 0 ? fLow.0 : fLow.1
                var band = ch == 0 ? fBand.0 : fBand.1
                // two iterations for stability at high cutoffs
                for _ in 0..<2 {
                    low += f * band
                    let high = x - low - q * band
                    band += f * high
                }
                let high = x - low - q * band
                let y: Float = filterType == 0 ? low : (filterType == 1 ? band : high)
                if ch == 0 { fLow.0 = low; fBand.0 = band; l[i] = y } else { fLow.1 = low; fBand.1 = band; r[i] = y }
            }
        }
    }

    private func distortion(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let drive = 1 + driveAmount * 30
        let comp = 1 / (1 + driveAmount * 2.5)
        let a = 0.05 + driveTone * 0.9
        for i in 0..<n {
            let xl = l[i], xr = r[i]
            var yl = tanhf(xl * drive) * comp
            var yr = tanhf(xr * drive) * comp
            dLP.0 += a * (yl - dLP.0); dLP.1 += a * (yr - dLP.1)
            yl = dLP.0; yr = dLP.1
            l[i] = yl * driveLevel * 1.4
            r[i] = yr * driveLevel * 1.4
        }
    }

    private func readFrac(_ b: UnsafeMutablePointer<Float>, _ len: Int, _ w: Int, _ d: Float) -> Float {
        var pos = Float(w) - d
        while pos < 0 { pos += Float(len) }
        let i0 = Int(pos) % len
        let i1 = (i0 + 1) % len
        let fr = pos - floorf(pos)
        return b[i0] + (b[i1] - b[i0]) * fr
    }

    private func chorus(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let rate = 0.1 + chorusRate * 2.9
        let base = 0.012 * sr
        let depth = chorusDepth * 0.006 * sr
        for i in 0..<n {
            chBufL[chW] = l[i]; chBufR[chW] = r[i]
            chPhase += rate / sr; if chPhase >= 1 { chPhase -= 1 }
            let m1 = sinf(2 * .pi * chPhase), m2 = sinf(2 * .pi * (chPhase + 0.25))
            let wl = readFrac(chBufL, chLen, chW, base + depth * (1 + m1) / 2 + 1)
            let wr = readFrac(chBufR, chLen, chW, base + depth * (1 + m2) / 2 + 1)
            l[i] = l[i] * (1 - chorusMix * 0.5) + wl * chorusMix
            r[i] = r[i] * (1 - chorusMix * 0.5) + wr * chorusMix
            chW = (chW + 1) % chLen
        }
    }

    private func phaser(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let rate = 0.05 + phaserRate * 2
        for i in 0..<n {
            phPhase += rate / sr; if phPhase >= 1 { phPhase -= 1 }
            for ch in 0..<2 {
                let lfo = 0.5 + 0.5 * sinf(2 * .pi * (phPhase + Float(ch) * 0.2))
                let hz = 200 + lfo * phaserDepth * 3800
                let t = tanf(.pi * hz / sr)
                let a = (t - 1) / (t + 1)
                let x = ch == 0 ? l[i] : r[i]
                var y = x + (ch == 0 ? phLast.0 : phLast.1) * phaserFeedback * 0.7
                for s in 0..<6 {
                    let zi = ch * 6 + s
                    let out = a * y + phZ[zi]
                    phZ[zi] = y - a * out
                    y = out
                }
                if ch == 0 { phLast.0 = y; l[i] = x * (1 - phaserMix * 0.5) + y * phaserMix }
                else { phLast.1 = y; r[i] = x * (1 - phaserMix * 0.5) + y * phaserMix }
            }
        }
    }

    private func delay(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let a = 0.1 + delayTone * 0.85
        for i in 0..<n {
            dlTimeSmooth += (max(0.02, min(1.2, delayTime)) - dlTimeSmooth) * 0.0005
            let d = dlTimeSmooth * sr
            let yl = readFrac(dlL, dlLen, dlW, d)
            let yr = readFrac(dlR, dlLen, dlW, d * 0.75 + 0.25 * d)
            dlTone.0 += a * (yl - dlTone.0); dlTone.1 += a * (yr - dlTone.1)
            // ping-pong-ish cross feedback
            dlL[dlW] = l[i] + dlTone.1 * delayFeedback * 0.95
            dlR[dlW] = r[i] + dlTone.0 * delayFeedback * 0.95
            l[i] += yl * delayMix
            r[i] += yr * delayMix
            dlW = (dlW + 1) % dlLen
        }
    }

    private func reverb(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, _ n: Int) {
        let fb = 0.7 + reverbSize * 0.28
        let damp = reverbDamp * 0.4
        let wet = reverbMix
        for i in 0..<n {
            let input = (l[i] + r[i]) * 0.015
            var outL: Float = 0, outR: Float = 0
            var k = 0
            while k < combs.count {
                outL += combs[k].process(input, feedback: fb, damp: damp)
                outR += combs[k + 1].process(input, feedback: fb, damp: damp)
                k += 2
            }
            k = 0
            while k < allpasses.count {
                outL = allpasses[k].process(outL)
                outR = allpasses[k + 1].process(outR)
                k += 2
            }
            l[i] = l[i] * (1 - wet * 0.4) + outL * wet * 3
            r[i] = r[i] * (1 - wet * 0.4) + outR * wet * 3
        }
    }
}
