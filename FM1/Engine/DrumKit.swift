import Foundation

// MARK: - DSP helpers (file-private, original implementation)

/// Topology-preserving-transform state-variable filter. Coefficients are set at
/// trigger time only, so the per-sample cost is a handful of multiply-adds.
fileprivate struct DKFilter {
    var k: Float = 1, a1: Float = 0, a2: Float = 0, a3: Float = 0
    var ic1: Float = 0, ic2: Float = 0

    mutating func set(_ fc: Float, q: Float, sr: Float) {
        let f = min(max(fc, 10), sr * 0.45)
        let g = tanf(Float.pi * f / sr)
        k = 1 / max(q, 0.05)
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        ic1 = 0; ic2 = 0
    }
    @inline(__always) mutating func lp(_ x: Float) -> Float { tick(x).0 }
    /// Band-pass normalised to unity gain at the centre frequency.
    @inline(__always) mutating func bp(_ x: Float) -> Float { k * tick(x).1 }
    @inline(__always) mutating func hp(_ x: Float) -> Float { let r = tick(x); return x - k * r.1 - r.0 }
    @inline(__always) mutating func tick(_ x: Float) -> (Float, Float) {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        return (v2, v1)
    }
}

/// sin(2π·p) for p in [0,1): parabola plus one correction step (~0.1 % error).
@inline(__always) fileprivate func dkSin(_ p: Float) -> Float {
    var x = 2 * p
    if x > 1 { x -= 2 }
    let y = 4 * x * (1 - abs(x))
    return 0.225 * (y * abs(y) - y) + y
}

/// Rational tanh approximation, exact ±1 beyond |x| = 3.
@inline(__always) fileprivate func dkTanh(_ x: Float) -> Float {
    if x > 3 { return 1 }
    if x < -3 { return -1 }
    let x2 = x * x
    return x * (27 + x2) / (27 + 9 * x2)
}

/// PolyBLEP correction for a naive square edge.
@inline(__always) fileprivate func dkBlep(_ t: Float, _ dt: Float) -> Float {
    if t < dt { let u = t / dt; return u + u - u * u - 1 }
    if t > 1 - dt { let u = (t - 1) / dt; return u * u + u + u + 1 }
    return 0
}

@inline(__always) fileprivate func dkSquareBL(_ p: Float, _ dt: Float) -> Float {
    var s: Float = p < 0.5 ? 1 : -1
    s += dkBlep(p, dt)
    var q = p + 0.5; if q >= 1 { q -= 1 }
    s -= dkBlep(q, dt)
    return s
}

/// Per-lane voice state. One generic struct for all eleven instruments; each
/// instrument uses the fields it needs.
fileprivate struct DKVoice {
    var active = false
    var t = 0                        // samples since trigger
    var gain: Float = 0              // level × velocity × instrument trim
    // oscillators (phase 0..<1, increment per sample)
    var p0: Float = 0, p1: Float = 0, p2: Float = 0, p3: Float = 0, p4: Float = 0, p5: Float = 0
    var i0: Float = 0, i1: Float = 0, i2: Float = 0, i3: Float = 0, i4: Float = 0, i5: Float = 0
    // pitch envelope
    var pe: Float = 0, peC: Float = 0, depth: Float = 0
    // amplitude envelopes and their per-sample multipliers
    var e1: Float = 0, c1: Float = 0, e2: Float = 0, c2: Float = 0, e3: Float = 0, c3: Float = 0
    // misc per-instrument values
    var a: Float = 0, b: Float = 0, drive: Float = 1, driveNorm: Float = 1
    var stage = 0, nextStage = 0
    var f1 = DKFilter(), f2 = DKFilter(), f3 = DKFilter()
    // choke + declick
    var choking = false, chokeGain: Float = 1
    var residual: Float = 0, lastOut: Float = 0
}

// MARK: - DrumKit

