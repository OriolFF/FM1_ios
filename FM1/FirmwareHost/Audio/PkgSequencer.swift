import Foundation

/// The host's step sequencer for package firmwares. Tracks are declared in the manifest;
/// a script edits step data (main thread, byte stores) and the audio thread plays it.
/// Per track: `patterns` × `rows` × 64 steps, where rows = 1 for a note track (up to four
/// notes a step) or the drum lane count. Per step: velocity (0 = empty), length in
/// quarter steps, chance, condition, ratchet, accent/slide flags, nudge and two locks.
final class PkgSequencer {
    static let steps = 64
    static let notesPerStep = 4
    static let locksPerStep = 2
    /// Step divisions, in quarter notes (beats).
    static let divNames = ["1/32", "1/16T", "1/16", "1/8T", "1/8", "1/4", "1/2", "1 BAR", "2 BARS", "4 BARS"]
    static let divBeats: [Double] = [0.125, 1.0 / 6, 0.25, 1.0 / 3, 0.5, 1, 2, 4, 8, 16]
    static let defaultDiv: UInt8 = 2
    static let rest: UInt8 = 0xFF

    // Conditions: 0 always, 1 FILL, 2 !FILL, 3 first loop, 4 not first, 100 + a*10 + b = A:B (a of every b loops)
    struct Track {
        let id: String
        let instrument: Int
        let rows: Int
        let isDrum: Bool
    }

    final class TrackData {
        let rows: Int
        let patterns: Int
        let count: Int                      // patterns*rows*steps
        let vel, len, chance, cond, ratchet, flags: UnsafeMutablePointer<UInt8>
        let nudge: UnsafeMutablePointer<Int8>
        let notes: UnsafeMutablePointer<UInt8>       // count*4
        let lockP, lockV: UnsafeMutablePointer<UInt8> // count*2
        let length, div: UnsafeMutablePointer<UInt8>  // per pattern
        init(patterns: Int, rows: Int) {
            self.rows = rows; self.patterns = patterns
            count = patterns * rows * PkgSequencer.steps
            func b(_ n: Int, _ v: UInt8) -> UnsafeMutablePointer<UInt8> { let p = UnsafeMutablePointer<UInt8>.allocate(capacity: n); p.initialize(repeating: v, count: n); return p }
            vel = b(count, 0); len = b(count, 3); chance = b(count, 100); cond = b(count, 0); ratchet = b(count, 1); flags = b(count, 0)
            nudge = .allocate(capacity: count); nudge.initialize(repeating: 0, count: count)
            notes = b(count * PkgSequencer.notesPerStep, 0)
            lockP = b(count * PkgSequencer.locksPerStep, PkgSequencer.rest)
            lockV = b(count * PkgSequencer.locksPerStep, 0)
            length = b(patterns, 16); div = b(patterns, PkgSequencer.defaultDiv)
        }
        deinit {
            for p in [vel, len, chance, cond, ratchet, flags, notes, lockP, lockV, length, div] { p.deallocate() }
            nudge.deallocate()
        }
        @inline(__always) func i(_ p: Int, _ r: Int, _ s: Int) -> Int { (p * rows + r) * PkgSequencer.steps + s }

