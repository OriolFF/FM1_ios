import Foundation

/// Groovebox sequencer (opt-in "Groove" mode): 8 patterns, each with a
/// 64-step FM synth track and an 11-lane drum track, following the community
/// FM-1 firmware grammar (Felucca / SLOOP / FM-1+VA).
///
/// All pattern data lives in fixed unsafe buffers: the UI edits bytes, the
/// audio thread reads them; nothing is reallocated after init.
final class GrooveSeq: @unchecked Sendable {
    static let patterns = 8
    static let steps = 64
    static let lanes = 11
    static let notesPerStep = 4
    static let locksPerStep = 4
    static let tieGate: UInt8 = 17

    /// Chance / condition values: 0 always, 1...7 = (8-k)/8 probability, 8 FILL, 9 !FILL
    static let conditionNames = ["Always", "88%", "75%", "63%", "50%", "38%", "25%", "13%", "FILL", "!FILL"]

    // MARK: Synth track buffers  [pattern][step]...
    let sNotes: UnsafeMutablePointer<UInt8>    // × notesPerStep, 0 = none
    let sVel: UnsafeMutablePointer<UInt8>      // 0 = empty step
    let sGate: UnsafeMutablePointer<UInt8>     // 1...16 (/16 of step), 17 = tie
    let sCond: UnsafeMutablePointer<UInt8>
    let sRatchet: UnsafeMutablePointer<UInt8>  // 1...4
    let sLockParam: UnsafeMutablePointer<UInt8> // × locksPerStep, 0xFF = none (VCED index)
    let sLockVal: UnsafeMutablePointer<UInt8>

    // MARK: Drum buffers [pattern][lane][step]
    let dVel: UnsafeMutablePointer<UInt8>      // 0 = no hit
    let dCond: UnsafeMutablePointer<UInt8>
    let dRatchet: UnsafeMutablePointer<UInt8>

    // MARK: Per pattern
    var synthLen = [Int](repeating: 16, count: patterns)
    var drumLen = [Int](repeating: 16, count: patterns)
    var swing = [Int](repeating: 50, count: patterns)   // 50...75

    // MARK: Mix / perform (UI writes)
    var tempo: Double = 120
    var synthMute = false, drumMute = false
    var synthSolo = false, drumSolo = false
    let laneMute: UnsafeMutablePointer<Bool>
    var fill = false

    // MARK: Transport (UI writes)
    var on = false
    var playing = false
    var pattern = 0
    var queuedPattern = -1

    /// Unlocked patch the locks restore to (UI keeps it in sync with the edit buffer).
    let basePatch: UnsafeMutablePointer<UInt8>
    private let enginePatch: UnsafeMutablePointer<UInt8>
    private let kit: DrumKit

    // MARK: Playback state (audio writes, UI reads)
    private(set) var synthStep = -1
    private(set) var drumStep = -1
    private(set) var stepPhase: Double = 0   // 0...1 progress through current step
    private(set) var counter = 0

    private var samplesToNext: Double = 0
    private var curStepLen: Double = 1
    private var wasPlaying = false
    private var rng: UInt32 = 0x1234_ABCD
    // sounding synth notes
    private var sounding = [Int](repeating: -1, count: 8)
    private var soundingCount = 0
    private var gateLeft: Double = -1
    private var tieActive = false
    // synth ratchet
    private var sRatLeft = 0
    private var sRatInterval: Double = 0
    private var sRatCountdown: Double = 0
    private var sRatStep = 0
    private var sRatPattern = 0
    // drum ratchets per lane
    private var dRatLeft = [Int](repeating: 0, count: lanes)
    private var dRatInterval = [Double](repeating: 0, count: lanes)
    private var dRatCountdown = [Double](repeating: 0, count: lanes)
    private var dRatVel = [Int](repeating: 0, count: lanes)
    // active locks to restore
    private var lockedParams = [Int](repeating: -1, count: locksPerStep)

