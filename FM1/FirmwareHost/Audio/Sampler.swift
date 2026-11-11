import Foundation

/// Sample playback for package firmwares: a library of sample sets loaded from WAV files when the
/// package starts (main thread), and the `sampler` instrument (also the `smp` engine of a slot).
///
/// A set is either multisampled (`zones`: files with their root notes; a key plays the nearest
/// zone, re-pitched) or sliced (`file` + `slices`: one sample cut into equal slices; key C3 (48)
/// plays slice 1, the next key slice 2, and so on, at the original pitch).

/// One decoded sample: mono Float, read-only once loaded.
final class PkgSample {
    let data: UnsafeMutablePointer<Float>
    let count: Int
    let rate: Float
    init(data: UnsafeMutablePointer<Float>, count: Int, rate: Float) { self.data = data; self.count = count; self.rate = rate }
    deinit { data.deallocate() }

    /// Decodes PCM WAV (8/16/24/32-bit integer or 32-bit float, any channel count, mixed to mono).
    static func decodeWAV(_ d: Data, maxFrames: Int) throws -> PkgSample {
        func fail(_ m: String) -> FirmwareError { .invalid("WAV: \(m)") }
        return try d.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> PkgSample in
            guard raw.count >= 12, raw.loadUnaligned(fromByteOffset: 0, as: UInt32.self) == 0x4646_4952,   // RIFF
                  raw.loadUnaligned(fromByteOffset: 8, as: UInt32.self) == 0x4556_4157 else { throw fail("not a WAV file") }  // WAVE
            var i = 12
            var tag = 0, ch = 0, rate = 0, bits = 0
            var dataAt = -1, dataLen = 0
            while i + 8 <= raw.count {
                let id = raw.loadUnaligned(fromByteOffset: i, as: UInt32.self)
                let n = Int(raw.loadUnaligned(fromByteOffset: i + 4, as: UInt32.self))
                if id == 0x2074_6D66, i + 24 <= raw.count {               // "fmt "
                    tag = Int(raw.loadUnaligned(fromByteOffset: i + 8, as: UInt16.self))
                    ch = Int(raw.loadUnaligned(fromByteOffset: i + 10, as: UInt16.self))
                    rate = Int(raw.loadUnaligned(fromByteOffset: i + 12, as: UInt32.self))
                    bits = Int(raw.loadUnaligned(fromByteOffset: i + 22, as: UInt16.self))
                    if tag == 0xFFFE, i + 34 <= raw.count {               // extensible: real format in the sub-format GUID
                        tag = Int(raw.loadUnaligned(fromByteOffset: i + 32, as: UInt16.self))
                    }
                } else if id == 0x6174_6164 {                             // "data"
                    dataAt = i + 8; dataLen = min(n, raw.count - i - 8)
                }
                i += 8 + n + (n & 1)
            }
            guard dataAt >= 0, ch >= 1, ch <= 8, rate >= 4000, rate <= 192_000 else { throw fail("missing or unsupported format") }
            guard (tag == 1 && [8, 16, 24, 32].contains(bits)) || (tag == 3 && bits == 32) else { throw fail("only PCM 8/16/24/32-bit or float 32-bit") }
            let w = bits / 8
            let frames = min(dataLen / (w * ch), maxFrames)
            guard frames > 0 else { throw fail("no audio") }
            let out = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            for f in 0..<frames {
                var sum: Float = 0
                for c in 0..<ch {
                    let o = dataAt + (f * ch + c) * w
                    switch (tag, w) {
                    case (3, _): sum += raw.loadUnaligned(fromByteOffset: o, as: Float.self)
                    case (_, 1): sum += (Float(raw[o]) - 128) / 128
                    case (_, 2): sum += Float(raw.loadUnaligned(fromByteOffset: o, as: Int16.self)) / 32768
                    case (_, 3):
                        let v = Int32(raw[o]) | Int32(raw[o + 1]) << 8 | Int32(Int8(bitPattern: raw[o + 2])) << 16
                        sum += Float(v) / 8_388_608
                    default: sum += Float(raw.loadUnaligned(fromByteOffset: o, as: Int32.self)) / 2_147_483_648
                    }
                }
                let v = sum / Float(ch)
                out[f] = v.isFinite ? min(max(v, -1), 1) : 0
            }
            return PkgSample(data: out, count: frames, rate: Float(rate))
        }
    }
}