        func clear(pattern p: Int) {
            for r in 0..<rows { for s in 0..<PkgSequencer.steps { clearStep(i(p, r, s)) } }
        }
        func clearStep(_ k: Int) {
            vel[k] = 0; len[k] = 3; chance[k] = 100; cond[k] = 0; ratchet[k] = 1; flags[k] = 0; nudge[k] = 0
            for n in 0..<PkgSequencer.notesPerStep { notes[k * PkgSequencer.notesPerStep + n] = 0 }
            for l in 0..<PkgSequencer.locksPerStep { lockP[k * PkgSequencer.locksPerStep + l] = PkgSequencer.rest; lockV[k * PkgSequencer.locksPerStep + l] = 0 }
        }
        func copyStep(_ from: Int, _ to: Int) {
            vel[to] = vel[from]; len[to] = len[from]; chance[to] = chance[from]; cond[to] = cond[from]
            ratchet[to] = ratchet[from]; flags[to] = flags[from]; nudge[to] = nudge[from]
            for n in 0..<PkgSequencer.notesPerStep { notes[to * 4 + n] = notes[from * 4 + n] }
            for l in 0..<PkgSequencer.locksPerStep { lockP[to * 2 + l] = lockP[from * 2 + l]; lockV[to * 2 + l] = lockV[from * 2 + l] }
        }
        func copy(pattern a: Int, to b: Int) {
            guard a != b else { return }
            for r in 0..<rows { for s in 0..<PkgSequencer.steps { copyStep(i(a, r, s), i(b, r, s)) } }
            length[b] = length[a]; div[b] = div[a]
        }
        func hasData(pattern p: Int) -> Bool {
            for r in 0..<rows { for s in 0..<PkgSequencer.steps where vel[i(p, r, s)] != 0 { return true } }
            return false
        }

        // persistence
        func serialize() -> Data {
            var d = Data()
            for p in [vel, len, chance, cond, ratchet, flags] { d.append(p, count: count) }
            d.append(UnsafeRawPointer(nudge).assumingMemoryBound(to: UInt8.self), count: count)
            d.append(notes, count: count * 4)
            d.append(lockP, count: count * 2); d.append(lockV, count: count * 2)
            d.append(length, count: patterns); d.append(div, count: patterns)
            return d
        }
        func restore(_ d: Data) {
            let need = count * 7 + count * 4 + count * 4 + patterns * 2
            guard d.count == need else { return }
            d.withUnsafeBytes { raw in
                let b = raw.bindMemory(to: UInt8.self)
                var o = 0
                func take(_ p: UnsafeMutablePointer<UInt8>, _ n: Int) { for k in 0..<n { p[k] = b[o + k] }; o += n }
                for p in [vel, len, chance, cond, ratchet, flags] { take(p, count) }
                for k in 0..<count { nudge[k] = Int8(bitPattern: b[o + k]) }; o += count
                take(notes, count * 4); take(lockP, count * 2); take(lockV, count * 2)
                take(length, patterns); take(div, patterns)
            }
        }
    }

    let tracks: [Track]
    let data: [TrackData]
    let patterns: Int
    private let instruments: [PkgInstrument]
    var onKick: (() -> Void)?

    // MARK: transport (main writes)
    var tempo: Double = 120
    var swing: Double = 50            // 50...75 % (MPC)
    var fill = false
    private(set) var playing = false
    private var startRequest = false
    private var stopRequest = false
    let mute: UnsafeMutablePointer<Bool>
    let laneMute: UnsafeMutablePointer<Bool>   // track*16 + lane
    /// Pattern selected per track (main writes; switches at the track's loop end while playing).
    let selected: UnsafeMutablePointer<Int>

    // MARK: song (main writes when stopped or between sections)
    static let maxSections = 64
    let songPatterns: UnsafeMutablePointer<UInt8>     // section*tracks + t (rest = 0xFF)
    let songRepeats: UnsafeMutablePointer<UInt8>
    var songLength = 0
    var songOn = false
    var songLoop = true
    private(set) var songSection = 0
    private var songRepeatLeft = 0

    // MARK: playback state (audio writes, main reads)
    private(set) var pos: Double = 0                  // beats since start
    let playing_ = UnsafeMutablePointer<Int>.allocate(capacity: 16)  // pattern playing per track
    let stepNow: UnsafeMutablePointer<Int>             // last fired step per track (-1)
    let stepTime: UnsafeMutablePointer<Double>         // nominal beat of that step
    let loopCount: UnsafeMutablePointer<Int>
    private let nextNominal: UnsafeMutablePointer<Double>
    private let nextIdx: UnsafeMutablePointer<Int>
    private let stepCounter: UnsafeMutablePointer<Int>
    // sounding notes per track (fixed 16 slots): note, off time
    private let sNote: UnsafeMutablePointer<Int>
    private let sOff: UnsafeMutablePointer<Double>
    // ratchets per track row (rows ≤ 16): remaining, interval, next time, velocity, step index
    private let rLeft: UnsafeMutablePointer<Int>
    private let rInterval: UnsafeMutablePointer<Double>
    private let rNext: UnsafeMutablePointer<Double>
    private let rVel: UnsafeMutablePointer<Int>
    private let rStep: UnsafeMutablePointer<Int>
    private var rng: UInt32 = 0x2545_F491
    private var lockedTracks: UInt32 = 0

