import Foundation

/// Arpeggiator + 16-pattern × 16-step sequencer, clocked on the audio thread.
/// Pattern data lives in fixed unsafe buffers so the UI thread can edit it
/// while the audio thread reads it (byte-sized benign races, no reallocation).
final class ArpSeq: @unchecked Sendable {
    enum ArpMode: Int, CaseIterable {
        case up, down, inclusive, exclusive, random, order, `repeat`
        var label: String { ["Up", "Down", "Inclusive", "Exclusive", "Random", "Order", "Repeat"][rawValue] }
    }
    /// Note values in beats.
    static let rates: [(String, Double)] = [
        ("1/1", 4), ("1/2", 2), ("1/4", 1), ("1/4T", 2.0 / 3), ("1/8", 0.5), ("1/8T", 1.0 / 3),
        ("1/16", 0.25), ("1/16T", 1.0 / 6), ("1/32", 0.125), ("1/32T", 1.0 / 12),
    ]

    static let patterns = 16
    static let steps = 16
    static let notesPerStep = 6

    // MARK: Arp settings
    var arpOn = false
    var arpMode: ArpMode = .up
    var arpOctaves = 1
    var arpRate = 6           // 1/16
    var arpGate = 50          // 20...100 %
    var arpSwing = 50         // 50...75 %
    var arpLatch = false
    /// Set by the UI when the arpeggiator is switched on: forget old (latched) notes.
    var arpResetRequest = false
    var tempo: Double = 120   // shared by ARP and SEQ

    // MARK: Sequencer settings / data
    var seqOn = false
    var playing = false
    var pattern = 0
    let stepNotes: UnsafeMutablePointer<UInt8>     // [pattern][step][note] 0 = empty
    let stepRate: UnsafeMutablePointer<UInt8>      // [pattern][step] 0xFF = pattern rate
    let stepTie: UnsafeMutablePointer<UInt8>       // [pattern][step] 1 = continue previous step
    var patLength = [Int](repeating: 16, count: 16)
    var patRate = [Int](repeating: 6, count: 16)
    var patGate = [Int](repeating: 60, count: 16)
    var patSwing = [Int](repeating: 50, count: 16)
    var patChain = [Int](repeating: 1, count: 16)
    var patTranspose = [Int](repeating: 0, count: 16)
    var patVoice = [Int](repeating: -1, count: 16)  // -1 = none

    /// Step being played (audio writes, UI reads); -1 stopped.
    private(set) var currentStep = -1
    private(set) var currentPattern = 0
    var velocity: UInt8 = 100

    // MARK: Audio-thread state
    private var held = [Int](repeating: 0, count: 32)
    private var heldCount = 0
    private var physical = [Bool](repeating: false, count: 128)
    private var physicalCount = 0
    private var arpSeqBuf = [Int](repeating: 0, count: 512)
    private var arpIndex = 0
    private var arpRepeat = 0
    private var arpStepCount = 0
    private var samplesToNext: Double = 0
    private var gateLeft: Double = -1
    private var soundingArp = -1
    private var seqToNext: Double = 0
    private var seqGateLeft: Double = -1
    private var seqSounding = [Int](repeating: 0, count: 8)
    private var seqSoundingCount = 0
    private var wasPlaying = false
    private var chainIndex = 0
    private var rngState: UInt32 = 0x9E37_79B9

    init() {
        let n = ArpSeq.patterns * ArpSeq.steps
        stepNotes = .allocate(capacity: n * ArpSeq.notesPerStep)
        stepNotes.initialize(repeating: 0, count: n * ArpSeq.notesPerStep)
        stepRate = .allocate(capacity: n); stepRate.initialize(repeating: 0xFF, count: n)
        stepTie = .allocate(capacity: n); stepTie.initialize(repeating: 0, count: n)
    }

    // MARK: Step data helpers (UI thread)