    init(enginePatch: UnsafeMutablePointer<UInt8>, kit: DrumKit) {
        self.enginePatch = enginePatch
        self.kit = kit
        let ps = GrooveSeq.patterns * GrooveSeq.steps
        func buf(_ n: Int, _ v: UInt8) -> UnsafeMutablePointer<UInt8> { let p = UnsafeMutablePointer<UInt8>.allocate(capacity: n); p.initialize(repeating: v, count: n); return p }
        sNotes = buf(ps * GrooveSeq.notesPerStep, 0)
        sVel = buf(ps, 0)
        sGate = buf(ps, 8)
        sCond = buf(ps, 0)
        sRatchet = buf(ps, 1)
        sLockParam = buf(ps * GrooveSeq.locksPerStep, 0xFF)
        sLockVal = buf(ps * GrooveSeq.locksPerStep, 0)
        let pd = GrooveSeq.patterns * GrooveSeq.lanes * GrooveSeq.steps
        dVel = buf(pd, 0)
        dCond = buf(pd, 0)
        dRatchet = buf(pd, 1)
        laneMute = .allocate(capacity: GrooveSeq.lanes); laneMute.initialize(repeating: false, count: GrooveSeq.lanes)
        basePatch = buf(FMPatch.size, 0)
        basePatch.update(from: enginePatch, count: FMPatch.size)
    }

    // MARK: Index helpers
    @inline(__always) func si(_ p: Int, _ s: Int) -> Int { p * GrooveSeq.steps + s }
    @inline(__always) func di(_ p: Int, _ l: Int, _ s: Int) -> Int { (p * GrooveSeq.lanes + l) * GrooveSeq.steps + s }

    // MARK: UI-thread editing helpers

    func synthNotes(_ p: Int, _ s: Int) -> [Int] {
        let b = si(p, s) * GrooveSeq.notesPerStep
        return (0..<GrooveSeq.notesPerStep).compactMap { sNotes[b + $0] == 0 ? nil : Int(sNotes[b + $0]) }
    }
    func setSynthNotes(_ p: Int, _ s: Int, _ notes: [Int], velocity: Int = 100) {
        let b = si(p, s) * GrooveSeq.notesPerStep
        for i in 0..<GrooveSeq.notesPerStep { sNotes[b + i] = i < notes.count ? UInt8(clamping: max(1, notes[i])) : 0 }
        sVel[si(p, s)] = notes.isEmpty ? 0 : UInt8(clamping: max(1, velocity))
    }
    func addSynthNote(_ p: Int, _ s: Int, _ note: Int, velocity: Int) {
        var n = synthNotes(p, s)
        if n.contains(note) { return }
        if n.count >= GrooveSeq.notesPerStep { n.removeFirst() }
        n.append(note)
        setSynthNotes(p, s, n, velocity: velocity)
    }
    func synthHas(_ p: Int, _ s: Int) -> Bool { sVel[si(p, s)] != 0 }
    func drumHas(_ p: Int, _ l: Int, _ s: Int) -> Bool { dVel[di(p, l, s)] != 0 }
    func laneHasHits(_ p: Int, _ l: Int) -> Bool {
        for s in 0..<GrooveSeq.steps where dVel[di(p, l, s)] != 0 { return true }
        return false
    }

    func clearSynth(_ p: Int) {
        for s in 0..<GrooveSeq.steps {
            setSynthNotes(p, s, [])
            let i = si(p, s)
            sGate[i] = 8; sCond[i] = 0; sRatchet[i] = 1
            for k in 0..<GrooveSeq.locksPerStep { sLockParam[i * GrooveSeq.locksPerStep + k] = 0xFF }
        }
    }
    func clearLane(_ p: Int, _ l: Int) {
        for s in 0..<GrooveSeq.steps { let i = di(p, l, s); dVel[i] = 0; dCond[i] = 0; dRatchet[i] = 1 }
    }
    func clearDrums(_ p: Int) { for l in 0..<GrooveSeq.lanes { clearLane(p, l) } }

    func copyPattern(_ from: Int, _ to: Int) {
        guard from != to else { return }
        let n = GrooveSeq.steps
        func cp(_ b: UnsafeMutablePointer<UInt8>, _ stride: Int) {
            (b + to * n * stride).update(from: b + from * n * stride, count: n * stride)
        }
        cp(sNotes, GrooveSeq.notesPerStep); cp(sVel, 1); cp(sGate, 1); cp(sCond, 1); cp(sRatchet, 1)
        cp(sLockParam, GrooveSeq.locksPerStep); cp(sLockVal, GrooveSeq.locksPerStep)
        let dn = GrooveSeq.lanes * n
        (dVel + to * dn).update(from: dVel + from * dn, count: dn)
        (dCond + to * dn).update(from: dCond + from * dn, count: dn)
        (dRatchet + to * dn).update(from: dRatchet + from * dn, count: dn)
        synthLen[to] = synthLen[from]; drumLen[to] = drumLen[from]; swing[to] = swing[from]
    }