    init(tracks: [Track], patterns: Int, instruments: [PkgInstrument]) {
        self.tracks = tracks
        self.patterns = max(1, min(16, patterns))
        self.instruments = instruments
        data = tracks.map { TrackData(patterns: max(1, min(16, patterns)), rows: $0.rows) }
        let T = max(1, tracks.count)
        func ints(_ n: Int, _ v: Int) -> UnsafeMutablePointer<Int> { let p = UnsafeMutablePointer<Int>.allocate(capacity: n); p.initialize(repeating: v, count: n); return p }
        func dbl(_ n: Int) -> UnsafeMutablePointer<Double> { let p = UnsafeMutablePointer<Double>.allocate(capacity: n); p.initialize(repeating: 0, count: n); return p }
        mute = .allocate(capacity: T); mute.initialize(repeating: false, count: T)
        laneMute = .allocate(capacity: T * 16); laneMute.initialize(repeating: false, count: T * 16)
        selected = ints(T, 0)
        playing_.initialize(repeating: 0, count: 16)
        stepNow = ints(T, -1); stepTime = dbl(T); loopCount = ints(T, 0)
        nextNominal = dbl(T); nextIdx = ints(T, 0); stepCounter = ints(T, 0)
        sNote = ints(T * 16, -1); sOff = dbl(T * 16)
        rLeft = ints(T * 16, 0); rInterval = dbl(T * 16); rNext = dbl(T * 16); rVel = ints(T * 16, 0); rStep = ints(T * 16, 0)
        songPatterns = .allocate(capacity: PkgSequencer.maxSections * T)
        songPatterns.initialize(repeating: 0, count: PkgSequencer.maxSections * T)
        songRepeats = .allocate(capacity: PkgSequencer.maxSections)
        songRepeats.initialize(repeating: 1, count: PkgSequencer.maxSections)
    }

    // MARK: main-thread API

    func play() { startRequest = true; stopRequest = false }
    func stop() { stopRequest = true; startRequest = false }
    var isPlaying: Bool { playing || startRequest }
    func playingPattern(_ t: Int) -> Int { playing ? playing_[t] : selected[t] }

    func stepBeats(_ t: Int, pattern p: Int) -> Double {
        let d = Int(data[t].div[p]); return PkgSequencer.divBeats[min(d, PkgSequencer.divBeats.count - 1)]
    }

    /// Nearest step to "now" on track t while playing, with the nudge (−8...7 16ths) from the grid.
    func nearestStep(_ t: Int) -> (step: Int, nudge: Int)? {
        guard playing, stepNow[t] >= 0 else { return nil }
        let p = playing_[t]
        let sb = stepBeats(t, pattern: p)
        let len = max(1, Int(data[t].length[p]))
        let phase = (pos - stepTime[t]) / sb
        var step = stepNow[t], frac = phase
        if phase > 0.5 { step = (step + Int(phase.rounded())) % len; frac = phase - phase.rounded() }
        let n = Int((frac * 16).rounded())
        return (step, min(7, max(-8, n)))
    }

    // MARK: audio thread

    @inline(__always) private func rand100() -> Int {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return Int(rng % 100)
    }

