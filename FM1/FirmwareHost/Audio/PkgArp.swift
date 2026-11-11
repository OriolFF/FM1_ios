import Foundation

/// Native arpeggiator for one package instrument, clocked on the audio thread.
/// Live keys for its instrument go here instead of to the instrument while `on` is set.
/// While the package sequencer plays, steps fall on its beat grid; stopped, the arp runs free
/// at the sequencer tempo and the first key of a phrase sounds at once.
/// Settings are plain stores from the main thread, read once per block.
/// Modes follow Felucca's documented list; the chord modes (DNUP…CHORD) are this host's own
/// reading of their names, since the documentation does not define them.
final class PkgArp {
    static let modeNames = ["UP", "DN", "UPDN", "RND", "ORD", "REPEAT", "DNUP", "UP+8", "CONV", "DIVG", "PINKY", "THUMB", "WALK", "CHORD"]
    /// Step lengths in beats, matching the names in `rateNames`.
    static let rates: [Double] = [1, 0.5, 1.0 / 3, 0.25, 1.0 / 6, 0.125, 1.0 / 12, 0.0625]
    static let rateNames = ["1/4", "1/8", "1/8T", "1/16", "1/16T", "1/32", "1/32T", "1/64"]

    // MARK: settings (main thread writes)
    var on = false
    var mode = 0
    var rate = 3
    var octaves = 1          // 1...4
    var gate: Double = 0.5   // 0.05...1 of a step
    var latch = false
    /// Steps fired since the phrase began (audio writes, main reads for a beat LED).
    private(set) var stepCount = 0

    // MARK: audio-thread state
    private var held = [Int](repeating: 0, count: 32)
    private var heldVel = [Int](repeating: 100, count: 32)
    private var heldCount = 0
    private var physical = [Bool](repeating: false, count: 128)
    private var physicalCount = 0
    private var buf = [Int](repeating: 0, count: 512)
    private var sorted = [Int](repeating: 0, count: 32)
    private var tmp = [Int](repeating: 0, count: 512)
    private var sounding = [Int](repeating: -1, count: 16)
    private var offAt = [Double](repeating: 0, count: 16)
    private var index = 0
    private var walk = 0
    private var nextBeat: Double = 0
    private var wasOn = false
    private var wasSynced = false
    private var freeClock: Double = 0
    private var restart = false
    private var rng: UInt32 = 0x1234_5679

    // MARK: keys (audio thread)

    func keyDown(_ note: Int, vel: Int) {
        guard note >= 0 && note < 128 else { return }
        if latch && physicalCount == 0 && heldCount > 0 { heldCount = 0; index = 0 }
        if heldCount == 0 { restart = true; index = 0; walk = 0 }
        if !physical[note] { physical[note] = true; physicalCount += 1 }
        for i in 0..<heldCount where held[i] == note { heldVel[i] = vel; return }
        if heldCount < held.count { held[heldCount] = note; heldVel[heldCount] = vel; heldCount += 1 }
    }

    /// Returns false when the key was not held by the arp (so the caller releases it directly).
    @discardableResult
    func keyUp(_ note: Int) -> Bool {
        guard note >= 0 && note < 128, physical[note] else { return false }
        physical[note] = false; physicalCount -= 1
        if !latch { remove(note) }
        return true
    }

    private func remove(_ note: Int) {
        var j = 0
        for i in 0..<heldCount where held[i] != note { held[j] = held[i]; heldVel[j] = heldVel[i]; j += 1 }
        heldCount = j
    }

    func reset(_ inst: PkgInstrument) {
        releaseSounding(inst)
        heldCount = 0; physicalCount = 0
        for i in 0..<128 { physical[i] = false }
    }

    private func releaseSounding(_ inst: PkgInstrument) {
        for k in 0..<sounding.count where sounding[k] >= 0 { inst.noteOff(sounding[k]); sounding[k] = -1 }
    }

    private func rand() -> Int { rng = rng &* 1664525 &+ 1013904223; return Int(rng >> 8) }

    // MARK: pattern

