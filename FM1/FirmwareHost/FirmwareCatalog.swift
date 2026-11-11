import Foundation
import JavaScriptCore

/// Every firmware the panel can flash: the packages bundled in the app (the `Firmwares`
/// folder) plus the ones installed at runtime from a URL or the Files app. An installed
/// package with the id of a bundled one replaces it (an update), except the native ones.
@MainActor
final class FirmwareCatalog: ObservableObject {
    static let shared = FirmwareCatalog()
    @Published private(set) var all: [Firmware] = []

    static var installedRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FirmwarePackages", isDirectory: true)
    }
    static func dataFolder(for id: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FirmwareData", isDirectory: true).appendingPathComponent(id, isDirectory: true)
    }

    private init() {
        #if DEBUG
        // UI tests start from the bundled catalog: drop packages earlier runs downloaded
        if ProcessInfo.processInfo.environment["FM1_TEST_RESET_PACKAGES"] == "1" {
            try? FileManager.default.removeItem(at: Self.installedRoot)
        }
        // UI tests: one generated user sample ("TEST SINE") for the firmware with this id
        if let id = ProcessInfo.processInfo.environment["FM1_TEST_USER_SAMPLE"] {
            Self.removeUserSamples(for: id)
            var pcm = Data()
            for i in 0..<22050 { var v = Int16(12000 * sin(2 * Double.pi * 261.6256 * Double(i) / 22050)); pcm.append(Data(bytes: &v, count: 2)) }
            var wav = Data("RIFF".utf8)
            func put<T>(_ x: T) { var y = x; wav.append(Data(bytes: &y, count: MemoryLayout<T>.size)) }
            put(UInt32(36 + pcm.count)); wav.append(Data("WAVEfmt ".utf8))
            put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(22050)); put(UInt32(44100)); put(UInt16(2)); put(UInt16(16))
            wav.append(Data("data".utf8)); put(UInt32(pcm.count)); wav.append(pcm)
            try? Self.addUserSample(wav, name: "TEST SINE.wav", to: id)
        }
        #endif
        reload()
    }

    func reload() {
        var list: [Firmware] = []
        if let root = Bundle.main.url(forResource: "Firmwares", withExtension: nil) {
            list += Self.scan(root, origin: .bundled, allowNative: true)
        }
        if !list.contains(where: { $0.isStock }) { list.insert(.stockV15, at: 0) }
        if !list.contains(where: { $0.isGroove }) { list.append(.groove) }
        for fw in Self.scan(Self.installedRoot, origin: .installed, allowNative: false) {
            if let i = list.firstIndex(where: { $0.id == fw.id }) { list[i] = fw } else { list.append(fw) }
        }
        // stock first, then native, then packages by name
        list.sort { a, b in
            if a.isStock != b.isStock { return a.isStock }
            if (a.manifest.runtime == "native") != (b.manifest.runtime == "native") { return a.manifest.runtime == "native" }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        all = list
    }

    private static func scan(_ root: URL, origin: Firmware.Origin, allowNative: Bool) -> [Firmware] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return dirs.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { dir in
            let m = dir.appendingPathComponent("manifest.json")
            guard let d = try? Data(contentsOf: m),
                  let man = try? JSONDecoder().decode(FirmwareManifest.self, from: d),
                  (try? man.validate(allowNative: allowNative)) != nil else { return nil }
            return Firmware(manifest: man, folder: dir, origin: origin)
        }
    }

    // MARK: user samples (Application Support/FirmwareData/<id>/samples)

    static func userSamples(for id: String) -> [String] {
        let dir = PackageHost.userSampleFolder(id)
        return ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.lowercased().hasSuffix(".wav") }.sorted()
    }

    /// Adds one WAV file to a package's user samples (checked as WAV, name made safe). Returns the stored name.
    @discardableResult
    static func addUserSample(_ data: Data, name: String, to id: String) throws -> String {
        guard data.count <= 32_000_000 else { throw FirmwareError.invalid("\(name) is larger than 32 MB") }
        _ = try PkgSample.decodeWAV(data, maxFrames: 1)
        guard userSamples(for: id).count < 32 else { throw FirmwareError.invalid("At most 32 user samples per firmware") }
        var base = (name as NSString).deletingPathExtension.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
        base = String(base.trimmingCharacters(in: CharacterSet(charactersIn: "_-")).prefix(40))
        if base.isEmpty { base = "sample" }
        let dir = PackageHost.userSampleFolder(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var file = base + ".wav", n = 2
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(file).path) { file = "\(base)_\(n).wav"; n += 1 }
        try data.write(to: dir.appendingPathComponent(file), options: .atomic)
        return file
    }

    /// Imports WAV files picked in Files. Returns how many were added and the first error, if any.
    static func importUserSamples(_ urls: [URL], to id: String) -> (added: Int, error: String?) {
        var added = 0, err: String? = nil
        for url in urls {
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do { try addUserSample(try Data(contentsOf: url), name: url.lastPathComponent, to: id); added += 1 }
            catch { if err == nil { err = "\(url.lastPathComponent): \(error.localizedDescription)" } }
        }
        return (added, err)
    }

    static func removeUserSamples(for id: String) {
        try? FileManager.default.removeItem(at: PackageHost.userSampleFolder(id))
    }

    func firmware(id: String) -> Firmware? {
        let migrated = id == "stockV15" ? "stock-v15" : id
        return all.first { $0.id == migrated }
    }
    var stock: Firmware { all.first { $0.isStock } ?? .stockV15 }

    // MARK: Install

    /// Downloads and installs a package. Accepts a single-file `.fm1fw` bundle (JSON:
    /// `{"fm1fw": 1, "files": {"manifest.json": "...", "main.js": "..."}}`) from any URL
    /// (https, file, data), or a `manifest.json` URL whose scripts sit next to it.
    @MainActor func install(from url: URL) async throws -> Firmware {
        let data = try await Self.fetch(url)
        return try await install(data: data, baseURL: url)
    }

    @MainActor func install(data: Data, baseURL: URL?) async throws -> Firmware {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirmwareError.invalid("not a JSON package (.fm1fw) or manifest.json")
        }
        var files: [String: Data] = [:]
        if obj["fm1fw"] != nil {
            // text files are strings; binary files (package samples) are {"base64": "…"}
            guard let f = obj["files"] as? [String: Any] else { throw FirmwareError.invalid("bundle has no files") }
            for (k, v) in f {
                if let s = v as? String { files[k] = Data(s.utf8) }
                else if let o = v as? [String: Any], let b = o["base64"] as? String, let d = Data(base64Encoded: b) { files[k] = d }
                else { throw FirmwareError.invalid("bad entry \(k)") }
            }
        } else if obj["runtime"] != nil {
            files["manifest.json"] = data
            let man = try Self.decode(data)
            guard let base = baseURL, base.scheme == "https" || base.scheme == "http" || base.isFileURL else {
                throw FirmwareError.invalid("a bare manifest needs its scripts next to it; install the .fm1fw bundle instead")
            }
            for s in man.scripts ?? [] where FirmwareManifest.safeFileName(s) {
                files[s] = try await Self.fetch(base.deletingLastPathComponent().appendingPathComponent(s))
            }
        } else {
            throw FirmwareError.invalid("unrecognised JSON")
        }
        guard let md = files["manifest.json"] else { throw FirmwareError.invalid("no manifest.json") }
        let man = try Self.decode(md)
        try man.validate(allowNative: false)
        if all.contains(where: { $0.id == man.id && $0.manifest.runtime == "native" }) {
            throw FirmwareError.invalid("'\(man.id)' is a built-in firmware id")
        }
        // every listed script must be there and parse
        for s in man.scripts ?? [] {
            guard let d = files[s], let src = String(data: d, encoding: .utf8) else { throw FirmwareError.invalid("missing script \(s)") }
            guard d.count < 2_000_000 else { throw FirmwareError.invalid("\(s) is too large") }
            if let err = Self.syntaxError(src, name: s) { throw FirmwareError.invalid(err) }
        }
        // write atomically: temp folder, then swap
        let fm = FileManager.default
        try fm.createDirectory(at: Self.installedRoot, withIntermediateDirectories: true)
        let tmp = Self.installedRoot.appendingPathComponent(".tmp-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        for (name, d) in files where name == "manifest.json" || (man.scripts ?? []).contains(name) || (FirmwareManifest.safeFileName(name) && name.hasSuffix(".json")) {
            try d.write(to: tmp.appendingPathComponent(name))
        }
        // the package's own samples (`samples/<file>.wav` in its manifest), checked as WAV
        let own = Set((man.engine?.samples ?? []).flatMap { s in ([s.file].compactMap { $0 }) + (s.zones ?? []).map(\.file) }.filter { $0.hasPrefix("samples/") })
        if !own.isEmpty { try fm.createDirectory(at: tmp.appendingPathComponent("samples"), withIntermediateDirectories: true) }
        for path in own {
            guard let d = files[path] else { throw FirmwareError.invalid("missing sample \(path)") }
            _ = try PkgSample.decodeWAV(d, maxFrames: 1)
            try d.write(to: tmp.appendingPathComponent(path))
        }
        let dest = Self.installedRoot.appendingPathComponent(man.id, isDirectory: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: tmp, to: dest)
        reload()
        guard let fw = all.first(where: { $0.id == man.id }) else { throw FirmwareError.invalid("installed package did not load") }
        return fw
    }

    func uninstall(_ fw: Firmware) {
        guard fw.origin == .installed, let folder = fw.folder else { return }
        try? FileManager.default.removeItem(at: folder)
        reload()
    }

    private static func decode(_ d: Data) throws -> FirmwareManifest {
        do { return try JSONDecoder().decode(FirmwareManifest.self, from: d) }
        catch { throw FirmwareError.invalid("manifest.json: \(error.localizedDescription)") }
    }

    private static func fetch(_ url: URL) async throws -> Data {
        if url.scheme == "data" {
            // data:[<type>][;base64],<payload>
            let s = url.absoluteString
            guard let comma = s.firstIndex(of: ",") else { throw FirmwareError.download("bad data URL") }
            let head = s[s.index(s.startIndex, offsetBy: 5)..<comma], payload = String(s[s.index(after: comma)...])
            let d = head.hasSuffix(";base64") ? Data(base64Encoded: payload) : payload.removingPercentEncoding.map { Data($0.utf8) }
            guard let d else { throw FirmwareError.download("bad data URL") }
            return d
        }
        if url.isFileURL {
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do { return try Data(contentsOf: url) } catch { throw FirmwareError.download(error.localizedDescription) }
        }
        do {
            let (d, resp) = try await URLSession.shared.data(from: url)
            if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw FirmwareError.download("HTTP \(h.statusCode)") }
            guard d.count < 24_000_000 else { throw FirmwareError.download("package too large") }
            return d
        } catch let e as FirmwareError { throw e } catch { throw FirmwareError.download(error.localizedDescription) }
    }

    /// Parses (without running) a script; returns a message on a syntax error.
    static func syntaxError(_ source: String, name: String) -> String? {
        let ctx = JSGlobalContextCreate(nil)
        defer { JSGlobalContextRelease(ctx) }
        let src = JSStringCreateWithUTF8CString(source)
        let url = JSStringCreateWithUTF8CString(name)
        defer { JSStringRelease(src); JSStringRelease(url) }
        var exc: JSValueRef?
        if JSCheckScriptSyntax(ctx, src, url, 1, &exc) { return nil }
        if let exc, let s = JSValueToStringCopy(ctx, exc, nil) {
            defer { JSStringRelease(s) }
            return "\(name): " + (JSStringCopyCFString(nil, s) as String)
        }
        return "\(name): syntax error"
    }
}
