import Foundation
import os

/// Realtime 6-operator FM synthesis engine.
///
/// This is a port of the MSFA engine (Google "music-synthesizer-for-android",
/// as used by Dexed and by M-VAVE's FM-1 firmware). Control-rate maths
/// (envelopes, pitch EG, LFO, levels, frequencies) follows MSFA's fixed-point
/// formulas and runs once per 64-sample block; the audio-rate operator kernel
/// is floating point (phase in cycles, 1.0 operator output = 1 cycle of phase
/// modulation, exactly MSFA's Q24 convention).
///
/// The audio thread only touches preallocated unsafe buffers. The UI thread
/// edits the shared patch bytes directly (single-byte writes are benign races)
/// and posts note events through a small lock-protected queue that the audio
/// thread drains with `withLockIfAvailable` (never blocks).
final class FMEngine: @unchecked Sendable {

    // MARK: Public configuration (read on the audio thread)
    var masterVolume: Float = 0.8
    var bendUp: Float = 2              // semitones
    var bendDown: Float = 2
    /// bit n = operator n+1 muted
    var opMuteMask: Int = 0
    /// Mono glide time in seconds (0 = off) and mode
    var glideTime: Float = 0
    var glideFingered = false
    /// Global ADSR (FM-1 "ENV"), 0...1 each
    var envOn = false
    var envA: Float = 0, envD: Float = 0.3, envS: Float = 1, envR: Float = 0.2
    let arpSeq = ArpSeq()
    var maxVoices: Int = 12 { didSet { maxVoices = min(max(1, maxVoices), FMEngine.voiceCapacity) } }
    var monoMode = false
    var velocityCurveOn = true          // false → velocity fixed at 100
    var masterTune: Float = 0           // cents

    static let voiceCapacity = 16
    static let blockSize = 64           // MSFA N (control-rate block)

    /// Shared patch bytes (155). UI writes, audio reads.
    let patch: UnsafeMutablePointer<UInt8>

    // MARK: Events
    enum Event { case keyOn(UInt8, UInt8), keyOff(UInt8), noteOn(UInt8, UInt8), noteOff(UInt8), cc(UInt8, UInt8), bend(Int), allOff, panic }
    private struct EventQueue { var items: [Event] = []; init() { items.reserveCapacity(512) } }
    private let queue = OSAllocatedUnfairLock(initialState: EventQueue())
    private var pending: UnsafeMutablePointer<Event>
    private let pendingCap = 512

    // MARK: Per-voice state (structure of arrays)
    private var vActive: UnsafeMutablePointer<Bool>
    private var vNote: UnsafeMutablePointer<Int>        // key as played (for note-off matching)
    private var vMidi: UnsafeMutablePointer<Int>        // key after patch transpose (MSFA "midinote")
    private var vVel: UnsafeMutablePointer<Int>
    private var vKeyDown: UnsafeMutablePointer<Bool>
    private var vSustained: UnsafeMutablePointer<Bool>
    private var vAge: UnsafeMutablePointer<Int>
    private var vPitchLevel: UnsafeMutablePointer<Int>  // pitch EG level, Q24 log2 (tab << 19)
    private var vPitchStage: UnsafeMutablePointer<Int>  // MSFA ix_ (0...4)
    private var vGlide: UnsafeMutablePointer<Float>     // glide offset, semitones (→ 0)
    private var vGlideStep: UnsafeMutablePointer<Float> // semitones per 64-sample block
    private var vAdsr: UnsafeMutablePointer<Float>
    private var vAdsrStage: UnsafeMutablePointer<Int>   // 0 A, 1 D, 2 S, 3 R, 4 done
    private var monoStack = [Int](repeating: 0, count: 16)
    private var monoCount = 0
    private var lastMonoPitch: Float = -1
    // per operator (V*6)
    private var oPhase: UnsafeMutablePointer<Float>     // cycles 0..<1
    private var oEnv: UnsafeMutablePointer<Int>         // env level, Q24 ("actual" << 16)
    private var oStage: UnsafeMutablePointer<Int>       // MSFA ix_ 0...3, 4 = finished
    private var oGain: UnsafeMutablePointer<Float>      // last gain_out (linear)
    // feedback history (2 samples) per voice
    private var fbY0: UnsafeMutablePointer<Float>
    private var fbY1: UnsafeMutablePointer<Float>
    private var ageCounter = 0

    // controllers
    private var bend: Float = 0      // -1...1
    private var wheelCC = 0          // 0...127
    private var sustainPedal = false

    // LFO (global, like MSFA / FM-1): Q32 phase, Q24 outputs
    private var lfoPhase: UInt32 = 0
    private var lfoDelayState: UInt32 = 0
    private var lfoRand: Int = 0