    /// Fills `buf` with this cycle's notes for the current mode; returns the count.
    private func build() -> Int {
        let n0 = heldCount
        guard n0 > 0 else { return 0 }
        var s = 0
        for i in 0..<n0 { sorted[s] = held[i]; s += 1 }
        if mode != 4 {                                 // ORD keeps the playing order; insertion sort, no allocation
            for i in 1..<max(1, s) { let v = sorted[i]; var j = i - 1; while j >= 0 && sorted[j] > v { sorted[j + 1] = sorted[j]; j -= 1 }; sorted[j + 1] = v }
        }
        var n = 0
        let oct = min(max(octaves, 1), 4)
        for o in 0..<oct { for i in 0..<s where n < 128 { buf[n] = sorted[i] + 12 * o; n += 1 } }
        let m = n
        func append(_ v: Int) { if n < buf.count { buf[n] = v; n += 1 } }
        switch mode {
        case 1: buf[0..<m].reverse()                                               // DN
        case 2: if m > 2 { for i in stride(from: m - 2, through: 1, by: -1) { append(buf[i]) } }   // UPDN
        case 6:                                                                     // DNUP
            buf[0..<m].reverse()
            if m > 2 { for i in stride(from: m - 2, through: 1, by: -1) { append(buf[i]) } }
        case 7:                                                                     // UP+8: each note, then its octave
            for i in stride(from: m - 1, through: 0, by: -1) { buf[2 * i + 1] = buf[i] + 12; buf[2 * i] = buf[i] }
            n = min(2 * m, buf.count)
        case 8, 9:                                                                  // CONV outside-in, DIVG inside-out
            var t = 0, lo = 0, hi = m - 1
            while lo <= hi { tmp[t] = buf[lo]; t += 1; if hi != lo { tmp[t] = buf[hi]; t += 1 }; lo += 1; hi -= 1 }
            for i in 0..<m { buf[i] = mode == 9 ? tmp[m - 1 - i] : tmp[i] }
        case 10, 11:                                                                // PINKY: top between; THUMB: bottom between
            guard m > 1 else { break }
            let pivot = mode == 10 ? buf[m - 1] : buf[0]
            let start = mode == 10 ? 0 : 1, end = mode == 10 ? m - 1 : m
            var t = 0
            for i in start..<end where t + 1 < tmp.count { tmp[t] = buf[i]; tmp[t + 1] = pivot; t += 2 }
            n = t
            for i in 0..<n { buf[i] = tmp[i] }
        default: break
        }
        return n
    }

    private func velocity(of note: Int) -> Int {
        for i in 0..<heldCount where note >= held[i] && (note - held[i]) % 12 == 0 { return heldVel[i] }
        return heldCount > 0 ? heldVel[heldCount - 1] : 100
    }

    private func play(_ inst: PkgInstrument, _ note: Int, _ vel: Int, off: Double) {
        guard note >= 0 && note < 128 else { return }
        inst.noteOn(note, vel: vel, slide: false, accent: false)
        for k in 0..<sounding.count where sounding[k] < 0 { sounding[k] = note; offAt[k] = off; return }
    }

    // MARK: clock (audio thread)

    /// `beat` is the sequencer position at the start of this block when `synced`.
    func advance(inst: PkgInstrument, synced: Bool, beat: Double, blockBeats: Double, swing: Double) {
        if !on {
            if wasOn { reset(inst); wasOn = false }
            return
        }
        if !wasOn { wasOn = true; restart = true }
        if !latch && physicalCount == 0 && heldCount > 0 { heldCount = 0 }
        let clock = synced ? beat : freeClock
        if !synced { freeClock += blockBeats }
        let end = clock + blockBeats
        let L = PkgArp.rates[min(max(rate, 0), PkgArp.rates.count - 1)]
        if synced != wasSynced { wasSynced = synced; nextBeat = synced ? (clock / L).rounded(.up) * L : clock }
        if restart {
            restart = false; stepCount = 0
            if synced {
                // a key a little late for a grid line still takes it
                let g = (clock / L).rounded(.down) * L
                nextBeat = clock - g < L * 0.15 ? clock : g + L
            } else { nextBeat = clock }
        }
        // note-offs due in this block
        for k in 0..<sounding.count where sounding[k] >= 0 && offAt[k] < end { inst.noteOff(sounding[k]); sounding[k] = -1 }
        guard heldCount > 0 else { nextBeat = max(nextBeat, end); return }
        if nextBeat < clock - L { nextBeat = clock }   // fell behind (tempo jump): resync
        var guardCount = 0
        let swingAmt = (min(max(swing, 50), 75) - 50) / 50
        while guardCount < 8 {
            // odd steps are late by the swing amount (as the sequencer does for steps of 1/8 or shorter)
            let swingOff = (stepCount & 1 == 1 && L <= 0.5) ? swingAmt * L : 0
            let t = nextBeat + swingOff
            guard t < end else { break }
            guardCount += 1
            let n = build()
            guard n > 0 else { break }
            let off = t + L * min(max(gate, 0.05), 1)
            releaseSounding(inst)
            switch mode {
            case 13:                                                     // CHORD: every held note each step
                for i in 0..<heldCount { play(inst, held[i], heldVel[i], off: off) }
            case 5:                                                      // REPEAT: the latest key
                play(inst, held[heldCount - 1], heldVel[heldCount - 1], off: off)
            case 3:                                                      // RND
                let note = buf[rand() % n]; play(inst, note, velocity(of: note), off: off)
            case 12:                                                     // WALK: one step up or down
                walk = min(max(walk + (rand() & 1 == 0 ? -1 : 1), 0), n - 1)
                play(inst, buf[walk], velocity(of: buf[walk]), off: off)
            default:
                let note = buf[index % n]; index = (index + 1) % n
                play(inst, note, velocity(of: note), off: off)
            }
            stepCount += 1
            nextBeat += L
        }
    }
}