    /// Euclidean rhythm (Bjorklund-equivalent bucket method) written into a lane.
    func euclid(_ p: Int, lane l: Int, hits: Int, steps: Int, rotate: Int, velocity: Int = 100) {
        let n = max(1, min(GrooveSeq.steps, steps))
        let k = max(0, min(n, hits))
        for s in 0..<GrooveSeq.steps { dVel[di(p, l, s)] = 0 }
        guard k > 0 else { return }
        for s in 0..<n {
            // step s is a hit when the bucket overflows
            let hit = ((s * k) % n) < k
            if hit {
                let pos = ((s + rotate) % n + n) % n
                dVel[di(p, l, pos)] = UInt8(clamping: velocity)
            }
        }
    }

    /// Random drum fill by metric weight (PERF-1 style density).
    func densityFill(_ p: Int, lane l: Int, density: Double) {
        let n = drumLen[p]
        let weights: [Double] = [1.0, 0.2, 0.45, 0.25, 0.75, 0.2, 0.45, 0.3, 0.9, 0.2, 0.45, 0.25, 0.75, 0.2, 0.5, 0.35]
        var g = SystemRandomNumberGenerator()
        for s in 0..<n {
            let w = weights[s % 16]
            let hit = Double.random(in: 0...1, using: &g) < density * (0.35 + w)
            dVel[di(p, l, s)] = hit ? UInt8(w > 0.7 ? 110 : 85) : 0
        }
    }

    /// Nearest synth step for live recording (UI thread, approximate).
    func nearestSynthStep() -> Int {
        let len = max(1, synthLen[pattern])
        let cur = max(0, synthStep)
        return stepPhase > 0.5 ? (cur + 1) % len : cur
    }

    // MARK: Audio thread

    private func rand8() -> Int { rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5; return Int(rng & 7) }

    private func passes(_ cond: UInt8) -> Bool {
        switch cond {
        case 0: return true
        case 1...7: return rand8() < 8 - Int(cond)
        case 8: return fill
        case 9: return !fill
        default: return true
        }
    }

    private let scratch = UnsafeMutablePointer<Int>.allocate(capacity: GrooveSeq.notesPerStep)

    /// Releases sounding notes except the first `keepCount` entries of `scratch`.
    private func releaseSynth(_ sink: (FMEngine.Event) -> Void, keepCount: Int = 0) {
        var j = 0
        for i in 0..<soundingCount {
            let n = sounding[i]
            var keep = false
            for k in 0..<keepCount where scratch[k] == n { keep = true }
            if keep { sounding[j] = n; j += 1 } else { sink(.noteOff(UInt8(n))) }
        }
        soundingCount = j
    }

    private func restoreLocks() {
        for k in 0..<GrooveSeq.locksPerStep where lockedParams[k] >= 0 {
            let idx = lockedParams[k]
            enginePatch[idx] = basePatch[idx]
            lockedParams[k] = -1
        }
    }

    func stopAll(_ sink: (FMEngine.Event) -> Void) {
        releaseSynth(sink)
        restoreLocks()
        sRatLeft = 0
        for l in 0..<GrooveSeq.lanes { dRatLeft[l] = 0 }
        tieActive = false
        gateLeft = -1
    }

    private var synthAudible: Bool { !synthMute && !(drumSolo && !synthSolo) }
    private var drumAudible: Bool { !drumMute && !(synthSolo && !drumSolo) }

    private func playSynthStep(_ p: Int, _ s: Int, stepLen: Double, _ sink: (FMEngine.Event) -> Void) {
        let i = si(p, s)
        // locks: restore previous, apply this step's
        restoreLocks()
        if sVel[i] != 0 {
            for k in 0..<GrooveSeq.locksPerStep {
                let prm = sLockParam[i * GrooveSeq.locksPerStep + k]
                if prm != 0xFF && Int(prm) < FMPatch.size {
                    enginePatch[Int(prm)] = sLockVal[i * GrooveSeq.locksPerStep + k]
                    lockedParams[k] = Int(prm)
                }
            }
        }
        guard sVel[i] != 0, synthAudible, passes(sCond[i]) else {
            if !tieActive { releaseSynth(sink) }
            tieActive = false
            return
        }
        var count = 0
        let b = i * GrooveSeq.notesPerStep
        for k in 0..<GrooveSeq.notesPerStep where sNotes[b + k] != 0 { scratch[count] = Int(sNotes[b + k]); count += 1 }
        // a tie from the previous step keeps common notes sounding (no retrigger)
        let tied = tieActive
        releaseSynth(sink, keepCount: tied ? count : 0)
        for k in 0..<count {
            let n = scratch[k]
            var already = false
            if tied { for q in 0..<soundingCount where sounding[q] == n { already = true } }
            if already { continue }
            sink(.noteOn(UInt8(n), sVel[i]))
            if soundingCount < sounding.count { sounding[soundingCount] = n; soundingCount += 1 }
        }
        let rat = max(1, Int(sRatchet[i]))
        let gate = sGate[i]
        tieActive = gate == GrooveSeq.tieGate && rat == 1
        let sub = stepLen / Double(rat)
        gateLeft = tieActive ? -1 : sub * Double(min(16, max(1, Int(gate)))) / 16
        sRatLeft = rat - 1
        sRatInterval = sub
        sRatCountdown = sub
        sRatStep = s; sRatPattern = p
    }