    func notes(pattern p: Int, step s: Int) -> [Int] {
        let b = (p * ArpSeq.steps + s) * ArpSeq.notesPerStep
        return (0..<ArpSeq.notesPerStep).compactMap { stepNotes[b + $0] == 0 ? nil : Int(stepNotes[b + $0]) }
    }
    func setNotes(pattern p: Int, step s: Int, _ notes: [Int]) {
        let b = (p * ArpSeq.steps + s) * ArpSeq.notesPerStep
        for i in 0..<ArpSeq.notesPerStep { stepNotes[b + i] = i < notes.count ? UInt8(clamping: max(1, notes[i])) : 0 }
    }
    func addNote(pattern p: Int, step s: Int, _ note: Int) {
        var n = notes(pattern: p, step: s)
        if !n.contains(note) && n.count < ArpSeq.notesPerStep { n.append(note); setNotes(pattern: p, step: s, n) }
    }
    func clear(pattern p: Int) {
        for s in 0..<ArpSeq.steps {
            setNotes(pattern: p, step: s, [])
            stepRate[p * ArpSeq.steps + s] = 0xFF
            stepTie[p * ArpSeq.steps + s] = 0
        }
    }
    func hasNotes(pattern p: Int, step s: Int) -> Bool {
        let b = (p * ArpSeq.steps + s) * ArpSeq.notesPerStep
        return stepNotes[b] != 0 || stepTie[p * ArpSeq.steps + s] != 0
    }

    // MARK: Key routing (audio thread)

    var consumesKeys: Bool { arpOn }

    func keyDown(_ note: Int, vel: Int) {
        guard note >= 0 && note < 128 else { return }
        if arpLatch && physicalCount == 0 && heldCount > 0 {
            // latch: a new chord replaces the latched one, the clock keeps running
            heldCount = 0; arpIndex = 0
        } else if heldCount == 0 {
            // first key of a new phrase: play it straight away instead of waiting for the running clock
            samplesToNext = 0; arpStepCount = 0; arpIndex = 0
        }
        if !physical[note] { physical[note] = true; physicalCount += 1 }
        for i in 0..<heldCount where held[i] == note { return }
        if heldCount < held.count { held[heldCount] = note; heldCount += 1 }
    }

    func keyUp(_ note: Int) {
        guard note >= 0 && note < 128 else { return }
        if physical[note] { physical[note] = false; physicalCount -= 1 }
        if !arpLatch { removeHeld(note) }
    }

    private func removeHeld(_ note: Int) {
        var j = 0
        for i in 0..<heldCount where held[i] != note { held[j] = held[i]; j += 1 }
        heldCount = j
    }

    func releaseAll() {
        heldCount = 0
        for i in 0..<128 { physical[i] = false }
        physicalCount = 0
    }

    private func buildArp() -> Int {
        guard heldCount > 0 else { return 0 }
        var base = Array(held[0..<heldCount])
        if arpMode != .order && arpMode != .random { base.sort() }
        var n = 0
        for o in 0..<max(1, arpOctaves) {
            for b in base where n < 256 { arpSeqBuf[n] = b + 12 * o; n += 1 }
        }
        switch arpMode {
        case .down:
            arpSeqBuf[0..<n].reverse()
        case .inclusive:
            // up then down, endpoints repeated
            let m = n
            for i in stride(from: m - 1, through: 0, by: -1) where n < 512 { arpSeqBuf[n] = arpSeqBuf[i]; n += 1 }
        case .exclusive:
            let m = n
            if m > 2 { for i in stride(from: m - 2, through: 1, by: -1) where n < 512 { arpSeqBuf[n] = arpSeqBuf[i]; n += 1 } }
        default: break
        }
        return n
    }

    private func rand() -> UInt32 { rngState = rngState &* 1664525 &+ 1013904223; return rngState >> 8 }

    // MARK: Clock (audio thread)