/// Realtime 11-voice analog-808-style drum synthesiser.
/// Voices are monophonic per lane; parameters are latched when a voice is triggered.
final class DrumKit: @unchecked Sendable {
    static let laneCount = 11
    static let names: [String] = ["KICK", "SNARE", "LO TOM", "MID TOM", "HI TOM", "RIM", "CLAP",
                                  "COWBELL", "CYMBAL", "OPEN HAT", "CL HAT"]
    static let shortNames: [String] = ["BD", "SD", "LT", "MT", "HT", "RM", "CP", "CB", "CY", "OH", "CH"]
    static let paramNames: [String] = ["Level", "Tune", "Decay", "Tone"]

    /// lane*4 + p, values 0...127 (64 = default/neutral; Level default 100). UI thread writes, audio reads.
    let params: UnsafeMutablePointer<UInt8>
    var kitLevel: Float = 0.8
    var accent: Float = 0.7
    var chokeHats = true
    /// Per-lane activity 0...1 for LEDs.
    let laneMeter: UnsafeMutablePointer<Float>

    private let sr: Float
    private let invSr: Float
    private let voices: UnsafeMutablePointer<DKVoice>
    private static let chunk = 256
    private let mix: UnsafeMutablePointer<Float>
    private let lanePeak: UnsafeMutablePointer<Float>
    /// Preview mailbox: one 32-bit word per lane, (sequence << 8) | velocity.
    /// Written with a single aligned store by the UI, read by the audio thread.
    private let previewBox: UnsafeMutablePointer<UInt32>
    private let previewSeen: UnsafeMutablePointer<UInt32>
    private var rng: UInt32 = 0x1234_5678
    private let declickC: Float
    private let chokeC: Float
    private let meterC: Float

    private static let metal: [Float] = [207, 307, 370, 524, 544, 807]

    init(sampleRate: Float) {
        sr = max(8000, sampleRate)
        invSr = 1 / sr
        params = .allocate(capacity: DrumKit.laneCount * 4)
        laneMeter = .allocate(capacity: DrumKit.laneCount)
        laneMeter.initialize(repeating: 0, count: DrumKit.laneCount)
        voices = .allocate(capacity: DrumKit.laneCount)
        voices.initialize(repeating: DKVoice(), count: DrumKit.laneCount)
        mix = .allocate(capacity: DrumKit.chunk)
        mix.initialize(repeating: 0, count: DrumKit.chunk)
        lanePeak = .allocate(capacity: DrumKit.laneCount)
        lanePeak.initialize(repeating: 0, count: DrumKit.laneCount)
        previewBox = .allocate(capacity: DrumKit.laneCount)
        previewBox.initialize(repeating: 0, count: DrumKit.laneCount)
        previewSeen = .allocate(capacity: DrumKit.laneCount)
        previewSeen.initialize(repeating: 0, count: DrumKit.laneCount)
        declickC = expf(-1 / (0.0015 * sr))
        chokeC = expf(-1 / (0.004 * sr))
        meterC = expf(-Float(DrumKit.chunk) / (0.12 * sr))
        resetParams()
    }

    deinit {
        params.deallocate()
        laneMeter.deallocate()
        voices.deinitialize(count: DrumKit.laneCount)
        voices.deallocate()
        mix.deallocate()
        lanePeak.deallocate()
        previewBox.deallocate()
        previewSeen.deallocate()
    }

    func resetParams() {
        for l in 0..<DrumKit.laneCount {
            params[l * 4] = 100
            params[l * 4 + 1] = 64
            params[l * 4 + 2] = 64
            params[l * 4 + 3] = 64
        }
    }

    // MARK: preview (any thread)

    func preview(_ lane: Int, velocity: Int) {
        guard lane >= 0 && lane < DrumKit.laneCount else { return }
        let old = previewBox[lane]
        let seq = ((old >> 8) &+ 1) & 0x00FF_FFFF
        previewBox[lane] = (seq << 8) | UInt32(max(1, min(127, velocity)))
    }

    // MARK: trigger (audio thread)

    @inline(__always) private func coef(_ tau: Float) -> Float { expf(-1 / (max(tau, 0.0002) * sr)) }