/// The sample sets a package can play, in manifest order, then the user's own samples.
final class PkgSampleLibrary {
    struct Zone { let sample: PkgSample; let root: Int }
    struct Set {
        let name: String
        let zones: [Zone]          // multisample: sorted by root
        let slices: Int            // > 0: one sample cut into this many slices
    }
    let sets: [Set]
    /// Frames across all sets (memory guard).
    static let maxTotalFrames = 8_000_000

    init(sets: [Set]) { self.sets = sets }
    static let empty = PkgSampleLibrary(sets: [])

    /// Folder of samples shipped with the app, shared by every package as `@samples/<file>`.
    static var sharedFolder: URL? { Bundle.main.url(forResource: "Firmwares", withExtension: nil)?.appendingPathComponent("_samples", isDirectory: true) }

    /// Loads the manifest's sets (paths are `@samples/x.wav` or relative to the package folder)
    /// and, if `userFolder` is given, one set per WAV in it (root C4, named after the file).
    static func load(_ defs: [FirmwareManifest.SampleSet], packageFolder: URL?, sharedFolder: URL?, userFolder: URL?) throws -> PkgSampleLibrary {
        var total = 0
        var cache: [String: PkgSample] = [:]
        func sample(_ path: String) throws -> PkgSample {
            if let s = cache[path] { return s }
            let url: URL
            if path.hasPrefix("@samples/") {
                guard let base = sharedFolder else { throw FirmwareError.invalid("No shared samples in this app") }
                url = base.appendingPathComponent(String(path.dropFirst("@samples/".count)))
            } else if path.hasPrefix("@user/") {
                guard let base = userFolder else { throw FirmwareError.invalid("No user samples") }
                url = base.appendingPathComponent(String(path.dropFirst("@user/".count)))
            } else {
                guard let base = packageFolder else { throw FirmwareError.invalid("Sample \(path) needs a package folder") }
                url = base.appendingPathComponent(path)
            }
            guard let d = try? Data(contentsOf: url) else { throw FirmwareError.invalid("Missing sample \(path)") }
            let s = try PkgSample.decodeWAV(d, maxFrames: max(0, maxTotalFrames - total))
            total += s.count
            cache[path] = s
            return s
        }
        var sets: [Set] = []
        for def in defs {
            if let f = def.file {
                sets.append(Set(name: def.name, zones: [Zone(sample: try sample(f), root: 48)], slices: min(max(def.slices ?? 16, 1), 64)))
            } else {
                let zones = try (def.zones ?? []).map { Zone(sample: try sample($0.file), root: $0.root) }.sorted { $0.root < $1.root }
                if !zones.isEmpty { sets.append(Set(name: def.name, zones: zones, slices: 0)) }
            }
        }
        if let u = userFolder, let files = try? FileManager.default.contentsOfDirectory(atPath: u.path) {
            for f in files.filter({ $0.lowercased().hasSuffix(".wav") }).sorted().prefix(32) {
                guard let s = try? sample("@user/" + f) else { continue }
                let name = String((f as NSString).deletingPathExtension.uppercased().prefix(12))
                sets.append(Set(name: name, zones: [Zone(sample: s, root: 60)], slices: 0))
            }
        }
        return PkgSampleLibrary(sets: sets)
    }
}

/// `"type": "sampler"` (and a slot's `smp` engine): plays the package's sample sets.
final class SamplerInstrument: PkgInstrument {
    let kind = "smp"
    let library: PkgSampleLibrary
    let table: [PkgParam]
    var paramTable: [PkgParam] { table }
    private let p: PkgParamStore
    private let sr: Float
    private let nv: Int
    private struct Voice {
        var note = -1, zone = 0, set = 0
        var pos: Double = 0, inc: Double = 0, end: Double = 0, start: Double = 0
        var reverse = false
        var vel: Float = 0
        var env = PkgEnv()
        var lp: Float = 0
        var age = 0
    }
    private var voices: [Voice]
    private var clock = 0
    var meter: Float { var m: Float = 0; for v in voices where v.env.active { m = max(m, v.env.level * v.vel) }; return m }

    // parameter indices
    private static let names = ["set", "tune", "fine", "start", "a", "d", "s", "r", "cutoff", "reverse", "level", "vel"]
    init(sampleRate: Float, voices: Int, library: PkgSampleLibrary) {
        self.library = library
        sr = sampleRate
        nv = min(max(voices, 1), 16)
        table = [
            PkgParam("set", 0, count: max(1, library.sets.count)),
            PkgParam("tune", 24, count: 49),            // -24 … +24 semitones
            PkgParam("fine", 0.5), PkgParam("start", 0),
            PkgParam("a", 0.0), PkgParam("d", 0.5), PkgParam("s", 1), PkgParam("r", 0.35),
            PkgParam("cutoff", 1), PkgParam("reverse", 0, count: 2),
            PkgParam("level", 0.8), PkgParam("vel", 0.5),
        ]
        p = PkgParamStore(table)
        self.voices = [Voice](repeating: Voice(), count: nv)
    }
    /// Names of the sets, for scripts (`inst.sets()`).
    var setNames: [String] { library.sets.map(\.name) }

