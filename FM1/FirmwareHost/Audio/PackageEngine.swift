import Foundation
import os

/// The realtime half of a package firmware: the instruments its manifest declares, the
/// host sequencer and the master bus, attached to FMEngine as its block hook.
/// The main thread (script bridge) posts live notes into a lock-protected mailbox that the
/// audio thread drains with `withLockIfAvailable` (never blocks), and edits parameters and
/// step data with plain stores, like the rest of the app's engine code.
final class PackageEngine: FMBlockHook, @unchecked Sendable {
    enum Live { case on(UInt8, UInt8, UInt8), off(UInt8, UInt8), hit(UInt8, UInt8, UInt8), allOff, panic }

    let instruments: [PkgInstrument]
    let instrumentIDs: [String]
    let levels: UnsafeMutablePointer<Float>     // per instrument
    let instMute: UnsafeMutablePointer<Bool>
    let seq: PkgSequencer
    let master: MasterBus
    /// One arpeggiator per instrument (off by default).
    let arps: [PkgArp]
    unowned let fm: FMEngine
    private let fmIndex: Int
    private let fmInst: FMInstrument?
    private let drumMask: [Bool]
    private let synthBus: UnsafeMutablePointer<Float>
    private let drumBus: UnsafeMutablePointer<Float>
    private let scratch: UnsafeMutablePointer<Float>
    private struct Mail { var items: [Live] = []; init() { items.reserveCapacity(256) } }
    private let mailbox = OSAllocatedUnfairLock(initialState: Mail())
    private let pending: UnsafeMutablePointer<Live>
    private let pendingCap = 256
    /// Scope of the package mix (for screens), like FMEngine.scope.
    static let scopeSize = 1024
    let scope: UnsafeMutablePointer<Float>
    private(set) var scopeWrite = 0

    init(manifest: FirmwareManifest.Engine, fm: FMEngine, sampleRate: Float) {
        self.fm = fm
        var insts: [PkgInstrument] = []
        var ids: [String] = []
        var fmi = -1
        for d in manifest.instruments.prefix(8) {
            let inst: PkgInstrument
            switch d.type {
            case "fm" where fmi < 0:
                inst = FMInstrument(engine: fm); fmi = insts.count
            case "pd": inst = PDSynth(sampleRate: sampleRate, voices: d.voices ?? 6)
            case "drums": inst = DrumsInstrument(sampleRate: sampleRate)
            case "slot":
                let s = SlotInstrument(engines: d.engines ?? ["va"], sampleRate: sampleRate, voices: d.voices ?? 6)
                if let e = d.engine { _ = s.select(e) }
                inst = s
            default: inst = VASynth(sampleRate: sampleRate, voices: d.voices ?? 6)
            }
            insts.append(inst); ids.append(d.id)
        }
        instruments = insts
        instrumentIDs = ids
        arps = insts.map { _ in PkgArp() }
        fmIndex = fmi
        fmInst = fmi >= 0 ? insts[fmi] as? FMInstrument : nil
        drumMask = insts.map { $0 is DrumsInstrument }
        levels = .allocate(capacity: max(1, insts.count)); levels.initialize(repeating: 1, count: max(1, insts.count))
        instMute = .allocate(capacity: max(1, insts.count)); instMute.initialize(repeating: false, count: max(1, insts.count))
        let tracks: [PkgSequencer.Track] = (manifest.sequencer?.tracks ?? []).prefix(8).compactMap { t in
            guard let i = ids.firstIndex(of: t.instrument) else { return nil }
            let drum = insts[i] is DrumsInstrument
            return PkgSequencer.Track(id: t.id, instrument: i, rows: drum ? min(t.lanes ?? DrumKit.laneCount, DrumKit.laneCount) : 1, isDrum: drum)
        }
        seq = PkgSequencer(tracks: tracks, patterns: manifest.sequencer?.patterns ?? 8, instruments: insts)
        master = MasterBus(sampleRate: sampleRate)
        func buf() -> UnsafeMutablePointer<Float> { let p = UnsafeMutablePointer<Float>.allocate(capacity: FMEngine.blockSize); p.initialize(repeating: 0, count: FMEngine.blockSize); return p }
        synthBus = buf(); drumBus = buf(); scratch = buf()
        pending = .allocate(capacity: pendingCap); pending.initialize(repeating: .allOff, count: pendingCap)
        scope = .allocate(capacity: PackageEngine.scopeSize); scope.initialize(repeating: 0, count: PackageEngine.scopeSize)
        let m = master
        seq.onKick = { m.kick() }
    }