    private func playDrumStep(_ p: Int, _ s: Int, stepLen: Double) {
        guard drumAudible else { return }
        for l in 0..<GrooveSeq.lanes where !laneMute[l] {
            let i = di(p, l, s)
            let v = Int(dVel[i])
            guard v > 0, passes(dCond[i]) else { continue }
            kit.trigger(l, velocity: v)
            let rat = max(1, Int(dRatchet[i]))
            dRatLeft[l] = rat - 1
            dRatInterval[l] = stepLen / Double(rat)
            dRatCountdown[l] = dRatInterval[l]
            dRatVel[l] = v
        }
    }

    /// Advance by `frames` samples (called once per 64-sample block).
    func advance(frames: Int, sampleRate: Double, sink: (FMEngine.Event) -> Void) {
        guard on else { return }
        let f = Double(frames)
        if !playing {
            if wasPlaying { wasPlaying = false; stopAll(sink); synthStep = -1; drumStep = -1 }
            return
        }
        if !wasPlaying {
            wasPlaying = true
            counter = -1
            samplesToNext = 0
        }
        // sub-step events: gate, ratchets
        if gateLeft >= 0 {
            gateLeft -= f
            if gateLeft < 0 { releaseSynth(sink) }
        }
        if sRatLeft > 0 {
            sRatCountdown -= f
            if sRatCountdown <= 0 {
                sRatLeft -= 1
                sRatCountdown += sRatInterval
                let i = si(sRatPattern, sRatStep)
                releaseSynth(sink)
                let b = i * GrooveSeq.notesPerStep
                for k in 0..<GrooveSeq.notesPerStep where sNotes[b + k] != 0 && synthAudible {
                    let n = Int(sNotes[b + k])
                    sink(.noteOn(UInt8(n), sVel[i]))
                    if soundingCount < sounding.count { sounding[soundingCount] = n; soundingCount += 1 }
                }
                gateLeft = sRatInterval * Double(min(16, max(1, Int(sGate[i])))) / 16
            }
        }
        for l in 0..<GrooveSeq.lanes where dRatLeft[l] > 0 {
            dRatCountdown[l] -= f
            if dRatCountdown[l] <= 0 {
                dRatLeft[l] -= 1
                dRatCountdown[l] += dRatInterval[l]
                if drumAudible && !laneMute[l] { kit.trigger(l, velocity: dRatVel[l]) }
            }
        }

        samplesToNext -= f
        stepPhase = curStepLen > 0 ? min(1, 1 - samplesToNext / curStepLen) : 0
        guard samplesToNext <= 0 else { return }

        // ---- new 1/16 step
        counter += 1
        if queuedPattern >= 0 && counter % 16 == 0 {
            pattern = queuedPattern
            queuedPattern = -1
            counter = 0
        }
        let p = pattern
        let base = 60.0 / max(20, tempo) * sampleRate / 4
        let sw = Double(min(75, max(50, swing[p])) - 50) / 50
        let len = counter % 2 == 0 ? base * (1 + sw) : base * (1 - sw)
        curStepLen = len
        samplesToNext += len
        if samplesToNext <= 0 { samplesToNext = len }
        stepPhase = 0

        let sl = max(1, min(GrooveSeq.steps, synthLen[p]))
        let dl = max(1, min(GrooveSeq.steps, drumLen[p]))
        synthStep = counter % sl
        drumStep = counter % dl
        playSynthStep(p, synthStep, stepLen: len, sink)
        playDrumStep(p, drumStep, stepLen: len)
    }
}