    func setParam(_ i: Int, _ v: Float) { p.set(i, v) }
    func param(_ i: Int) -> Float { i >= 0 && i < p.count ? p.base[i] : 0 }

    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) {
        let sets = library.sets
        guard !sets.isEmpty else { return }
        let si = min(max(p.idx(0), 0), sets.count - 1)
        let set = sets[si]
        // a free voice, else the oldest; a retriggered note reuses its voice
        var k = -1
        for i in 0..<nv where voices[i].note == note && voices[i].env.active { k = i; break }
        if k < 0 { for i in 0..<nv where !voices[i].env.active { k = i; break } }
        if k < 0 { var oldest = Int.max; for i in 0..<nv where voices[i].age < oldest { oldest = voices[i].age; k = i } }
        var v = Voice()
        v.note = note; v.set = si
        let tune = Double(p.idx(1) - 24) + Double(p.v(2) - 0.5)
        let rev = p.idx(9) == 1
        if set.slices > 0 {
            let s = set.zones[0].sample
            let n = set.slices, slice = ((note - 48) % n + n) % n
            let len = Double(s.count) / Double(n)
            v.start = Double(slice) * len; v.end = v.start + len
            v.zone = 0
            v.inc = Double(s.rate / sr) * pow(2, tune / 12)
        } else {
            // nearest zone by root
            var zi = 0, best = Int.max
            for (i, z) in set.zones.enumerated() { let dist = abs(z.root - note); if dist < best { best = dist; zi = i } }
            let z = set.zones[zi]
            v.zone = zi
            v.start = 0; v.end = Double(z.sample.count)
            v.inc = Double(z.sample.rate / sr) * pow(2, (Double(note - z.root) + tune) / 12)
        }
        let offset = Double(p.v(3)) * (v.end - v.start) * 0.9
        v.reverse = rev
        v.pos = rev ? v.end - 1 - offset : v.start + offset
        let sens = p.v(11)
        v.vel = (1 - sens) + sens * Float(min(max(vel + (accent ? 20 : 0), 1), 127)) / 127
        v.env.gate(true)
        clock += 1; v.age = clock
        voices[k] = v
    }
    func noteOff(_ note: Int) { for i in 0..<nv where voices[i].note == note && voices[i].env.stage < 3 { voices[i].env.gate(false) } }
    func hit(_ lane: Int, vel: Int) { noteOn(48 + lane, vel: vel, slide: false, accent: false) }
    func allOff() { for i in 0..<nv { voices[i].env.gate(false) } }
    func applyLock(_ i: Int, _ v: UInt8) { p.applyLock(i, v) }
    func clearLocks() { p.clearLocks() }

    func render(frames n: Int, out: UnsafeMutablePointer<Float>) {
        let sets = library.sets
        guard !sets.isEmpty else { return }
        let a = pkgTime(p.v(4)), d = pkgTime(p.v(5)), s = p.v(6), r = pkgTime(p.v(7))
        let level = p.v(10)
        // one-pole low-pass, 60 Hz … open
        let fc = 60 * powf(300, p.v(8))
        let coef = p.v(8) >= 0.999 ? 1 : min(1, 1 - expf(-2 * Float.pi * fc / sr))
        for i in 0..<nv where voices[i].env.active {
            var v = voices[i]
            guard v.set < sets.count else { voices[i].env = PkgEnv(); continue }
            let z = sets[v.set].zones[min(v.zone, sets[v.set].zones.count - 1)]
            let data = z.sample.data
            let e0 = v.env.level
            let e1 = v.env.tick(n: n, a: a, d: d, s: s, r: r, sr: sr)
            let g = level * v.vel
            for k in 0..<n {
                let pos = v.pos
                if v.reverse ? pos < v.start : pos >= v.end - 1 { v.env = PkgEnv(); break }
                let j = Int(pos), f = Float(pos - Double(j))
                let x = data[j] + (data[min(j + 1, z.sample.count - 1)] - data[j]) * f
                v.lp += (x - v.lp) * coef
                let env = e0 + (e1 - e0) * Float(k) / Float(n)
                out[k] += v.lp * env * g
                v.pos += v.reverse ? -v.inc : v.inc
            }
            voices[i] = v
        }
    }
}