    deinit {
        for p in [synthBus, drumBus, scratch, scope] { p.deallocate() }
        levels.deallocate(); instMute.deallocate(); pending.deallocate()
    }

    func index(of id: String) -> Int? { instrumentIDs.firstIndex(of: id) }

    // MARK: main thread

    func post(_ e: Live) { mailbox.withLock { if $0.items.count < 250 { $0.items.append(e) } } }
    func noteOn(_ inst: Int, _ note: Int, _ vel: Int) { post(.on(UInt8(clamping: inst), UInt8(clamping: note), UInt8(clamping: max(1, vel)))) }
    func noteOff(_ inst: Int, _ note: Int) { post(.off(UInt8(clamping: inst), UInt8(clamping: note))) }
    func hit(_ inst: Int, _ lane: Int, _ vel: Int) { post(.hit(UInt8(clamping: inst), UInt8(clamping: lane), UInt8(clamping: max(1, vel)))) }

    // MARK: FMBlockHook (audio thread)

    func advance(frames: Int, sampleRate: Double, sink: (FMEngine.Event) -> Void) {
        var count = 0
        let pend = pending, cap = pendingCap
        _ = mailbox.withLockIfAvailableUnchecked { m in
            for e in m.items where count < cap { pend[count] = e; count += 1 }
            m.items.removeAll(keepingCapacity: true)
        }
        for k in 0..<count {
            switch pending[k] {
            case let .on(i, n, v):
                guard Int(i) < instruments.count else { break }
                if arps[Int(i)].on { arps[Int(i)].keyDown(Int(n), vel: Int(v)) }
                else { instruments[Int(i)].noteOn(Int(n), vel: Int(v), slide: false, accent: false) }
            case let .off(i, n):
                guard Int(i) < instruments.count else { break }
                // a key pressed before the arp was switched on still releases its own note
                if !(arps[Int(i)].on && arps[Int(i)].keyUp(Int(n))) {
                    arps[Int(i)].keyUp(Int(n))
                    instruments[Int(i)].noteOff(Int(n))
                }
            case let .hit(i, l, v):
                if Int(i) < instruments.count {
                    instruments[Int(i)].hit(Int(l), vel: Int(v))
                    if l == 0 && drumMask[Int(i)] { master.kick() }
                }
            case .allOff: for inst in instruments { inst.allOff() }
            case .panic:
                for inst in instruments { inst.allOff() }
                sink(.panic)
            }
        }
        master.tempo = seq.tempo
        let blockBeats = Double(frames) / sampleRate * seq.tempo / 60
        for (i, arp) in arps.enumerated() {
            arp.advance(inst: instruments[i], synced: seq.playing, beat: seq.pos, blockBeats: blockBeats, swing: seq.swing)
        }
        seq.advance(frames: frames, sampleRate: sampleRate)
        fmInst?.flush(sink)
    }

    func mix(frames n: Int, out: UnsafeMutablePointer<Float>) {
        let mv = fm.masterVolume
        // FM voices are already in `out` (with master volume applied by FMEngine)
        let fmGain: Float = fmIndex >= 0 ? (instMute[fmIndex] ? 0 : levels[fmIndex]) : 1
        for k in 0..<n { synthBus[k] = out[k] * fmGain; drumBus[k] = 0 }
        for (i, inst) in instruments.enumerated() where i != fmIndex {
            for k in 0..<n { scratch[k] = 0 }
            inst.render(frames: n, out: scratch)
            let g = (instMute[i] ? 0 : levels[i]) * mv
            if drumMask[i] {
                for k in 0..<n { drumBus[k] += scratch[k] * g }
            } else {
                for k in 0..<n { synthBus[k] += scratch[k] * g }
            }
        }
        master.process(synth: synthBus, drums: drumBus, out: out, frames: n)
        for k in 0..<n {
            scope[scopeWrite] = out[k]
            scopeWrite = (scopeWrite + 1) & (PackageEngine.scopeSize - 1)
        }
    }
}