    private func passes(_ cond: UInt8, _ chance: UInt8, loop: Int) -> Bool {
        switch cond {
        case 1: if !fill { return false }
        case 2: if fill { return false }
        case 3: if loop != 0 { return false }
        case 4: if loop == 0 { return false }
        case 100...199:
            let a = (Int(cond) - 100) / 10, b = max(1, (Int(cond) - 100) % 10)
            if loop % b != (a - 1 + b) % b { return false }
        default: break
        }
        return chance >= 100 || rand100() < Int(chance)
    }

    private func releaseTrack(_ t: Int, keepNote: Int = -1) {
        let inst = instruments[tracks[t].instrument]
        for k in 0..<16 where sNote[t * 16 + k] >= 0 && sNote[t * 16 + k] != keepNote {
            inst.noteOff(sNote[t * 16 + k]); sNote[t * 16 + k] = -1
        }
    }

    private func startNote(_ t: Int, _ note: Int, _ vel: Int, off: Double, slide: Bool, accent: Bool) {
        let inst = instruments[tracks[t].instrument]
        // same note already sounding (tie/slide continuation): extend
        for k in 0..<16 where sNote[t * 16 + k] == note {
            if slide { sOff[t * 16 + k] = off; return }
            inst.noteOff(note); sNote[t * 16 + k] = -1
        }
        inst.noteOn(note, vel: vel, slide: slide, accent: accent)
        for k in 0..<16 where sNote[t * 16 + k] < 0 { sNote[t * 16 + k] = note; sOff[t * 16 + k] = off; return }
    }

    private func applySongSection(_ s: Int) {
        let T = tracks.count
        for t in 0..<T { let p = songPatterns[s * T + t]; if p != PkgSequencer.rest { selected[t] = Int(p) } }
        songRepeatLeft = max(1, Int(songRepeats[s]))
    }

    @inline(__always) private func sectionRests(_ t: Int) -> Bool {
        songOn && songLength > 0 && songPatterns[songSection * tracks.count + t] == PkgSequencer.rest
    }

    private func fire(_ t: Int, step s: Int, pattern p: Int, time ft: Double, sb: Double) {
        let d = data[t]
        let inst = instruments[tracks[t].instrument]
        // locks: from this step until a step without them
        inst.clearLocks()
        let muted = mute[t] || sectionRests(t)
        for r in 0..<d.rows {
            let k = d.i(p, r, s)
            for l in 0..<PkgSequencer.locksPerStep where d.lockP[k * 2 + l] != PkgSequencer.rest {
                inst.applyLock(Int(d.lockP[k * 2 + l]), d.lockV[k * 2 + l])
            }
            let v = Int(d.vel[k])
            guard v > 0, !muted, !(tracks[t].isDrum && laneMute[t * 16 + min(r, 15)]) else { continue }
            guard passes(d.cond[k], d.chance[k], loop: loopCount[t]) else { continue }
            let accent = d.flags[k] & 1 != 0, slide = d.flags[k] & 2 != 0
            let rat = max(1, Int(d.ratchet[k]))
            if tracks[t].isDrum {
                inst.hit(r, vel: accent ? min(127, v + 24) : v)
                if r == 0 { onKick?() }
            } else {
                let off = ft + sb * Double(max(1, Int(d.len[k]))) / 4 / Double(rat) * (rat > 1 ? 0.6 : 1)
                if !slide { releaseTrack(t) } else {
                    // slide: release everything not in this step
                    releaseTrack(t, keepNote: Int(d.notes[k * 4]))
                }
                for n in 0..<PkgSequencer.notesPerStep {
                    let note = Int(d.notes[k * 4 + n])
                    if note > 0 { startNote(t, note, v, off: off, slide: slide, accent: accent) }
                }
            }
            if rat > 1 {
                let slot = t * 16 + min(r, 15)
                rLeft[slot] = rat - 1; rInterval[slot] = sb / Double(rat); rNext[slot] = ft + sb / Double(rat)
                rVel[slot] = v; rStep[slot] = k
            }
        }
    }