    func trigger(_ lane: Int, velocity: Int) {
        guard lane >= 0 && lane < DrumKit.laneCount else { return }
        let vel = Float(max(1, min(127, velocity))) / 127
        let acc = min(max(accent, 0), 1)
        let vg = (1 - acc) + acc * vel
        let p = params + lane * 4
        let lv = Float(min(p[0], 127)) / 100
        let level = lv * lv
        let tune = exp2f((Float(min(p[1], 127)) - 64) / 64)
        let dec = powf(4, (Float(min(p[2], 127)) - 64) / 64)
        let tone = Float(min(p[3], 127)) / 127

        if lane == 10 && chokeHats && voices[9].active && !voices[9].choking {
            voices[9].choking = true
        }

        let old = voices[lane]
        var v = DKVoice()
        v.residual = old.active ? old.lastOut : old.residual
        v.active = true
        v.gain = level * vg

        switch lane {
        case 0: // KICK — swept sine with fast pitch drop, click burst, tanh drive
            let f0 = 49 * tune
            v.i0 = f0 * invSr
            v.depth = 1.6 + 5.5 * tone * tone
            v.pe = 1; v.peC = coef(0.0065)
            v.e1 = 1; v.c1 = coef(0.21 * dec)
            v.e2 = 1; v.c2 = coef(0.0007)
            v.a = 0.5 * tone                              // click amount
            v.f1.set(2600 + 2400 * tone, q: 0.8, sr: sr)  // click colour
            v.drive = 1 + 2.2 * tone
            v.driveNorm = 1 / dkTanh(v.drive)
            v.gain *= 0.84
        case 1: // SNARE — two damped modes + filtered noise ("snappy")
            v.i0 = 180 * tune * invSr
            v.i1 = 332 * tune * invSr
            v.depth = 0.35; v.pe = 1; v.peC = coef(0.008)
            v.e1 = 1; v.c1 = coef(0.055 * dec)
            v.e2 = 1; v.c2 = coef(0.032 * dec)
            v.e3 = 1; v.c3 = coef(0.07 * dec)
            v.a = 0.15 + 1.35 * tone                      // snappy noise amount
            v.b = 1 - 0.35 * tone                         // body amount
            v.f1.set(1500 * tune.squareRoot(), q: 0.7, sr: sr)
            v.f2.set(9000, q: 0.6, sr: sr)
            v.gain *= 0.62
        case 2, 3, 4: // TOMS — sine with downward pitch sweep, tone = saturation + stick noise
            let base: Float = lane == 2 ? 88 : (lane == 3 ? 128 : 178)
            let tau: Float = lane == 2 ? 0.17 : (lane == 3 ? 0.14 : 0.115)
            v.i0 = base * tune * invSr
            v.depth = 0.55; v.pe = 1; v.peC = coef(0.06)
            v.e1 = 1; v.c1 = coef(tau * dec)
            v.e2 = 1; v.c2 = coef(0.003)
            v.a = 0.06 + 0.3 * tone
            v.f1.set(base * tune * 12, q: 0.8, sr: sr)
            v.drive = 1 + 3 * tone
            v.driveNorm = 1 / dkTanh(v.drive)
            v.gain *= 0.6
        case 5: // RIM — two short sines + noise click, high-passed and lightly clipped
            v.i0 = 470 * tune * invSr
            v.i1 = 1690 * tune * invSr
            v.e1 = 1; v.c1 = coef(0.011 * dec)
            v.e2 = 1; v.c2 = coef(0.0065 * dec)
            v.e3 = 1; v.c3 = coef(0.0009)
            v.a = 0.2 + 0.8 * tone                        // click
            v.b = 0.3 + 0.7 * tone                        // upper mode
            v.f1.set(2500 + 3000 * tone, q: 0.7, sr: sr)
            v.f2.set(180 + 400 * tone, q: 0.7, sr: sr)
            v.gain *= 0.5
        case 6: // CLAP — 3 fast bursts ~11 ms apart then a band-passed tail
            v.f1.set(1150 * tune * (0.8 + 0.5 * tone), q: 1.7, sr: sr)
            v.f2.set(420, q: 0.7, sr: sr)
            v.e1 = 1; v.c1 = coef(0.0032)                 // burst env
            v.c2 = coef((0.045 + 0.18 * tone) * dec)      // tail env
            v.stage = 0
            v.nextStage = Int(0.0105 * sr)
            v.a = Float(Int(0.0105 * sr))
            v.gain *= 1.1
        case 7: // COWBELL — two band-limited squares 540/800 Hz through a BPF, two-stage env
            v.i0 = 540 * tune * invSr
            v.i1 = 800 * tune * invSr
            v.f1.set(2000 * tune.squareRoot() * (0.55 + 0.9 * tone), q: 1.3, sr: sr)
            v.f2.set(320, q: 0.7, sr: sr)
            v.e1 = 1; v.c1 = coef(0.009)
            v.e2 = 1; v.c2 = coef(0.11 * dec)
            v.gain *= 0.62
        case 8, 9, 10: // CYMBAL / OPEN HAT / CLOSED HAT — six square "metal" oscillators
            let m = DrumKit.metal
            v.i0 = m[0] * tune * invSr; v.i1 = m[1] * tune * invSr; v.i2 = m[2] * tune * invSr
            v.i3 = m[3] * tune * invSr; v.i4 = m[4] * tune * invSr; v.i5 = m[5] * tune * invSr
            // decorrelated start phases avoid an identical "tick" on every hit
            v.p0 = 0.13; v.p1 = 0.71; v.p2 = 0.37; v.p3 = 0.59; v.p4 = 0.05; v.p5 = 0.83
            let bright = (0.55 + 1.0 * tone) * tune.squareRoot()
            if lane == 8 {
                v.f1.set(3400 * bright, q: 1.6, sr: sr)   // low band
                v.f2.set(7600 * bright, q: 0.7, sr: sr)   // high band
                v.f3.set(2200 * bright, q: 0.7, sr: sr)
                v.e1 = 1; v.c1 = coef(0.16 * dec)
                v.e2 = 1; v.c2 = coef(0.42 * dec)
                v.e3 = 1; v.c3 = coef(0.0015)
                v.gain *= 0.62
            } else {
                v.f1.set(8800 * bright, q: 1.1, sr: sr)
                v.f2.set(6400 * bright, q: 0.7, sr: sr)
                v.e1 = 1; v.c1 = coef((lane == 9 ? 0.11 : 0.013) * dec)
                v.e2 = 1; v.c2 = coef(0.0012)
                v.gain *= lane == 9 ? 0.8 : 0.95
            }
        default: break
        }
        voices[lane] = v
    }