    func advance(frames: Int, sampleRate: Double, sink: (FMEngine.Event) -> Void) {
        let beat = 60.0 / max(20, tempo) * sampleRate

        // ---- ARP
        if arpResetRequest {
            arpResetRequest = false
            releaseAll()
            if soundingArp >= 0 { sink(.noteOff(UInt8(soundingArp))); soundingArp = -1 }
            samplesToNext = 0; arpIndex = 0; arpStepCount = 0; gateLeft = -1
        }
        if arpOn {
            // latch switched off with no key down: let the latched notes go
            if !arpLatch && physicalCount == 0 && heldCount > 0 { heldCount = 0 }
            if gateLeft >= 0 {
                gateLeft -= Double(frames)
                if gateLeft < 0, soundingArp >= 0 { sink(.noteOff(UInt8(soundingArp))); soundingArp = -1 }
            }
            samplesToNext -= Double(frames)
            if samplesToNext <= 0 {
                var len = beat * ArpSeq.rates[min(arpRate, ArpSeq.rates.count - 1)].1
                let sw = Double(arpSwing - 50) / 50  // 0 ... 0.5
                len *= arpStepCount % 2 == 0 ? (1 + sw) : (1 - sw)
                arpStepCount += 1
                samplesToNext += len
                if samplesToNext < 0 { samplesToNext = len }
                if soundingArp >= 0 { sink(.noteOff(UInt8(soundingArp))); soundingArp = -1 }
                let n = buildArp()
                if n > 0 {
                    var note: Int
                    if arpMode == .random {
                        note = arpSeqBuf[Int(rand()) % n]
                    } else if arpMode == .repeat {
                        let idx = (arpIndex / 2) % n
                        note = arpSeqBuf[idx]; arpIndex += 1
                    } else {
                        note = arpSeqBuf[arpIndex % n]; arpIndex += 1
                    }
                    note = max(0, min(127, note))
                    sink(.noteOn(UInt8(note), velocity))
                    soundingArp = note
                    gateLeft = len * Double(arpGate) / 100
                } else {
                    arpIndex = 0
                }
            }
        } else if soundingArp >= 0 {
            sink(.noteOff(UInt8(soundingArp))); soundingArp = -1
        }

        // ---- SEQUENCER
        if seqOn && playing {
            if !wasPlaying {
                seqToNext = 0; currentStep = -1; chainIndex = 0; currentPattern = pattern; wasPlaying = true
            }
            let p = currentPattern
            if seqGateLeft >= 0 {
                seqGateLeft -= Double(frames)
                if seqGateLeft < 0 { stopSeqNotes(sink) }
            }
            seqToNext -= Double(frames)
            if seqToNext <= 0 {
                var next = currentStep + 1
                if next >= max(1, min(patLength[p], ArpSeq.steps)) {
                    next = 0
                    // pattern chain
                    let chain = max(1, patChain[pattern])
                    chainIndex = (chainIndex + 1) % chain
                    currentPattern = (pattern + chainIndex) % ArpSeq.patterns
                }
                currentStep = next
                let cp = currentPattern
                let si = cp * ArpSeq.steps + next
                let rateIdx = stepRate[si] == 0xFF ? patRate[cp] : Int(stepRate[si])
                var len = beat * ArpSeq.rates[min(rateIdx, ArpSeq.rates.count - 1)].1
                let sw = Double(patSwing[cp] - 50) / 50
                len *= next % 2 == 0 ? (1 + sw) : (1 - sw)
                seqToNext += len
                if seqToNext < 0 { seqToNext = len }
                if stepTie[si] != 0 {
                    // long note: keep sounding, extend gate
                    seqGateLeft = len * Double(patGate[cp]) / 100
                } else {
                    stopSeqNotes(sink)
                    let b = si * ArpSeq.notesPerStep
                    for k in 0..<ArpSeq.notesPerStep {
                        let raw = Int(stepNotes[b + k])
                        if raw == 0 { continue }
                        let n = max(0, min(127, raw + patTranspose[cp]))
                        sink(.noteOn(UInt8(n), velocity))
                        if seqSoundingCount < seqSounding.count { seqSounding[seqSoundingCount] = n; seqSoundingCount += 1 }
                    }
                    seqGateLeft = len * Double(patGate[cp]) / 100
                }
            }
        } else if wasPlaying {
            wasPlaying = false
            currentStep = -1
            stopSeqNotes(sink)
        }
    }

    private func stopSeqNotes(_ sink: (FMEngine.Event) -> Void) {
        for i in 0..<seqSoundingCount { sink(.noteOff(UInt8(seqSounding[i]))) }
        seqSoundingCount = 0
        seqGateLeft = -1
    }
}