    /// Called once per control block from PackageEngine.advance.
    func advance(frames: Int, sampleRate: Double) {
        let T = tracks.count
        if stopRequest {
            stopRequest = false
            if playing { for t in 0..<T { releaseTrack(t); instruments[tracks[t].instrument].clearLocks(); stepNow[t] = -1 } }
            playing = false
        }
        if startRequest {
            startRequest = false
            playing = true
            pos = 0
            if songOn && songLength > 0 { songSection = 0; applySongSection(0) }
            for t in 0..<T {
                nextNominal[t] = 0; nextIdx[t] = 0; stepCounter[t] = 0; loopCount[t] = 0; stepNow[t] = -1
                playing_[t] = selected[t]
                for r in 0..<16 { rLeft[t * 16 + r] = 0 }
            }
        }
        guard playing else { return }
        let blockBeats = Double(frames) / sampleRate * tempo / 60
        let end = pos + blockBeats
        let swingAmt = (min(max(swing, 50), 75) - 50) / 50
        for t in 0..<T {
            let d = data[t]
            var guardCount = 0
            while guardCount < 8 {
                guardCount += 1
                let idx = nextIdx[t]
                var p = playing_[t]
                if idx == 0 { p = selected[t] }
                let sb = stepBeats(t, pattern: p)
                let swingOff = (stepCounter[t] & 1 == 1 && sb <= 0.5) ? swingAmt * sb : 0
                // nudge of the step (max across rows; note tracks have one row)
                var nudge = 0
                for r in 0..<d.rows { let k = d.i(p, r, idx); if d.vel[k] != 0 { nudge = Int(d.nudge[k]); break } }
                let ft = nextNominal[t] + swingOff + Double(nudge) * sb / 16
                if ft >= end { break }
                if idx == 0 {
                    if stepCounter[t] > 0 { loopCount[t] += 1 }
                    if t == 0 && songOn && songLength > 0 && stepCounter[t] > 0 {
                        songRepeatLeft -= 1
                        if songRepeatLeft <= 0 {
                            var next = songSection + 1
                            if next >= songLength { next = songLoop ? 0 : -1 }
                            if next < 0 { stopRequest = true; return }
                            songSection = next
                            applySongSection(next)
                            // other tracks restart with the section
                            for u in 1..<max(1, T) { nextIdx[u] = 0; nextNominal[u] = nextNominal[0]; playing_[u] = selected[u] }
                        }
                    }
                    playing_[t] = selected[t]
                    p = playing_[t]
                }
                stepNow[t] = idx
                stepTime[t] = nextNominal[t]
                fire(t, step: idx, pattern: p, time: max(ft, pos), sb: sb)
                nextNominal[t] += sb
                stepCounter[t] += 1
                nextIdx[t] = (idx + 1) % max(1, min(PkgSequencer.steps, Int(d.length[p])))
            }
            // ratchet repeats and note-offs inside this block
            let inst = instruments[tracks[t].instrument]
            for r in 0..<min(d.rows, 16) {
                let slot = t * 16 + r
                while rLeft[slot] > 0 && rNext[slot] < end {
                    rLeft[slot] -= 1
                    let k = rStep[slot]
                    if tracks[t].isDrum {
                        inst.hit(r, vel: max(1, rVel[slot] - 6))
                        if r == 0 { onKick?() }
                    } else {
                        releaseTrack(t)
                        let off = rNext[slot] + rInterval[slot] * 0.6
                        for n in 0..<PkgSequencer.notesPerStep {
                            let note = Int(d.notes[k * 4 + n])
                            if note > 0 { startNote(t, note, rVel[slot], off: off, slide: false, accent: false) }
                        }
                    }
                    rNext[slot] += rInterval[slot]
                }
            }
            if !tracks[t].isDrum {
                for k in 0..<16 where sNote[t * 16 + k] >= 0 && sOff[t * 16 + k] < end {
                    // a following tied/slid step re-extends before this point; otherwise release
                    inst.noteOff(sNote[t * 16 + k]); sNote[t * 16 + k] = -1
                }
            }
        }
        pos = end
    }
}