    // output stage
    private var dcX1: Float = 0, dcY1: Float = 0

    // scratch
    private var sine: UnsafeMutablePointer<Float>
    private static let sineSize = 4096
    private let opOut = UnsafeMutablePointer<Float>.allocate(capacity: 6)
    var sampleRate: Float = 48000

    // Scope buffer for the display
    static let scopeSize = 1024
    let scope: UnsafeMutablePointer<Float>
    private(set) var scopeWrite = 0
    /// Number of voices currently sounding (UI may read)
    private(set) var activeVoiceCount = 0
    /// Per-operator envelope level of the most recent voice, 0...1 (for meters)
    let opMeter: UnsafeMutablePointer<Float>

    init() {
        patch = .allocate(capacity: FMPatch.size)
        patch.initialize(from: FMPatch.initVoice.data, count: FMPatch.size)
        pending = .allocate(capacity: pendingCap)
        pending.initialize(repeating: .allOff, count: pendingCap)
        func f(_ n: Int) -> UnsafeMutablePointer<Float> { let p = UnsafeMutablePointer<Float>.allocate(capacity: n); p.initialize(repeating: 0, count: n); return p }
        func i(_ n: Int) -> UnsafeMutablePointer<Int> { let p = UnsafeMutablePointer<Int>.allocate(capacity: n); p.initialize(repeating: 0, count: n); return p }
        func b(_ n: Int) -> UnsafeMutablePointer<Bool> { let p = UnsafeMutablePointer<Bool>.allocate(capacity: n); p.initialize(repeating: false, count: n); return p }
        let V = FMEngine.voiceCapacity
        vActive = b(V); vNote = i(V); vMidi = i(V); vVel = i(V); vKeyDown = b(V); vSustained = b(V); vAge = i(V)
        vPitchLevel = i(V); vPitchStage = i(V); vGlide = f(V); vGlideStep = f(V)
        vAdsr = f(V); vAdsrStage = i(V)
        oPhase = f(V * 6); oEnv = i(V * 6); oStage = i(V * 6); oGain = f(V * 6)
        fbY0 = f(V); fbY1 = f(V)
        for k in 0..<(V * 6) { oStage[k] = 4 }
        sine = f(FMEngine.sineSize + 1)
        for k in 0...FMEngine.sineSize { sine[k] = sinf(2 * .pi * Float(k) / Float(FMEngine.sineSize)) }
        scope = f(FMEngine.scopeSize)
        opMeter = f(6)
        for ptr in [opOut, opInc, opG1, opGStep, opMeterTmp] { ptr.initialize(repeating: 0, count: 6) }
        opOn.initialize(repeating: false, count: 6)
        amFactor.initialize(repeating: 0, count: 4)
        for a in 0..<32 {
            let alg = FMAlgorithm.all[a]
            for o in 0..<6 {
                let mods = alg.modulators[o]
                modCount[a * 6 + o] = mods.count
                for (i, m) in mods.enumerated() { modList[a * 36 + o * 6 + i] = m - 1 }
                carrierMask[a * 6 + o] = alg.isCarrier(o + 1) ? 1 : 0
            }
        }
    }

    /// Notes of voices currently held/sounding (approximate, UI polling).
    func soundingNotes() -> [Int] {
        var r: [Int] = []
        for v in 0..<FMEngine.voiceCapacity where vActive[v] && (vKeyDown[v] || vSustained[v]) { r.append(vNote[v]) }
        return r
    }

    // MARK: Event API (any thread)

    func post(_ e: Event) {
        queue.withLock { q in
            if q.items.count < 500 { q.items.append(e) }
        }
    }
    /// Key events from the keyboard / MIDI (routed through the arpeggiator when it is on).
    func noteOn(_ note: Int, velocity: Int) { post(.keyOn(UInt8(clamping: note), UInt8(clamping: max(1, velocity)))) }
    func noteOff(_ note: Int) { post(.keyOff(UInt8(clamping: note))) }
    func panic() { post(.panic) }
    func controlChange(_ cc: Int, _ value: Int) { post(.cc(UInt8(clamping: cc), UInt8(clamping: value))) }
    func pitchBend(_ value14: Int) { post(.bend(value14)) }
    func allNotesOff() { post(.allOff) }

    func loadPatch(_ p: FMPatch) {
        for k in 0..<FMPatch.size { patch[k] = p.data[k] }
    }

    // MARK: MSFA tables (dx7note.cc, env.cc, pitchenv.cc)