    // MARK: render (audio thread)

    func render(frames: Int, out: UnsafeMutablePointer<Float>) {
        guard frames > 0 else { return }
        // consume preview requests
        for l in 0..<DrumKit.laneCount {
            let box = previewBox[l]
            let seq = box >> 8
            if seq != previewSeen[l] {
                previewSeen[l] = seq
                trigger(l, velocity: Int(box & 0xFF))
            }
        }
        for l in 0..<DrumKit.laneCount { lanePeak[l] = 0 }

        let kl = min(max(kitLevel, 0), 1.5)
        var done = 0
        while done < frames {
            let n = min(DrumKit.chunk, frames - done)
            mix.update(repeating: 0, count: n)
            for l in 0..<DrumKit.laneCount where voices[l].active || voices[l].residual != 0 {
                let pk = renderLane(l, &voices[l], n)
                if pk > lanePeak[l] { lanePeak[l] = pk }
            }
            let o = out + done
            for i in 0..<n {
                var x = mix[i] * kl
                // linear up to 0.6, then a smooth knee that saturates at 1.0
                let ax = abs(x)
                if ax > 0.6 {
                    let y = 0.6 + 0.4 * dkTanh((ax - 0.6) * 2.5)
                    x = x < 0 ? -y : y
                }
                o[i] += x
            }
            done += n
        }
        // LED meters (approximate, decaying)
        let blocks = Float(max(1, frames / DrumKit.chunk))
        let fall = powf(meterC, blocks)
        for l in 0..<DrumKit.laneCount {
            let target = min(1, lanePeak[l] * 1.6)
            let m = laneMeter[l] * fall
            laneMeter[l] = target > m ? target : (m < 0.001 ? 0 : m)
        }
    }

