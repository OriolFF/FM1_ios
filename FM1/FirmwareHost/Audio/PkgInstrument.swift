import Foundation

/// A sound source a firmware package declares in its manifest (`engine.instruments`).
/// All methods run on the audio thread except `setParam`/`param`, which the main
/// thread calls (single Float stores, read once per block by the audio thread).
protocol PkgInstrument: AnyObject {
    var kind: String { get }
    var paramTable: [PkgParam] { get }
    func setParam(_ index: Int, _ value: Float)
    func param(_ index: Int) -> Float

    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool)
    func noteOff(_ note: Int)
    func hit(_ lane: Int, vel: Int)
    func allOff()
    /// Parameter lock from the sequencer for the current step (value 0...255, or a discrete index).
    func applyLock(_ index: Int, _ value: UInt8)
    func clearLocks()
    /// Adds `frames` mono samples to `out`.
    func render(frames: Int, out: UnsafeMutablePointer<Float>)
    /// 0...1 activity for screens/LEDs (approximate).
    var meter: Float { get }
}

/// One package-visible parameter. Continuous parameters are normalised 0...1 in the
/// script API; `count > 0` marks a discrete parameter whose value is an index 0..<count.
struct PkgParam {
    let name: String
    let count: Int          // 0 = continuous
    let defaultValue: Float
    init(_ name: String, _ def: Float, count: Int = 0) { self.name = name; self.defaultValue = def; self.count = count }
}

/// Fixed-size Float parameter store with per-step lock overrides.
final class PkgParamStore {
    let count: Int
    let base: UnsafeMutablePointer<Float>
    let lock: UnsafeMutablePointer<Float>   // .nan = none
    let table: [PkgParam]
    init(_ table: [PkgParam]) {
        self.table = table
        count = table.count
        base = .allocate(capacity: count)
        lock = .allocate(capacity: count)
        for i in 0..<count { base[i] = table[i].defaultValue }
        lock.initialize(repeating: .nan, count: count)
    }
    deinit { base.deallocate(); lock.deallocate() }
    @inline(__always) func v(_ i: Int) -> Float { let l = lock[i]; return l.isNaN ? base[i] : l }
    @inline(__always) func idx(_ i: Int) -> Int { Int(v(i).rounded()) }
    func applyLock(_ i: Int, _ raw: UInt8) {
        guard i >= 0 && i < count else { return }
        lock[i] = table[i].count > 0 ? Float(min(Int(raw), table[i].count - 1)) : Float(raw) / 255
    }
    func clearLocks() { for i in 0..<count { lock[i] = .nan } }
    func set(_ i: Int, _ value: Float) {
        guard i >= 0 && i < count else { return }
        let p = table[i]
        base[i] = p.count > 0 ? Float(min(max(Int(value.rounded()), 0), p.count - 1)) : min(max(value, 0), 1)
    }
}

// MARK: - Shared DSP helpers

@inline(__always) func pkgBlep(_ t: Float, _ dt: Float) -> Float {
    if t < dt { let x = t / dt; return x + x - x * x - 1 }
    if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
    return 0
}

@inline(__always) func pkgTanh(_ x: Float) -> Float {
    if x > 3 { return 1 }
    if x < -3 { return -1 }
    let x2 = x * x
    return x * (27 + x2) / (27 + 9 * x2)
}

/// cos(2π·p) via the parabolic sine below (< 0.1 % error).
@inline(__always) func pkgCos2pi(_ p: Float) -> Float { pkgSin2pi(p + 0.25) }

/// sin(2π·p), parabolic approximation with one refinement step.
@inline(__always) func pkgSin2pi(_ p: Float) -> Float {
    var x = p - floorf(p)                // 0..<1
    x = x < 0.5 ? x * 2 : (x - 0.5) * 2  // half-cycle position
    let s: Float = (p - floorf(p)) < 0.5 ? 1 : -1
    let y = 4 * x * (1 - x)              // parabola 0..1..0
    return s * y * (0.775 + 0.225 * y)   // refined
}

/// Times in seconds from a 0...1 knob: 1 ms ... 10 s, exponential.
@inline(__always) func pkgTime(_ v: Float) -> Float { 0.001 * powf(10000, v) }

/// Linear-attack, exponential decay/release envelope (per voice).
struct PkgEnv {
    var level: Float = 0
    var stage = 4              // 0 attack, 1 decay, 2 sustain, 3 release, 4 idle
    mutating func gate(_ on: Bool, legato: Bool = false) {
        if on { if !legato || stage >= 3 { stage = 0 } } else if stage < 3 { stage = 3 }
    }
    /// Advances by `n` samples at once (block-rate), returns the level at the block end.
    @inline(__always) mutating func tick(n: Int, a: Float, d: Float, s: Float, r: Float, sr: Float) -> Float {
        let dt = Float(n) / sr
        switch stage {
        case 0:
            level += dt / max(a, 0.0005)
            if level >= 1 { level = 1; stage = 1 }
        case 1:
            level = s + (level - s) * expf(-dt / max(d * 0.3, 0.0005))
            if abs(level - s) < 0.0005 { level = s; stage = 2 }
        case 2:
            level = s
        case 3:
            level *= expf(-dt / max(r * 0.3, 0.0005))
            if level < 0.0002 { level = 0; stage = 4 }
        default:
            level = 0
        }
        return level
    }
    var active: Bool { stage < 4 }
}

/// Note stack for mono / legato voice modes (fixed capacity, no allocation).
struct PkgNoteStack {
    var notes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var count = 0
    mutating func push(_ n: Int) {
        remove(n)
        guard count < 16 else { return }
        withUnsafeMutableBytes(of: &notes) { $0.bindMemory(to: Int.self)[count] = n }
        count += 1
    }
    mutating func remove(_ n: Int) {
        withUnsafeMutableBytes(of: &notes) { raw in
            let b = raw.bindMemory(to: Int.self)
            var j = 0
            for i in 0..<count where b[i] != n { b[j] = b[i]; j += 1 }
            count = j
        }
    }
    var top: Int? {
        guard count > 0 else { return nil }
        return withUnsafeBytes(of: notes) { $0.bindMemory(to: Int.self)[count - 1] }
    }
}