    private static let levelLUT: [Int] = [0, 5, 9, 13, 17, 20, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 42, 43, 45, 46]
    @inline(__always) private static func scaleOutLevel(_ l: Int) -> Int { l >= 20 ? 28 + l : levelLUT[max(0, l)] }

    private static let velocityData: [Int] = [0, 70, 86, 97, 106, 114, 121, 126, 132, 138, 142, 148, 152, 156, 160, 163, 166, 170, 173, 174, 178, 181, 184, 186, 189, 190, 194, 196, 198, 200, 202, 205, 206, 209, 211, 214, 216, 218, 220, 222, 224, 225, 227, 229, 230, 232, 233, 235, 237, 238, 240, 241, 242, 243, 244, 246, 246, 248, 249, 250, 251, 252, 253, 254]
    private static let expScale: [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 14, 16, 19, 23, 27, 33, 39, 47, 56, 66, 80, 94, 110, 126, 142, 158, 174, 190, 206, 222, 238, 250]
    private static let pitchEnvTab: [Int] = [-128, -116, -104, -95, -85, -76, -68, -61, -56, -52, -49, -46, -43, -41, -39, -37, -35, -33, -32, -31, -30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 38, 40, 43, 46, 49, 53, 58, 65, 73, 82, 92, 103, 115, 127]
    private static let pitchEnvRate: [Int] = [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 33, 34, 36, 37, 38, 39, 41, 42, 44, 46, 47, 49, 51, 53, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76, 79, 82, 85, 88, 91, 94, 98, 102, 106, 110, 115, 120, 125, 130, 135, 141, 147, 153, 159, 165, 171, 178, 185, 193, 202, 211, 232, 243, 254, 255]
    private static let pmsTab: [Int] = [0, 10, 20, 33, 55, 92, 153, 255]
    private static let amsTab: [Int] = [0, 4342338, 7171437, 16777216]   // Q24
    /// coarsemul[] in octaves: log2(coarse), coarse 0 → 0.5
    private static let coarseLog: [Double] = (0..<32).map { $0 == 0 ? -1 : log2(Double($0)) }
    private static let fineLog: [Double] = (0..<100).map { log2(1 + 0.01 * Double($0)) }
    /// log2 of MIDI note 0 frequency (50857777 / 2^24)
    private static let noteZeroLog = 50857777.0 / 16777216.0
    /// Exp2 lookup threshold of fm_core.cc (kLevelThresh = 1120 in Q24)
    private static let levelThresh: Float = 1120.0 / 16777216.0

    @inline(__always) private func p(_ i: Int) -> Int { Int(patch[i]) }

    // MARK: Level / rate scaling (dx7note.cc)

    private func scaleCurve(_ group: Int, _ depth: Int, _ curve: Int) -> Int {
        var scale: Int
        if curve == 0 || curve == 3 {
            scale = (group * depth * 329) >> 12
        } else {
            let raw = FMEngine.expScale[min(group, FMEngine.expScale.count - 1)]
            scale = (raw * depth * 329) >> 15
        }
        if curve < 2 { scale = -scale }
        return scale
    }

    /// ScaleLevel: note offsets are relative to break point + 17 (MSFA convention).
    private func scaleLevel(note: Int, base b: Int) -> Int {
        let offset = note - p(b + 8) - 17
        if offset >= 0 {
            return scaleCurve((offset + 1) / 3, p(b + 10), p(b + 12))
        } else {
            return scaleCurve((-offset + 1) / 3, p(b + 9), p(b + 11))
        }
    }

    /// ScaleRate (with the FM-1 / Dexed rounding corrections), in qrate units.
    @inline(__always) private static func scaleRate(_ note: Int, _ sens: Int) -> Int {
        let x = min(31, max(0, note / 3 - 7))
        var d = (sens * x) >> 3
        let rem = x & 7
        if sens == 3 && rem == 3 { d -= 1 } else if sens == 7 && rem > 0 && rem < 4 { d += 1 }
        return d
    }

    /// Operator output level for a note in Q5 "microsteps" (outlevel in dx7note.cc).
    private func operatorOutLevel(base b: Int, note: Int, velocity: Int) -> Int {
        var level = FMEngine.scaleOutLevel(p(b + 16))
        level += scaleLevel(note: note, base: b)
        var out = min(127, level) << 5
        let vel = velocityCurveOn ? velocity : 100
        let v = FMEngine.velocityData[min(63, vel >> 1)] - 239
        out += ((p(b + 15) * v + 7) >> 3) * 16
        return max(0, out)
    }

    // MARK: Voice management (audio thread)