    @inline(__always) private func noise(_ s: inout UInt32) -> Float {
        s ^= s << 13; s ^= s >> 17; s ^= s << 5
        return Float(Int32(bitPattern: s)) * (1.0 / 2147483648.0)
    }

    /// Common output stage: gain, choke fade, declick residual. Returns the sample.
    @inline(__always) private func finish(_ v: inout DKVoice, _ s: Float) -> Float {
        var y = s * v.gain
        if v.choking { v.chokeGain *= chokeC; y *= v.chokeGain }
        y += v.residual
        v.residual *= declickC
        v.lastOut = y
        return y
    }

    /// Renders one lane's chunk, adding into `mix`; returns peak |sample|.
    private func renderLane(_ lane: Int, _ v: inout DKVoice, _ n: Int) -> Float {
        var r = rng
        defer { rng = r }
        var peak: Float = 0
        let mix = self.mix
        if !v.active {
            // only a declick residual is left
            for i in 0..<n {
                let y = v.residual
                v.residual *= declickC
                mix[i] += y
            }
            if abs(v.residual) < 1e-6 { v.residual = 0 }
            return 0
        }

        switch lane {
        case 0: // KICK
            for i in 0..<n {
                let inc = v.i0 * (1 + v.depth * v.pe)
                v.pe *= v.peC
                v.p0 += inc; if v.p0 >= 1 { v.p0 -= 1 }
                var s = dkSin(v.p0) * v.e1
                v.e1 *= v.c1
                if v.e2 > 1e-4 {
                    s += v.f1.lp(noise(&r)) * v.e2 * v.a
                    v.e2 *= v.c2
                }
                s = dkTanh(s * v.drive) * v.driveNorm
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.e1 < 1e-4 { v.active = false }

        case 1: // SNARE
            for i in 0..<n {
                let pm = 1 + v.depth * v.pe
                v.pe *= v.peC
                v.p0 += v.i0 * pm; if v.p0 >= 1 { v.p0 -= 1 }
                v.p1 += v.i1 * pm; if v.p1 >= 1 { v.p1 -= 1 }
                let body = (dkSin(v.p0) * v.e1 + 0.55 * dkSin(v.p1) * v.e2) * v.b
                v.e1 *= v.c1; v.e2 *= v.c2
                let nz = v.f2.lp(v.f1.hp(noise(&r))) * v.e3 * v.a
                v.e3 *= v.c3
                let s = dkTanh(1.3 * (body + nz))
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.e1 < 1e-4 && v.e3 < 1e-4 { v.active = false }

        case 2, 3, 4: // TOMS
            for i in 0..<n {
                v.p0 += v.i0 * (1 + v.depth * v.pe); if v.p0 >= 1 { v.p0 -= 1 }
                v.pe *= v.peC
                var s = dkSin(v.p0) * v.e1
                v.e1 *= v.c1
                if v.e2 > 1e-4 {
                    s += v.f1.lp(noise(&r)) * v.e2 * v.a
                    v.e2 *= v.c2
                }
                s = dkTanh(s * v.drive) * v.driveNorm
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.e1 < 1e-4 { v.active = false }

        case 5: // RIM
            for i in 0..<n {
                v.p0 += v.i0; if v.p0 >= 1 { v.p0 -= 1 }
                v.p1 += v.i1; if v.p1 >= 1 { v.p1 -= 1 }
                var s = dkSin(v.p0) * v.e1 + v.b * dkSin(v.p1) * v.e2
                v.e1 *= v.c1; v.e2 *= v.c2
                s += v.f1.hp(noise(&r)) * v.e3 * v.a
                v.e3 *= v.c3
                s = dkTanh(1.8 * v.f2.hp(s))
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.e1 < 1e-4 && v.e2 < 1e-4 { v.active = false }

        case 6: // CLAP
            for i in 0..<n {
                if v.t >= v.nextStage && v.stage < 3 {
                    v.stage += 1
                    v.nextStage += Int(v.a)
                    if v.stage < 3 { v.e1 = 1 } else { v.e1 = 0; v.e2 = 1 }
                }
                let env = v.e1 + v.e2
                v.e1 *= v.c1; v.e2 *= v.c2
                let s = v.f2.hp(v.f1.bp(noise(&r))) * env * 1.6
                v.t += 1
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.stage >= 3 && v.e2 < 1e-4 { v.active = false }

        case 7: // COWBELL
            for i in 0..<n {
                let sq = 0.5 * (dkSquareBL(v.p0, v.i0) + dkSquareBL(v.p1, v.i1))
                v.p0 += v.i0; if v.p0 >= 1 { v.p0 -= 1 }
                v.p1 += v.i1; if v.p1 >= 1 { v.p1 -= 1 }
                let env = 0.55 * v.e1 + 0.45 * v.e2
                v.e1 *= v.c1; v.e2 *= v.c2
                let s = dkTanh(1.6 * v.f2.hp(v.f1.bp(sq))) * env
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if v.e2 < 1e-4 { v.active = false }

        case 8, 9, 10: // METAL: CYMBAL / OPEN HAT / CLOSED HAT
            let cym = lane == 8
            for i in 0..<n {
                var m: Float = v.p0 < 0.5 ? 1 : -1
                m += v.p1 < 0.5 ? 1 : -1
                m += v.p2 < 0.5 ? 1 : -1
                m += v.p3 < 0.5 ? 1 : -1
                m += v.p4 < 0.5 ? 1 : -1
                m += v.p5 < 0.5 ? 1 : -1
                v.p0 += v.i0; if v.p0 >= 1 { v.p0 -= 1 }
                v.p1 += v.i1; if v.p1 >= 1 { v.p1 -= 1 }
                v.p2 += v.i2; if v.p2 >= 1 { v.p2 -= 1 }
                v.p3 += v.i3; if v.p3 >= 1 { v.p3 -= 1 }
                v.p4 += v.i4; if v.p4 >= 1 { v.p4 -= 1 }
                v.p5 += v.i5; if v.p5 >= 1 { v.p5 -= 1 }
                m *= (1.0 / 6.0)
                let s: Float
                if cym {
                    let x = m + 0.12 * noise(&r)
                    let lo = v.f3.hp(v.f1.bp(x)) * v.e1
                    let hi = v.f2.hp(x) * v.e2
                    // short attack ramp softens the initial edge
                    let att = 1 - v.e3
                    v.e1 *= v.c1; v.e2 *= v.c2; v.e3 *= v.c3
                    s = dkTanh(1.5 * (0.8 * lo + hi) * att)
                } else {
                    let x = m + 0.15 * noise(&r)
                    let att = 1 - v.e2
                    s = dkTanh(2.2 * v.f2.hp(v.f1.bp(x))) * v.e1 * att
                    v.e1 *= v.c1; v.e2 *= v.c2
                }
                let y = finish(&v, s)
                mix[i] += y
                peak = max(peak, abs(y))
            }
            if cym ? (v.e1 < 1e-4 && v.e2 < 1e-4) : (v.e1 < 1e-4) { v.active = false }

        default:
            v.active = false
        }

        if v.choking && v.chokeGain < 1e-4 { v.active = false }
        if !v.active {
            // Voice finished: keep only the residual (already 0-ish for natural decays).
            v.residual = v.lastOut
            v.lastOut = 0
        }
        if abs(v.residual) < 1e-7 { v.residual = 0 }
        return peak
    }
}
