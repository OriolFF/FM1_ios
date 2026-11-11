import Foundation

/// Native master section for package firmwares: sidechain DUCK (kick → synths), DUST
/// (bit/rate reduction + crackle), a DJ FILTER (low-pass ← off → high-pass) and one
/// tempo-synced punch-in effect at a time (`Punch`). Mono, like the FM-1's voice bus;
/// the host's stereo FX chain follows it.
final class MasterBus {
    enum Punch: Int, CaseIterable {
        case off, repeatLoop, reverse, tapeStop, halfSpeed, lpSweep, hpSweep, crush, gate, echo, killLow, killMid, killHigh, stutter
        static let names = ["OFF", "REPEAT", "REVERSE", "TAPE STOP", "HALF SPEED", "LP SWEEP", "HP SWEEP", "CRUSH", "GATE", "ECHO", "KILL LOW", "KILL MID", "KILL HIGH", "STUTTER"]
        static func named(_ s: String) -> Punch? { names.firstIndex(of: s.uppercased()).flatMap { Punch(rawValue: $0) } }
    }

    // main thread writes, audio reads
    var filter: Float = 0          // -1...1
    var dust: Float = 0            // 0...1
    var duck: Float = 0            // 0...1
    var punch: Punch = .off
    var punchBeats: Float = 0.25   // loop / gate length in beats
    var tempo: Double = 120
    /// Bumped by the main thread every time a punch is (re)pressed so the audio side re-captures.
    var punchSerial: UInt32 = 0

    private let sr: Float
    private let ringSize: Int
    private let ring: UnsafeMutablePointer<Float>
    private var write = 0
    private var frozen = false
    private var activePunch: Punch = .off
    private var seenSerial: UInt32 = 0
    private var loopStart = 0, loopLen = 1, loopPos = 0
    private var readPos: Double = 0, rate: Double = 1
    private var sweep: Float = 0
    private var holdS: Float = 0, holdCount = 0
    private var crushS: Float = 0, crushCount = 0
    private var gatePhase: Double = 0
    private let echo: UnsafeMutablePointer<Float>
    private let echoSize: Int
    private var echoW = 0
    private var lpA: Float = 0, lpB: Float = 0, hpA: Float = 0
    private var fic1: Float = 0, fic2: Float = 0
    private var duckEnv: Float = 0
    private var duckTrig: UInt32 = 0, duckSeen: UInt32 = 0
    private var rng: UInt32 = 0xC0FF_EE11
    private var xfade: Float = 1

    init(sampleRate: Float) {
        sr = sampleRate
        ringSize = Int(sampleRate * 4)
        ring = .allocate(capacity: ringSize); ring.initialize(repeating: 0, count: ringSize)
        echoSize = Int(sampleRate * 1.5)
        echo = .allocate(capacity: echoSize); echo.initialize(repeating: 0, count: echoSize)
    }
    deinit { ring.deallocate(); echo.deallocate() }

    /// Any thread: a kick hit (drum lane 0) for DUCK.
    func kick() { duckTrig &+= 1 }

    @inline(__always) private func noise() -> Float {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / 2147483648
    }

    @inline(__always) private func ringAt(_ i: Int) -> Float { ring[((i % ringSize) + ringSize) % ringSize] }