    private func startVoice(_ v: Int, note: Int, vel: Int, glideFrom: Float? = nil) {
        let retrigger = vActive[v]
        vAdsrStage[v] = 0
        if !retrigger { vAdsr[v] = 0 }
        vActive[v] = true; vNote[v] = note; vVel[v] = vel; vKeyDown[v] = true; vSustained[v] = false
        vMidi[v] = min(127, max(0, note + p(144) - 24))
        ageCounter += 1; vAge[v] = ageCounter
        setGlide(v, from: glideFrom, to: Float(note))
        // PitchEnv::set: level starts at L4, stage 0
        vPitchStage[v] = 0
        vPitchLevel[v] = FMEngine.pitchEnvTab[min(99, p(133))] << 19
        let sync = p(136) == 1
        for o in 0..<6 {
            let k = v * 6 + o
            oStage[k] = 0
            // Env::init starts from level 0; a stolen voice keeps its level to avoid a click.
            if !retrigger { oEnv[k] = 0; oGain[k] = 0 }
            if sync { oPhase[k] = 0 }
        }
        if sync || !retrigger { fbY0[v] = 0; fbY1[v] = 0 }
        lfoKeyDown()
    }

    private func setGlide(_ v: Int, from: Float?, to: Float) {
        guard let from, glideTime > 0, from != to else { vGlide[v] = 0; vGlideStep[v] = 0; return }
        let delta = from - to
        let blocks = max(1, glideTime * sampleRate / Float(FMEngine.blockSize))
        vGlide[v] = delta
        vGlideStep[v] = abs(delta) / blocks
    }

    private func releaseVoice(_ v: Int) {
        vKeyDown[v] = false
        if sustainPedal { vSustained[v] = true; return }
        enterRelease(v)
    }

    /// Env::keydown(false) / PitchEnv::keydown(false): jump to stage 4 (index 3).
    private func enterRelease(_ v: Int) {
        for o in 0..<6 { oStage[v * 6 + o] = 3 }
        vPitchStage[v] = 3
        vAdsrStage[v] = 3
    }

    private func monoNoteOn(_ note: Int, vel: Int) {
        // push (remove duplicates)
        var j = 0
        for i in 0..<monoCount where monoStack[i] != note { monoStack[j] = monoStack[i]; j += 1 }
        monoCount = j
        if monoCount < monoStack.count { monoStack[monoCount] = note; monoCount += 1 }
        let legato = vActive[0] && (vKeyDown[0] || vSustained[0]) && monoCount > 1
        if legato {
            let current = Float(vNote[0]) + vGlide[0]
            vNote[0] = note
            vMidi[0] = min(127, max(0, note + p(144) - 24))
            vKeyDown[0] = true
            setGlide(0, from: current, to: Float(note))
            lfoKeyDown()
        } else {
            let from: Float? = (glideTime > 0 && !glideFingered && lastMonoPitch >= 0) ? lastMonoPitch : nil
            startVoice(0, note: note, vel: vel, glideFrom: from)
        }
    }

    private func monoNoteOff(_ note: Int) {
        let wasTop = monoCount > 0 && monoStack[monoCount - 1] == note
        var j = 0
        for i in 0..<monoCount where monoStack[i] != note { monoStack[j] = monoStack[i]; j += 1 }
        monoCount = j
        guard vActive[0], vNote[0] == note || wasTop else { return }
        if monoCount > 0 {
            let current = Float(vNote[0]) + vGlide[0]
            let n = monoStack[monoCount - 1]
            vNote[0] = n
            vMidi[0] = min(127, max(0, n + p(144) - 24))
            setGlide(0, from: current, to: Float(n))
        } else {
            releaseVoice(0)
        }
    }

    /// Voice to use for a new note: idle > released > pedal-held > same pitch > oldest.
    private func allocateVoice(note: Int) -> Int {
        let n = maxVoices
        for v in 0..<n where !vActive[v] { return v }
        var best = -1, bestAge = Int.max
        for v in 0..<n where !vKeyDown[v] && !vSustained[v] && vAge[v] < bestAge { best = v; bestAge = vAge[v] }
        if best >= 0 { return best }
        for v in 0..<n where !vKeyDown[v] && vAge[v] < bestAge { best = v; bestAge = vAge[v] }
        if best >= 0 { return best }
        for v in 0..<n where vNote[v] == note { return v }
        for v in 0..<n where vAge[v] < bestAge { best = v; bestAge = vAge[v] }
        return max(0, best)
    }

