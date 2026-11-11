import Foundation

/// `"type": "drums"`: the host's 11-lane analog-style drum synth (FM1/Engine/DrumKit.swift),
/// one private instance per package. Parameters are `<lane>.<level|tune|decay|tone>`
/// (index lane*4+p, 0...1) plus `accent`; lanes follow DrumKit.names.
final class DrumsInstrument: PkgInstrument {
    let kind = "drums"
    let kit: DrumKit
    static let table: [PkgParam] = {
        var t: [PkgParam] = []
        for l in 0..<DrumKit.laneCount {
            for (i, p) in ["level", "tune", "decay", "tone"].enumerated() {
                t.append(PkgParam("\(DrumKit.shortNames[l]).\(p)", i == 0 ? 100 / 127 : 64 / 127))
            }
        }
        t.append(PkgParam("accent", 0.7))
        return t
    }()
    var paramTable: [PkgParam] { DrumsInstrument.table }
    private let base: UnsafeMutablePointer<UInt8>
    private var locked = false
    var meter: Float { var m: Float = 0; for l in 0..<DrumKit.laneCount { m = max(m, kit.laneMeter[l]) }; return m }

    init(sampleRate: Float) {
        kit = DrumKit(sampleRate: sampleRate)
        base = .allocate(capacity: DrumKit.laneCount * 4)
        base.update(from: kit.params, count: DrumKit.laneCount * 4)
    }
    deinit { base.deallocate() }

    func setParam(_ i: Int, _ v: Float) {
        let c = min(max(v, 0), 1)
        if i == DrumKit.laneCount * 4 { kit.accent = c; return }
        guard i >= 0 && i < DrumKit.laneCount * 4 else { return }
        let b = UInt8(clamping: Int((c * 127).rounded()))
        base[i] = b
        kit.params[i] = b
    }
    func param(_ i: Int) -> Float {
        if i == DrumKit.laneCount * 4 { return kit.accent }
        guard i >= 0 && i < DrumKit.laneCount * 4 else { return 0 }
        return Float(base[i]) / 127
    }
    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) { hit(note, vel: vel) }
    func noteOff(_ note: Int) {}
    func hit(_ lane: Int, vel: Int) { kit.trigger(lane, velocity: vel) }
    func allOff() {}
    func applyLock(_ i: Int, _ v: UInt8) {
        guard i >= 0 && i < DrumKit.laneCount * 4 else { return }
        kit.params[i] = v >> 1
        locked = true
    }
    func clearLocks() {
        guard locked else { return }
        kit.params.update(from: base, count: DrumKit.laneCount * 4)
        locked = false
    }
    func render(frames: Int, out: UnsafeMutablePointer<Float>) { kit.render(frames: frames, out: out) }
}

/// `"type": "fm"`: routes notes to the host's 6-operator engine (FM1/Engine/FMEngine.swift).
/// Only one per package (the engine is shared). Parameters are DX7 VCED indices (0...155) with
/// raw values; `preset` loads one of the 128 voices in the user's bank. The engine renders
/// its own voices; this wrapper only queues events that PackageEngine hands to the FM sink.
final class FMInstrument: PkgInstrument {
    let kind = "fm"
    var paramTable: [PkgParam] { [] }
    unowned let engine: FMEngine
    private let ring: UnsafeMutablePointer<FMEngine.Event>
    private let cap = 128
    private var count = 0
    private var lockIdx = [Int](repeating: -1, count: 4)
    private var lockOld = [UInt8](repeating: 0, count: 4)
    private var lockN = 0
    var meter: Float { Float(min(engine.activeVoiceCount, 4)) / 4 }

    init(engine: FMEngine) {
        self.engine = engine
        ring = .allocate(capacity: cap)
        ring.initialize(repeating: .allOff, count: cap)
        lockIdx.reserveCapacity(4); lockOld.reserveCapacity(4)
    }
    deinit { ring.deallocate() }

    func setParam(_ i: Int, _ v: Float) {
        guard i >= 0 && i < FMPatch.size else { return }
        engine.patch[i] = UInt8(clamping: Int(v.rounded()))
    }
    func param(_ i: Int) -> Float { i >= 0 && i < FMPatch.size ? Float(engine.patch[i]) : 0 }
    @inline(__always) private func push(_ e: FMEngine.Event) { if count < cap { ring[count] = e; count += 1 } }
    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) {
        push(.noteOn(UInt8(clamping: note), UInt8(clamping: max(1, accent ? min(127, vel + 20) : vel))))
    }
    func noteOff(_ note: Int) { push(.noteOff(UInt8(clamping: note))) }
    func hit(_ lane: Int, vel: Int) {}
    func allOff() { push(.allOff) }
    func applyLock(_ i: Int, _ v: UInt8) {
        guard i >= 0 && i < FMPatch.size, lockN < 4 else { return }
        lockIdx[lockN] = i; lockOld[lockN] = engine.patch[i]; lockN += 1
        engine.patch[i] = v
    }
    func clearLocks() {
        while lockN > 0 { lockN -= 1; engine.patch[lockIdx[lockN]] = lockOld[lockN] }
    }
    /// Audio thread, inside FMBlockHook.advance.
    func flush(_ sink: (FMEngine.Event) -> Void) {
        for k in 0..<count { sink(ring[k]) }
        count = 0
    }
    func render(frames: Int, out: UnsafeMutablePointer<Float>) {}
}