    /// `synth` and `drums` are this block's buses; the result is written to `out`.
    func process(synth: UnsafeMutablePointer<Float>, drums: UnsafeMutablePointer<Float>, out: UnsafeMutablePointer<Float>, frames n: Int) {
        if duckTrig != duckSeen { duckSeen = duckTrig; duckEnv = 1 }
        let duckAmt = min(max(duck, 0), 1)
        let duckC = expf(-1 / (0.16 * sr))
        let beat = Double(sr) * 60 / max(tempo, 20)

        // punch state changes
        let want = punch
        if want != activePunch || punchSerial != seenSerial {
            seenSerial = punchSerial
            activePunch = want
            xfade = 0
            frozen = false
            switch want {
            case .repeatLoop, .reverse, .stutter:
                loopLen = max(64, min(ringSize / 2, Int(Double(want == .stutter ? min(punchBeats, 0.125) : punchBeats) * beat)))
                loopStart = write - loopLen
                loopPos = 0
                frozen = true
            case .tapeStop, .halfSpeed:
                readPos = Double(write - 1); rate = 1
            case .lpSweep, .hpSweep: sweep = 0
            case .gate: gatePhase = 0
            default: break
            }
        }
        let p = activePunch
        let dustA = min(max(dust, 0), 1)
        let bits = 16 - dustA * 10
        let q = powf(2, bits - 1)
        let holdN = 1 + Int(dustA * 5)
        // DJ filter / sweep coefficients (block rate)
        var filt = filter
        if p == .lpSweep { sweep = min(1, sweep + Float(n) / Float(beat * 4)); filt = min(filt, -sweep * 0.95) }
        if p == .hpSweep { sweep = min(1, sweep + Float(n) / Float(beat * 4)); filt = max(filt, sweep * 0.9) }
        let lowPass = filt < -0.01, highPass = filt > 0.01
        let fc: Float = lowPass ? 20000 * powf(0.01, -filt) : (highPass ? 20 * powf(150, filt) : 1000)
        let g = tanf(Float.pi * min(fc, sr * 0.45) / sr)
        let k: Float = 1.2
        let a1 = 1 / (1 + g * (g + k)), a2 = g * a1, a3 = g * a2
        let killLowC = 1 - expf(-2 * Float.pi * 250 / sr)
        let killHighC = 1 - expf(-2 * Float.pi * 2500 / sr)
        let echoDelay = Int(min(Double(echoSize - 1), beat * 0.75))

        for i in 0..<n {
            duckEnv *= duckC
            var x = synth[i] * (1 - duckAmt * duckEnv * 0.85) + drums[i]
            if !frozen { ring[write % ringSize] = x; write = (write + 1) % (ringSize * 64) }
            var y = x
            switch p {
            case .repeatLoop, .stutter:
                y = ringAt(loopStart + loopPos)
                loopPos += 1; if loopPos >= loopLen { loopPos = 0 }
            case .reverse:
                y = ringAt(loopStart + loopLen - 1 - loopPos)
                loopPos += 1; if loopPos >= loopLen { loopPos = 0 }
            case .tapeStop:
                rate = max(0, rate - 1 / (Double(sr) * 0.9))
                readPos += rate
                let i0 = Int(readPos), fr = Float(readPos - Double(i0))
                y = (ringAt(i0) * (1 - fr) + ringAt(i0 + 1) * fr) * Float(min(1, rate * 3))
            case .halfSpeed:
                readPos += 0.5
                if Double(write) - readPos > Double(ringSize - 16) { readPos = Double(write - 1) }
                let i0 = Int(readPos), fr = Float(readPos - Double(i0))
                y = ringAt(i0) * (1 - fr) + ringAt(i0 + 1) * fr
            case .crush:
                crushCount += 1
                if crushCount >= 8 { crushCount = 0; crushS = (x * 8).rounded() / 8 }
                y = crushS
            case .gate:
                gatePhase += 1 / (Double(punchBeats) * beat)
                if gatePhase >= 1 { gatePhase -= 1 }
                y = x * (gatePhase < 0.5 ? 1 : 0.0)
            case .killLow:
                lpA += (x - lpA) * killLowC; y = x - lpA
            case .killHigh:
                lpB += (x - lpB) * killHighC; y = lpB
            case .killMid:
                lpA += (x - lpA) * killLowC
                hpA += (x - hpA) * killHighC
                y = lpA + (x - hpA)
            default: break
            }
            // echo send (ECHO throw: send while held, tail always)
            let rd = (echoW - echoDelay + echoSize) % echoSize
            let e = echo[rd]
            echo[echoW] = (p == .echo ? x : 0) + e * 0.55
            echoW = (echoW + 1) % echoSize
            y += e * 0.7
            // crossfade into punch changes (declick)
            if xfade < 1 { xfade = min(1, xfade + 1 / (0.004 * sr)); y = x + (y - x) * xfade }
            // DUST: sample-hold + bit reduction + crackle
            if dustA > 0.001 {
                holdCount += 1
                if holdCount >= holdN { holdCount = 0; holdS = (y * q).rounded() / q }
                y = holdS
                if noise() > 1 - dustA * 0.0015 { y += noise() * 0.25 * dustA }
            }
            // DJ filter
            if lowPass || highPass {
                let v3 = y - fic2
                let v1 = a1 * fic1 + a2 * v3
                let v2 = fic2 + a2 * fic1 + a3 * v3
                fic1 = 2 * v1 - fic1; fic2 = 2 * v2 - fic2
                y = lowPass ? v2 : y - k * v1 - v2
            }
            x = y
            out[i] = x > 1 ? 1 : (x < -1 ? -1 : x)
        }
    }
}