    private func handle(_ e: Event) {
        switch e {
        case let .keyOn(n, vel):
            if arpSeq.consumesKeys { arpSeq.keyDown(Int(n), vel: Int(vel)) } else { handle(.noteOn(n, vel)) }
        case let .keyOff(n):
            if arpSeq.consumesKeys { arpSeq.keyUp(Int(n)) } else { handle(.noteOff(n)) }
        case .panic:
            arpSeq.releaseAll()
            monoCount = 0
            for v in 0..<FMEngine.voiceCapacity { vActive[v] = false; vKeyDown[v] = false; vSustained[v] = false }
            for k in 0..<(FMEngine.voiceCapacity * 6) { oStage[k] = 4; oGain[k] = 0; oEnv[k] = 0 }
        case let .noteOn(n, vel):
            let note = Int(n)
            if monoMode {
                monoNoteOn(note, vel: Int(vel))
                return
            }
            startVoice(allocateVoice(note: note), note: note, vel: Int(vel))
        case let .noteOff(n):
            if monoMode { monoNoteOff(Int(n)); return }
            for v in 0..<FMEngine.voiceCapacity where vActive[v] && vNote[v] == Int(n) && vKeyDown[v] { releaseVoice(v) }
        case let .cc(c, val):
            switch c {
            case 1: wheelCC = Int(val)
            case 64:
                sustainPedal = val >= 64
                if !sustainPedal {
                    for v in 0..<FMEngine.voiceCapacity where vSustained[v] {
                        vSustained[v] = false
                        if !vKeyDown[v] { enterRelease(v) }
                    }
                }
            case 120, 123: handle(.allOff)
            default: break
            }
        case let .bend(v14):
            bend = Float(v14 - 8192) / 8192
        case .allOff:
            monoCount = 0
            for v in 0..<FMEngine.voiceCapacity where vActive[v] {
                vKeyDown[v] = false; vSustained[v] = false
                enterRelease(v)
            }
        }
    }

    // MARK: LFO (lfo.cc, FM-1 variant: speed formula instead of table)

    private func lfoKeyDown() {
        if p(141) != 0 { lfoPhase = (1 << 31) - 1 }
        lfoDelayState = 0
    }

    /// Advances the LFO by `n` samples; returns (value Q24 0...2^24, delay Q24 0...2^24).
    private func lfoTick(n: Int) -> (Int, Int) {
        let unit = Double(n) * 25190424.0 / Double(sampleRate)
        let rate = min(99, p(137))
        var sr = rate == 0 ? 1 : (165 * rate) >> 6
        sr *= sr < 160 ? 11 : (11 + ((sr - 160) >> 4))
        let delta = UInt32(min(Double(UInt32.max), (unit * Double(sr)).rounded()))
        lfoPhase = lfoPhase &+ delta
        let ph = lfoPhase
        var value: Int
        switch p(142) {
        case 0:  // triangle
            var x = Int32(bitPattern: ph >> 7)
            x ^= -Int32(bitPattern: ph >> 31)
            value = Int(x & ((1 << 24) - 1))
        case 1: value = Int((~ph ^ (1 << 31)) >> 8)          // saw down
        case 2: value = Int((ph ^ (1 << 31)) >> 8)           // saw up
        case 3: value = Int(((~ph) >> 7) & (1 << 24))        // square
        case 4:  // sine
            value = (1 << 23) + Int(sinf(Float(Double(ph) / 4294967296.0) * 2 * .pi) * Float(1 << 23))
        default: // sample & hold
            if ph < delta { lfoRand = (lfoRand * 179 + 17) & 0xff }
            value = ((lfoRand ^ 0x80) + 1) << 16
        }
        // delay
        let a0 = 99 - min(99, p(138))
        var delay: Int
        if a0 == 99 {
            delay = 1 << 24
        } else {
            let a = (16 + (a0 & 15)) << (1 + (a0 >> 4))
            let inc1 = UInt64(unit * Double(a))
            let inc2 = UInt64(unit * Double(max(0x80, a & 0xff80)))
            let d = UInt64(lfoDelayState) + (lfoDelayState < (1 << 31) ? inc1 : inc2)
            if d > UInt64(UInt32.max) {
                delay = 1 << 24
            } else {
                lfoDelayState = UInt32(d)
                delay = d < (1 << 31) ? 0 : Int((d >> 7) & ((1 << 24) - 1))
            }
        }
        return (value, delay)
    }

    // MARK: Render

