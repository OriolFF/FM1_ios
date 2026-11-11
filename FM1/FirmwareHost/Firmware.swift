import Foundation

/// `manifest.json` of a firmware package (see Firmwares/README.md for the format).
struct FirmwareManifest: Codable, Equatable {
    var format: Int
    var id: String
    var name: String
    var version: String
    var bootTitle: String?
    var summary: String
    var credits: String?
    var license: String?
    var source: String?
    /// "script" (data + JavaScript run by the host) or "native" (built into the app: stock, groove).
    var runtime: String
    var native: String?
    var scripts: [String]?
    var engine: Engine?

    struct Engine: Codable, Equatable {
        var instruments: [Instrument]
        var sequencer: Sequencer?
    }
    struct Instrument: Codable, Equatable {
        var id: String
        var type: String          // fm | va | pd | drums | slot
        var voices: Int?
        /// `slot` only: the engines it can switch between (va, fm, pd) and the one it starts with.
        var engines: [String]? = nil
        var engine: String? = nil
        /// `midi` only: the output channel it starts on, 1–16.
        var channel: Int? = nil
    }
    struct Sequencer: Codable, Equatable {
        var patterns: Int?
        var tracks: [Track]
    }
    struct Track: Codable, Equatable {
        var id: String
        var instrument: String
        var lanes: Int?
    }

    static let instrumentTypes: Set<String> = ["fm", "va", "pd", "drums", "slot", "midi"]

    /// Checks everything the host relies on. Throws a readable message.
    func validate(allowNative: Bool) throws {
        func fail(_ m: String) -> FirmwareError { .invalid(m) }
        guard format == 1 else { throw fail("Unsupported format \(format) (this app reads format 1)") }
        guard id.range(of: "^[a-z0-9][a-z0-9-]{0,31}$", options: .regularExpression) != nil else { throw fail("Bad id '\(id)': use a-z, 0-9 and -") }
        guard !name.isEmpty, name.count <= 40, !version.isEmpty, version.count <= 16 else { throw fail("Name or version missing or too long") }
        switch runtime {
        case "native":
            guard allowNative else { throw fail("Native firmwares are built into the app and cannot be downloaded") }
        case "script":
            let files = scripts ?? []
            guard !files.isEmpty, files.count <= 8 else { throw fail("A script firmware lists 1–8 scripts") }
            for f in files where !FirmwareManifest.safeFileName(f) { throw fail("Bad script file name '\(f)'") }
            guard let e = engine else { throw fail("A script firmware needs an engine section") }
            guard (1...8).contains(e.instruments.count) else { throw fail("1–8 instruments") }
            var ids = Set<String>()
            var fmCount = 0
            for i in e.instruments {
                guard FirmwareManifest.instrumentTypes.contains(i.type) else { throw fail("Unknown instrument type '\(i.type)'") }
                guard ids.insert(i.id).inserted else { throw fail("Duplicate instrument id '\(i.id)'") }
                if i.type == "fm" { fmCount += 1 }
                if let v = i.voices, !(1...12).contains(v) { throw fail("voices must be 1–12") }
                if let c = i.channel, !(1...16).contains(c) { throw fail("channel must be 1–16") }
                if i.type == "slot" {
                    let es = i.engines ?? []
                    guard !es.isEmpty, es.count <= 3, es.allSatisfy({ SlotInstrument.engineTypes.contains($0) }) else {
                        throw fail("Slot '\(i.id)' needs engines from va, fm, pd")
                    }
                    if let e = i.engine, !es.contains(e) { throw fail("Slot '\(i.id)' starts on '\(e)', which is not in its engines") }
                }
            }
            guard fmCount <= 1 else { throw fail("Only one fm instrument (the host has one FM engine)") }
            if let s = e.sequencer {
                guard s.tracks.count <= 8 else { throw fail("At most 8 sequencer tracks") }
                if let p = s.patterns, !(1...16).contains(p) { throw fail("patterns must be 1–16") }
                for t in s.tracks where !ids.contains(t.instrument) { throw fail("Track '\(t.id)' uses unknown instrument '\(t.instrument)'") }
            }
        default:
            throw fail("Unknown runtime '\(runtime)'")
        }
    }

    static func safeFileName(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$", options: .regularExpression) != nil && !s.contains("..")
    }
}

enum FirmwareError: LocalizedError {
    case invalid(String)
    case download(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let m): return "Invalid firmware package: \(m)"
        case .download(let m): return "Download failed: \(m)"
        }
    }
}

/// A firmware the panel can "flash": a package from the app bundle (Firmwares/…)
/// or one installed at runtime (Application Support/FirmwarePackages/…).
struct Firmware: Identifiable, Hashable {
    enum Origin: Hashable { case bundled, installed }
    let manifest: FirmwareManifest
    /// Folder holding manifest.json and the scripts.
    let folder: URL?
    let origin: Origin

    var id: String { manifest.id }
    var name: String { manifest.name }
    var version: String { manifest.version }
    var bootTitle: String { manifest.bootTitle ?? manifest.name.uppercased() }
    var summary: String { manifest.summary }
    var credits: String { manifest.credits ?? "" }
    var isStock: Bool { manifest.runtime == "native" && manifest.native == "stockV15" }
    var isGroove: Bool { manifest.runtime == "native" && manifest.native == "groove" }
    var isScript: Bool { manifest.runtime == "script" }

    static func == (a: Firmware, b: Firmware) -> Bool { a.id == b.id && a.version == b.version && a.origin == b.origin }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// Fallbacks so the panel always has the two native firmwares, even without the bundle folder.
    static let stockV15 = Firmware(manifest: FirmwareManifest(
        format: 1, id: "stock-v15", name: "FM-1 Stock", version: "V15", bootTitle: "FM-1",
        summary: "The original M-VAVE firmware (V15).", credits: nil, license: nil, source: nil,
        runtime: "native", native: "stockV15", scripts: nil, engine: nil), folder: nil, origin: .bundled)
    static let groove = Firmware(manifest: FirmwareManifest(
        format: 1, id: "groove", name: "FM Pocket Groove", version: "G1.0", bootTitle: "GROOVE",
        summary: "Groovebox port.", credits: nil, license: nil, source: nil,
        runtime: "native", native: "groove", scripts: nil, engine: nil), folder: nil, origin: .bundled)

    /// Concatenated scripts of a script firmware.
    func loadScripts() throws -> [(String, String)] {
        guard let folder, let files = manifest.scripts else { return [] }
        return try files.map { f in
            (f, try String(contentsOf: folder.appendingPathComponent(f), encoding: .utf8))
        }
    }
}