    /// Renders `frames` mono samples into `out`.
    func render(frames: Int, out: UnsafeMutablePointer<Float>) {
        // drain events without blocking
        var count = 0
        let pend = pending
        let cap = pendingCap
        _ = queue.withLockIfAvailableUnchecked { q in
            for e in q.items where count < cap { pend[count] = e; count += 1 }
            q.items.removeAll(keepingCapacity: true)
        }
        for k in 0..<count { handle(pending[k]) }

        var done = 0
        while done < frames {
            let n = min(FMEngine.blockSize, frames - done)
            if arpSeq.arpOn || arpSeq.seqOn {
                arpSeq.advance(frames: n, sampleRate: Double(sampleRate)) { self.handle($0) }
            }
            renderBlock(n: n, out: out + done)
            done += n
        }
        // scope
        for k in 0..<frames {
            scope[scopeWrite] = out[k]
            scopeWrite = (scopeWrite + 1) & (FMEngine.scopeSize - 1)
        }
    }

    private func renderBlock(n: Int, out: UnsafeMutablePointer<Float>) {
        for k in 0..<n { out[k] = 0 }
        let sr = sampleRate
        let blockSeconds = Float(n) / sr
        let blockFrac = Float(n) / Float(FMEngine.blockSize)

        // ---- global modulation (Dx7Note::compute, once per block)
        let (lfoVal, lfoDelay) = lfoTick(n: n)
        let pmdDepth = (min(99, p(139)) * 165) >> 6
        let pms = FMEngine.pmsTab[min(7, p(143))]
        let senslfo = pms * (lfoVal - (1 << 23))
        let pmd1 = Int(abs(Double(pmdDepth * lfoDelay) * Double(senslfo) / 549755813888.0))   // >> 39
        let wheelLfo = (pms != 0 ? pms : 10) * (lfoVal - (1 << 23))
        let wheelDepth = (wheelCC * 100 + 64) >> 7           // mod wheel → pitch (0...99)
        let pmd2 = abs((wheelDepth * wheelLfo) >> 14)
        let lfoPitch = Double(max(pmd1, pmd2) * (wheelLfo < 0 ? -1 : 1)) / 16777216.0   // octaves
        let bendSemis = bend >= 0 ? bend * bendUp : bend * bendDown
        let pitchBase = Double(bendSemis) / 12 + Double(masterTune) / 1200                 // octaves

        // amplitude modulation: per-sensitivity log-level factor (pt / 2^24 in dx7note.cc)
        let amdDepth = (min(99, p(140)) * 165) >> 6
        let lfoInv = (1 << 24) - lfoVal
        let amod = (((amdDepth * lfoDelay) >> 8) * lfoInv) >> 24
        for s in 1...3 {
            let sensamp = (amod * FMEngine.amsTab[s]) >> 24
            amFactor[s] = Float(exp(Double(sensamp) / 262144.0 * 0.07 + 12.2) / 16777216.0)
        }

        // envelope / pitch-EG rate units for this block
        let srMul = 44100.0 / Double(sr)                                     // Env::init_sr
        let pitchUnit = Double(n) * 16777216.0 / (21.3 * Double(sr))          // PitchEnv::init

        let algIndex = min(31, p(134))
        let mCount = modCount + algIndex * 6
        let mList = modList + algIndex * 36
        let cMask = carrierMask + algIndex * 6
        let fbParam = min(7, p(135))
        // feedback: (y0 + y1) >> (shift + 1), shift = 8 - fb. Algorithms 4, 6 and 32 use shift + 2 (FM-1 core).
        let fbExtra = (algIndex == 3 || algIndex == 5 || algIndex == 31) ? 2 : 0
        let fbAmount: Float = fbParam == 0 ? 0 : 0.5 * exp2f(Float(fbParam - 8 - fbExtra))
        let fbOpIdx = FMAlgorithm.all[algIndex].feedbackOp - 1
        let fbFromIdx = FMAlgorithm.all[algIndex].feedbackFrom - 1
        let muteMask = opMuteMask
        let adsrOn = envOn
        let invN = 1 / Float(n)
        let thresh = FMEngine.levelThresh
        var active = 0
        var newest = -1, newestAge = -1

        for v in 0..<FMEngine.voiceCapacity where vActive[v] {
            active += 1
            if vAge[v] > newestAge { newestAge = vAge[v]; newest = v }
            let midi = vMidi[v]
            let down = vKeyDown[v] || vSustained[v]

            // ---- pitch EG (pitchenv.cc)
            var pix = vPitchStage[v]
            var plevel = vPitchLevel[v]
            if pix < 3 || (pix < 4 && !down) {
                let target = FMEngine.pitchEnvTab[min(99, p(130 + pix))] << 19
                let inc = Int(Double(FMEngine.pitchEnvRate[min(99, p(126 + pix))]) * pitchUnit)
                if target > plevel {
                    plevel += inc
                    if plevel >= target { plevel = target; pix += 1 }
                } else {
                    plevel -= inc
                    if plevel <= target { plevel = target; pix += 1 }
                }
                vPitchLevel[v] = plevel; vPitchStage[v] = pix
            }

            // ---- glide (ratio operators only, as in the FM-1 core)
            var glide = vGlide[v]
            if glide != 0 {
                let step = vGlideStep[v] * blockFrac
                glide = glide > 0 ? max(0, glide - step) : min(0, glide + step)
                vGlide[v] = glide
            }
            if v == 0 { lastMonoPitch = Float(vNote[v]) + glide }

            // ---- global ADSR
            let adsrStart = vAdsr[v]
            if adsrOn { adsrStep(v, blockSeconds) } else { vAdsr[v] = 1 }
            let adsrEnd = vAdsr[v]

            let pitchMod = lfoPitch + Double(plevel) / 16777216.0 + Double(glide) / 12 + pitchBase
            let noteLog = FMEngine.noteZeroLog + Double(midi) / 12

            // ---- per-operator envelope, level and frequency
            var anyCarrierSounding = false
            for o in 0..<6 {
                let b = FMPatch.opBase(o + 1)
                let k = v * 6 + o
                // Env (env.cc), advanced once per block
                var ix = oStage[k]
                var level = oEnv[k]
                if ix < 3 || (ix < 4 && !down) {
                    let outLevel = operatorOutLevel(base: b, note: midi, velocity: vVel[v])
                    var target = ((FMEngine.scaleOutLevel(p(b + 4 + ix)) >> 1) << 6) + outLevel - 4256
                    target = max(16, target) << 16
                    var qrate = (p(b + ix) * 41) >> 6
                    qrate += FMEngine.scaleRate(midi, p(b + 13))
                    qrate = min(63, qrate)
                    let inc = Int(Double((4 + (qrate & 3)) << (2 + (qrate >> 2))) * srMul) * n
                    if target > level {
                        level = max(1716 << 16, level)                    // jumpstart
                        level += (((17 << 24) - level) >> 24) * inc         // exponential attack
                        if level >= target { level = target; ix += 1 }
                    } else {
                        level -= inc
                        if level <= target { level = target; ix += 1 }
                    }
                    oStage[k] = ix
                    oEnv[k] = level
                }
                // amplitude modulation (scales the log level)
                let ams = p(b + 14) & 3
                var lv = Float(level)
                if ams != 0 { lv -= lv * amFactor[ams] }
                let muted = (muteMask >> o) & 1 == 1
                let g2: Float = muted ? 0 : exp2f(lv / 16777216 - 14)
                let g1 = oGain[k]
                oGain[k] = g2
                opG1[o] = g1
                opGStep[o] = (g2 - g1) * invN
                opOn[o] = g1 >= thresh || g2 >= thresh
                // operator frequency (osc_freq + Freqlut)
                let fine = min(99, p(b + 19)), detune = min(14, p(b + 20)), coarse = p(b + 18) & 31
                var lf: Double
                if p(b + 17) == 1 {
                    lf = Double((coarse & 3) * 100 + fine) * (4458616.0 / 8 / 16777216.0)
                    if detune > 7 { lf += Double(13457 * (detune - 7)) / 16777216.0 }
                    lf += pitchBase
                } else {
                    lf = noteLog
                    if detune != 7 {
                        let ratio = 0.0209 * exp(-0.396 * lf) / 7
                        lf += ratio * lf * Double(detune - 7)
                    }
                    lf += FMEngine.coarseLog[coarse] + FMEngine.fineLog[fine] + pitchMod
                }
                opInc[o] = Float(exp2(lf) / Double(sr))
                if cMask[o] > 0 && opOn[o] { anyCarrierSounding = true }
                if v == newest { opMeterTmp[o] = min(1, g2 * 0.5) }
            }
            let adsrDone = adsrOn && vAdsrStage[v] >= 4
            if (!anyCarrierSounding || adsrDone) && !down {
                vActive[v] = false
                for o in 0..<6 { oStage[v * 6 + o] = 4; oGain[v * 6 + o] = 0 }
                active -= 1
                continue
            }

            // ---- synthesis (fm_core.cc / fm_op_kernel.cc)
            let base = v * 6
            var y0 = fbY0[v], y1 = fbY1[v]
            let adsrStep = (adsrEnd - adsrStart) * invN
            for s in 0..<n {
                let fs = Float(s + 1)
                var mix: Float = 0
                var o = 5
                while o >= 0 {
                    if opOn[o] {
                        let k = base + o
                        var mod: Float = 0
                        let mc = mCount[o]
                        var mi = 0
                        while mi < mc { mod += opOut[mList[o * 6 + mi]]; mi += 1 }
                        if o == fbOpIdx { mod += (y0 + y1) * fbAmount }
                        let ph = oPhase[k]
                        var np = ph + opInc[o]
                        if np >= 1 { np -= 1 }
                        oPhase[k] = np
                        var x = ph + mod
                        x -= floorf(x)
                        let fi = x * Float(FMEngine.sineSize)
                        let ii = Int(fi)
                        let fr = fi - Float(ii)
                        let sv = sine[ii] + (sine[ii + 1] - sine[ii]) * fr
                        let y = sv * (opG1[o] + opGStep[o] * fs)
                        opOut[o] = y
                        mix += y * cMask[o]
                    } else {
                        opOut[o] = 0
                    }
                    o -= 1
                }
                if fbAmount > 0 && opOn[fbFromIdx] { y0 = y1; y1 = opOut[fbFromIdx] }
                out[s] += mix * (adsrStart + adsrStep * fs)
            }
            fbY0[v] = y0; fbY1[v] = y1
            // phase of silent operators keeps running (param.phase += freq << LG_N)
            for o in 0..<6 where !opOn[o] {
                var ph = oPhase[base + o] + opInc[o] * Float(n)
                ph -= floorf(ph)
                oPhase[base + o] = ph
            }
        }
        activeVoiceCount = active
        if newest >= 0 { for o in 0..<6 { opMeter[o] = opMeterTmp[o] } } else { for o in 0..<6 { opMeter[o] *= 0.8 } }

        // ---- output: MSFA voice sum >> 4, DC blocker (FM-1 core), master, soft limiter
        let gain = masterVolume * FMEngine.outputScale
        let r = 1 - 126 / sr
        var x1 = dcX1, y1 = dcY1
        for k in 0..<n {
            let x = out[k] * gain
            let y = x - x1 + r * y1
            x1 = x; y1 = y
            out[k] = FMEngine.softLimit(y)
        }
        dcX1 = x1; dcY1 = y1
    }

    /// Voice sum to output: MSFA divides the Q24 carrier sum by 16; the extra
    /// factor 2 puts the app default master volume (0.8) at +4 dB
    /// relative to the FM-1 / Dexed level (volume 0.5 = MSFA unity).
    private static let outputScale: Float = 2.0 / 16

    /// Transparent below 0.75, smooth saturation to ±1 above.
    @inline(__always) private static func softLimit(_ x: Float) -> Float {
        let a = abs(x)
        if a <= 0.75 { return x }
        let y = 0.75 + 0.25 * tanhf((a - 0.75) * 4)
        return x < 0 ? -y : y
    }

    private let opInc = UnsafeMutablePointer<Float>.allocate(capacity: 6)
    private let opG1 = UnsafeMutablePointer<Float>.allocate(capacity: 6)
    private let opGStep = UnsafeMutablePointer<Float>.allocate(capacity: 6)
    private let opOn = UnsafeMutablePointer<Bool>.allocate(capacity: 6)
    private let opMeterTmp = UnsafeMutablePointer<Float>.allocate(capacity: 6)
    private let amFactor = UnsafeMutablePointer<Float>.allocate(capacity: 4)
    /// [alg][op] → count, [alg][op][i] → modulator index (0-based)
    private let modCount = UnsafeMutablePointer<Int>.allocate(capacity: 32 * 6)
    private let modList = UnsafeMutablePointer<Int>.allocate(capacity: 32 * 36)
    private let carrierMask = UnsafeMutablePointer<Float>.allocate(capacity: 32 * 6)

    /// 0...1 knob → seconds (cubic, 0 → 1 ms ... 1 → ~8 s)
    @inline(__always) private func envTime(_ x: Float) -> Float { 0.001 + x * x * x * 8 }

    private func adsrStep(_ v: Int, _ dt: Float) {
        var lvl = vAdsr[v]
        switch vAdsrStage[v] {
        case 0:
            lvl += dt / envTime(envA)
            if lvl >= 1 { lvl = 1; vAdsrStage[v] = 1 }
        case 1:
            let k = expf(-dt / (envTime(envD) * 0.3))
            lvl = envS + (lvl - envS) * k
            if abs(lvl - envS) < 0.001 { lvl = envS; vAdsrStage[v] = 2 }
        case 2:
            lvl = envS
        case 3:
            lvl *= expf(-dt / (envTime(envR) * 0.25))
            if lvl < 0.0005 { lvl = 0; vAdsrStage[v] = 4 }
        default:
            lvl = 0
        }
        if vAdsrStage[v] < 3 && !vKeyDown[v] && !vSustained[v] { vAdsrStage[v] = 3 }
        vAdsr[v] = lvl
    }
}
