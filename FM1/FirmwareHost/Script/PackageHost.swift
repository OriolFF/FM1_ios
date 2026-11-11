import Foundation
import JavaScriptCore
import SwiftUI

/// Runs one script firmware: builds its PackageEngine from the manifest, attaches it to the
/// FM engine, evaluates the package's JavaScript in a JavaScriptCore context with the `fm`
/// API (ScriptPrelude), forwards panel events to it and collects its screen frame and LEDs.
/// Everything here runs on the main thread; the script never touches the audio thread.
@MainActor
final class PackageHost {
    let firmware: Firmware
    let engine: PackageEngine
    private unowned let model: SynthModel
    private let ctx: JSContext
    private(set) var frame = PackageFrame()
    private(set) var keyLEDs = [Color?](repeating: nil, count: 27)
    private(set) var buttonLEDs: [String: String] = [:]
    private(set) var error: String?
    private var serial = 0
    private var store: [String: String] = [:]
    private var dirty = false
    private var lastSave = Date()
    private var started = false

    static let buttonNames: [PanelButton: String] = [
        .fx: "FX", .sel: "SEL", .env: "ENV", .lfo: "LFO", .edit: "EDIT", .glo: "GLO",
        .home: "HOME", .save: "SAVE", .arp: "ARP", .seq: "SEQ", .play: "PLAY", .rec: "REC",
        .octDown: "OCT-", .octUp: "OCT+",
    ]

    init(firmware: Firmware, model: SynthModel) throws {
        guard let em = firmware.manifest.engine else { throw FirmwareError.invalid("no engine") }
        self.firmware = firmware
        self.model = model
        engine = PackageEngine(manifest: em, fm: model.engine, sampleRate: model.engine.sampleRate)
        guard let c = JSContext() else { throw FirmwareError.invalid("JavaScriptCore unavailable") }
        ctx = c
        ctx.name = firmware.name
        ctx.exceptionHandler = { [weak self] _, exc in
            let msg = exc?.toString() ?? "error"
            let line = exc?.objectForKeyedSubscript("line")?.toString() ?? ""
            MainActor.assumeIsolated { self?.reportError("\(msg) (line \(line))") }
        }
        installBridge()
        loadPersisted()
    }

    // MARK: lifecycle

    func start() {
        guard !started else { return }
        started = true
        model.engine.allNotesOff()
        model.engine.monoMode = false
        model.engine.envOn = false
        model.engine.opMuteMask = 0
        for i in 0..<6 { model.fx.order[i] = i; model.fx.enabled[i] = false }
        engine.seq.tempo = Double(model.globals.tempo)
        engine.master.tempo = engine.seq.tempo
        model.engine.blockHook = engine
        ctx.evaluateScript(ScriptPrelude.source, withSourceURL: URL(string: "host://prelude.js"))
        do {
            for (name, src) in try firmware.loadScripts() {
                ctx.evaluateScript(src, withSourceURL: URL(string: "package://\(firmware.id)/\(name)"))
            }
        } catch {
            reportError("could not read scripts: \(error.localizedDescription)")
        }
        restoreParams()
        call("boot")
        render()
    }

    /// Detaches from the audio engine. The engine object is kept alive by the caller for a
    /// moment so the audio thread never releases the last reference.
    func stop() {
        guard started else { return }
        call("shutdown")
        engine.seq.stop()
        engine.post(.allOff)
        save()
        started = false
        model.engine.blockHook = nil
        model.engine.allNotesOff()
    }

    // MARK: events from the panel

    func button(_ b: PanelButton, down: Bool) { call("button", PackageHost.buttonNames[b] ?? "?", down); render() }
    func key(_ k: Int, down: Bool, velocity: Int) { call("key", k, down, velocity); render() }
    func knob(_ k: Int, _ d: Int) { call("knob", k, d); render() }
    /// Incoming MIDI (status with channel, data 1, data 2), see `onMidi` in Firmwares/README.md.
    func midi(_ status: UInt8, _ d1: Int, _ d2: Int) { call("midi", Int(status), d1, d2); render() }
    func encoder(_ name: String, _ d: Int) { call("encoder", name, d); render() }
    func tick() {
        call("tick", Date().timeIntervalSince1970 * 1000)
        render()
        if dirty && Date().timeIntervalSince(lastSave) > 8 && !engine.seq.isPlaying { save() }
    }

    private func call(_ type: String, _ a: Any = NSNull(), _ b: Any = NSNull(), _ c: Any = NSNull()) {
        guard error == nil else { return }
        ctx.objectForKeyedSubscript("__event")?.call(withArguments: [type, a, b, c])
    }

    func render() {
        serial += 1
        if let error {
            var f = PackageFrame(serial: serial)
            f.cmds = [.clear(Color(hex: 0x1a0606)),
                      .text(CGPoint(x: 12, y: 14), "SCRIPT ERROR", 16, Color(hex: 0xff5a4a), -1, true, "sans"),
                      .text(CGPoint(x: 12, y: 40), firmware.name + " " + firmware.version, 11, .white.opacity(0.7), -1, false, "sans")]
            var y: CGFloat = 64
            var line = ""
            for w in error.split(separator: " ") {
                if line.count + w.count > 30 { f.cmds.append(.text(CGPoint(x: 12, y: y), line, 11, .white, -1, false, "mono")); y += 15; line = "" }
                line += (line.isEmpty ? "" : " ") + w
            }
            if !line.isEmpty { f.cmds.append(.text(CGPoint(x: 12, y: y), line, 11, .white, -1, false, "mono")) }
            f.cmds.append(.text(CGPoint(x: 12, y: 210), "Firmware menu: install another", 10, .white.opacity(0.6), -1, false, "sans"))
            f.label = "SCRIPT ERROR " + error
            frame = f
            keyLEDs = Array(repeating: nil, count: 27)
            return
        }
        guard let v = ctx.objectForKeyedSubscript("__frame")?.call(withArguments: []), let d = v.toDictionary() else { return }
        frame = PackageFrame.parse((d["cmds"] as? [Any]) ?? [], serial: serial)
        if let keys = d["keys"] as? [Any] {
            for k in 0..<27 { keyLEDs[k] = k < keys.count ? (keys[k] as? String).map { PackageFrame.color($0) } : nil }
        }
        buttonLEDs = (d["buttons"] as? [String: String]) ?? [:]
    }

    private func reportError(_ m: String) {
        guard error == nil else { return }
        error = m
        print("PackageHost[\(firmware.id)]: \(m)")
    }

    func buttonLight(_ b: PanelButton) -> ButtonLight {
        switch buttonLEDs[PackageHost.buttonNames[b] ?? ""] {
        case "on": return .on
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        default: return .off
        }
    }

    // MARK: bridge

    private func def(_ obj: JSValue, _ name: String, _ block: Any) {
        obj.setObject(block, forKeyedSubscript: name as NSString)
    }

    private func paramIndex(_ inst: PkgInstrument, _ v: JSValue) -> Int? {
        if v.isNumber { return Int(v.toInt32()) }
        let s = v.toString() ?? ""
        if inst.kind == "fm" { return FMParamNames.index(s) }
        return inst.paramTable.firstIndex { $0.name == s }
    }

    private func installBridge() {
        guard let h = JSValue(newObjectIn: ctx) else { return }
        let e = engine
        let seq = engine.seq
        let insts = engine.instruments
        func inst(_ i: Int32) -> PkgInstrument? { Int(i) >= 0 && Int(i) < insts.count ? insts[Int(i)] : nil }
        func trackOK(_ t: Int32) -> Bool { Int(t) >= 0 && Int(t) < seq.tracks.count }

        // instruments
        def(h, "instIndex", { (id: String) -> Int32 in Int32(e.index(of: id) ?? -1) } as @convention(block) (String) -> Int32)
        def(h, "instType", { (i: Int32) -> String in inst(i)?.kind ?? "" } as @convention(block) (Int32) -> String)
        def(h, "noteOn", { (i: Int32, n: Int32, v: Int32) in e.noteOn(Int(i), Int(n), Int(v)) } as @convention(block) (Int32, Int32, Int32) -> Void)
        def(h, "noteOff", { (i: Int32, n: Int32) in e.noteOff(Int(i), Int(n)) } as @convention(block) (Int32, Int32) -> Void)
        def(h, "hit", { (i: Int32, l: Int32, v: Int32) in e.hit(Int(i), Int(l), Int(v)) } as @convention(block) (Int32, Int32, Int32) -> Void)
        def(h, "allOff", { (_: Int32) in e.post(.allOff) } as @convention(block) (Int32) -> Void)
        def(h, "setParam", { [unowned self] (i: Int32, p: JSValue, v: Double) in
            guard let ins = inst(i), let k = self.paramIndex(ins, p) else { return }
            ins.setParam(k, Float(v)); self.dirty = true
        } as @convention(block) (Int32, JSValue, Double) -> Void)
        def(h, "getParam", { [unowned self] (i: Int32, p: JSValue) -> Double in
            guard let ins = inst(i), let k = self.paramIndex(ins, p) else { return 0 }
            return Double(ins.param(k))
        } as @convention(block) (Int32, JSValue) -> Double)
        def(h, "paramNames", { (i: Int32) -> [String] in inst(i)?.paramTable.map(\.name) ?? [] } as @convention(block) (Int32) -> [String])
        def(h, "paramIndex", { [unowned self] (i: Int32, p: JSValue) -> Int32 in
            guard let ins = inst(i) else { return -1 }
            return Int32(self.paramIndex(ins, p) ?? -1)
        } as @convention(block) (Int32, JSValue) -> Int32)
        def(h, "instLevel", { (i: Int32, v: Double) -> Double in
            guard Int(i) >= 0 && Int(i) < insts.count else { return 0 }
            if v >= 0 { e.levels[Int(i)] = Float(min(v, 1.5)) }
            return Double(e.levels[Int(i)])
        } as @convention(block) (Int32, Double) -> Double)
        def(h, "instMute", { (i: Int32, b: Bool) in if Int(i) >= 0 && Int(i) < insts.count { e.instMute[Int(i)] = b } } as @convention(block) (Int32, Bool) -> Void)
        // arpeggiator: o may set on, mode (index or name), rate (index or name), octaves, gate, latch
        def(h, "arp", { [unowned self] (i: Int32, o: JSValue) -> [String: Any] in
            guard Int(i) >= 0 && Int(i) < e.arps.count else { return [:] }
            let a = e.arps[Int(i)]
            if o.isObject, let d = o.toDictionary() as? [String: Any], !d.isEmpty {
                PackageHost.applyArp(a, d); self.dirty = true
            }
            return PackageHost.arpState(a)
        } as @convention(block) (Int32, JSValue) -> [String: Any])
        def(h, "arpModes", { () -> [String] in PkgArp.modeNames } as @convention(block) () -> [String])
        def(h, "arpRates", { () -> [String] in PkgArp.rateNames } as @convention(block) () -> [String])
        def(h, "meter", { (i: Int32) -> Double in Double(inst(i)?.meter ?? 0) } as @convention(block) (Int32) -> Double)
        // loads FM bank voice i into the instrument's FM engine: its own one inside a slot, else the app's
        def(h, "fmPreset", { [unowned self] (ii: Int32, i: Int32) -> String in
            let ps = self.model.presets
            guard !ps.isEmpty else { return "" }
            let p = ps[((Int(i) % ps.count) + ps.count) % ps.count]
            var target = inst(ii)
            if let s = target as? SlotInstrument { target = s.current }
            if let f = target as? PrivateFMInstrument { f.engine.loadPatch(p) } else { self.model.engine.loadPatch(p) }
            self.dirty = true
            return p.name
        } as @convention(block) (Int32, Int32) -> String)
        def(h, "instEngine", { [unowned self] (i: Int32, name: String) -> String in
            guard let s = inst(i) as? SlotInstrument else { return inst(i)?.kind ?? "" }
            if !name.isEmpty, s.engineNames[s.selected] != name, s.select(name) { self.dirty = true }
            return s.engineNames[s.selected]
        } as @convention(block) (Int32, String) -> String)
        def(h, "instEngines", { (i: Int32) -> [String] in
            if let s = inst(i) as? SlotInstrument { return s.engineNames }
            return inst(i).map { [$0.kind] } ?? []
        } as @convention(block) (Int32) -> [String])
        def(h, "fmPresetName", { [unowned self] (i: Int32) -> String in
            let ps = self.model.presets
            guard !ps.isEmpty else { return "" }
            return ps[((Int(i) % ps.count) + ps.count) % ps.count].name
        } as @convention(block) (Int32) -> String)

        // sequencer data
        def(h, "trackIDs", { seq.tracks.map(\.id) } as @convention(block) () -> [String])
        def(h, "patternCount", { Int32(seq.patterns) } as @convention(block) () -> Int32)
        def(h, "trackRows", { (t: Int32) -> Int32 in trackOK(t) ? Int32(seq.tracks[Int(t)].rows) : 0 } as @convention(block) (Int32) -> Int32)
        def(h, "divNames", { PkgSequencer.divNames } as @convention(block) () -> [String])
        def(h, "seqGet", { (t: Int32, p: Int32, r: Int32, s: Int32) -> NSDictionary in
            guard trackOK(t) else { return [:] }
            let d = seq.data[Int(t)]
            guard (0..<d.patterns).contains(Int(p)), (0..<d.rows).contains(Int(r)), (0..<PkgSequencer.steps).contains(Int(s)) else { return [:] }
            let k = d.i(Int(p), Int(r), Int(s))
            var notes: [Int] = []
            for n in 0..<4 where d.notes[k * 4 + n] > 0 { notes.append(Int(d.notes[k * 4 + n])) }
            var locks: [[Int]] = []
            for l in 0..<2 where d.lockP[k * 2 + l] != PkgSequencer.rest { locks.append([Int(d.lockP[k * 2 + l]), Int(d.lockV[k * 2 + l])]) }
            return ["vel": Int(d.vel[k]), "len": Int(d.len[k]), "chance": Int(d.chance[k]), "cond": Int(d.cond[k]),
                    "ratchet": Int(d.ratchet[k]), "accent": d.flags[k] & 1 != 0, "slide": d.flags[k] & 2 != 0,
                    "nudge": Int(d.nudge[k]), "notes": notes, "locks": locks]
        } as @convention(block) (Int32, Int32, Int32, Int32) -> NSDictionary)
        def(h, "seqSet", { [unowned self] (t: Int32, p: Int32, r: Int32, s: Int32, o: JSValue) in
            guard trackOK(t) else { return }
            let d = seq.data[Int(t)]
            guard (0..<d.patterns).contains(Int(p)), (0..<d.rows).contains(Int(r)), (0..<PkgSequencer.steps).contains(Int(s)) else { return }
            let k = d.i(Int(p), Int(r), Int(s))
            guard let o = o.toDictionary() as? [String: Any] else { return }
            func num(_ key: String) -> Int? { (o[key] as? NSNumber)?.intValue }
            if let v = num("vel") { d.vel[k] = UInt8(clamping: v) }
            if let v = num("len") { d.len[k] = UInt8(clamping: max(1, v)) }
            if let v = num("chance") { d.chance[k] = UInt8(clamping: min(100, max(0, v))) }
            if let v = num("cond") { d.cond[k] = UInt8(clamping: v) }
            if let v = num("ratchet") { d.ratchet[k] = UInt8(clamping: min(8, max(1, v))) }
            if let v = num("nudge") { d.nudge[k] = Int8(clamping: min(7, max(-8, v))) }
            if let v = o["accent"] as? Bool { d.flags[k] = v ? d.flags[k] | 1 : d.flags[k] & ~1 }
            if let v = o["slide"] as? Bool { d.flags[k] = v ? d.flags[k] | 2 : d.flags[k] & ~2 }
            if let ns = o["notes"] as? [Any] {
                for n in 0..<4 { d.notes[k * 4 + n] = n < ns.count ? UInt8(clamping: (ns[n] as? NSNumber)?.intValue ?? 0) : 0 }
            }
            if let ls = o["locks"] as? [Any] {
                let ins = insts[seq.tracks[Int(t)].instrument]
                for l in 0..<2 {
                    if l < ls.count, let pair = ls[l] as? [Any], pair.count == 2 {
                        let pv = JSValue(object: pair[0], in: self.ctx)!
                        if let pi = self.paramIndex(ins, pv), pi >= 0, pi < 255 {
                            d.lockP[k * 2 + l] = UInt8(pi); d.lockV[k * 2 + l] = UInt8(clamping: (pair[1] as? NSNumber)?.intValue ?? 0)
                            continue
                        }
                    }
                    d.lockP[k * 2 + l] = PkgSequencer.rest
                }
            }
            self.dirty = true
        } as @convention(block) (Int32, Int32, Int32, Int32, JSValue) -> Void)
        def(h, "seqClear", { [unowned self] (t: Int32, p: Int32, r: Int32, s: Int32) in
            guard trackOK(t) else { return }
            let d = seq.data[Int(t)]
            guard (0..<d.patterns).contains(Int(p)) else { return }
            if r < 0 && s < 0 { d.clear(pattern: Int(p)) }
            else {
                for row in 0..<d.rows where r < 0 || row == Int(r) {
                    for st in 0..<PkgSequencer.steps where s < 0 || st == Int(s) { d.clearStep(d.i(Int(p), row, st)) }
                }
            }
            self.dirty = true
        } as @convention(block) (Int32, Int32, Int32, Int32) -> Void)
        def(h, "seqCopy", { [unowned self] (t: Int32, a: Int32, b: Int32) in
            guard trackOK(t) else { return }
            let d = seq.data[Int(t)]
            guard (0..<d.patterns).contains(Int(a)), (0..<d.patterns).contains(Int(b)) else { return }
            d.copy(pattern: Int(a), to: Int(b)); self.dirty = true
        } as @convention(block) (Int32, Int32, Int32) -> Void)
        def(h, "seqHas", { (t: Int32, p: Int32) -> Bool in
            guard trackOK(t), (0..<seq.patterns).contains(Int(p)) else { return false }
            return seq.data[Int(t)].hasData(pattern: Int(p))
        } as @convention(block) (Int32, Int32) -> Bool)
        def(h, "seqLength", { [unowned self] (t: Int32, p: Int32, n: Int32) -> Int32 in
            guard trackOK(t), (0..<seq.patterns).contains(Int(p)) else { return 0 }
            let d = seq.data[Int(t)]
            if n > 0 { d.length[Int(p)] = UInt8(min(64, Int(n))); self.dirty = true }
            return Int32(d.length[Int(p)])
        } as @convention(block) (Int32, Int32, Int32) -> Int32)
        def(h, "seqDiv", { [unowned self] (t: Int32, p: Int32, n: Int32) -> Int32 in
            guard trackOK(t), (0..<seq.patterns).contains(Int(p)) else { return 0 }
            let d = seq.data[Int(t)]
            if n >= 0 { d.div[Int(p)] = UInt8(min(PkgSequencer.divBeats.count - 1, Int(n))); self.dirty = true }
            return Int32(d.div[Int(p)])
        } as @convention(block) (Int32, Int32, Int32) -> Int32)

        // transport
        def(h, "transport", { (cmd: String) -> Bool in
            switch cmd {
            case "play": seq.play()
            case "stop": seq.stop()
            default: break
            }
            return seq.isPlaying
        } as @convention(block) (String) -> Bool)
        def(h, "tempo", { [unowned self] (v: Double) -> Double in
            if v > 0 { seq.tempo = min(300, max(30, v)); self.model.globals.tempo = Int(seq.tempo.rounded()) }
            return seq.tempo
        } as @convention(block) (Double) -> Double)
        def(h, "swing", { (v: Double) -> Double in if v >= 0 { seq.swing = min(75, max(50, v)) }; return seq.swing } as @convention(block) (Double) -> Double)
        def(h, "fill", { (v: Int32) -> Bool in if v >= 0 { seq.fill = v == 1 }; return seq.fill } as @convention(block) (Int32) -> Bool)
        def(h, "trackMute", { (t: Int32, v: Int32) -> Bool in
            guard trackOK(t) else { return false }
            if v >= 0 { seq.mute[Int(t)] = v == 1; if v == 1 { e.post(.allOff) } }
            return seq.mute[Int(t)]
        } as @convention(block) (Int32, Int32) -> Bool)
        def(h, "laneMute", { (t: Int32, l: Int32, v: Int32) -> Bool in
            guard trackOK(t), (0..<16).contains(Int(l)) else { return false }
            if v >= 0 { seq.laneMute[Int(t) * 16 + Int(l)] = v == 1 }
            return seq.laneMute[Int(t) * 16 + Int(l)]
        } as @convention(block) (Int32, Int32, Int32) -> Bool)
        def(h, "select", { [unowned self] (t: Int32, p: Int32) -> Int32 in
            guard trackOK(t) else { return 0 }
            if p >= 0 && Int(p) < seq.patterns { seq.selected[Int(t)] = Int(p); self.dirty = true }
            return Int32(seq.selected[Int(t)])
        } as @convention(block) (Int32, Int32) -> Int32)
        def(h, "playingPattern", { (t: Int32) -> Int32 in trackOK(t) ? Int32(seq.playingPattern(Int(t))) : 0 } as @convention(block) (Int32) -> Int32)
        def(h, "stepNow", { (t: Int32) -> Int32 in trackOK(t) && seq.playing ? Int32(seq.stepNow[Int(t)]) : -1 } as @convention(block) (Int32) -> Int32)
        def(h, "loopCount", { (t: Int32) -> Int32 in trackOK(t) ? Int32(seq.loopCount[Int(t)]) : 0 } as @convention(block) (Int32) -> Int32)
        def(h, "beatPos", { seq.playing ? seq.pos : -1 } as @convention(block) () -> Double)
        def(h, "record", { [unowned self] (t: Int32, note: Int32, vel: Int32, lane: Int32) -> Int32 in
            guard trackOK(t), let (step, nudge) = seq.nearestStep(Int(t)) else { return -1 }
            let d = seq.data[Int(t)]
            let p = seq.playingPattern(Int(t))
            let row = lane >= 0 ? min(Int(lane), d.rows - 1) : 0
            let k = d.i(p, row, step)
            if lane < 0 {
                var free = -1
                for n in 0..<4 {
                    if d.notes[k * 4 + n] == UInt8(clamping: note) { free = -2; break }
                    if d.notes[k * 4 + n] == 0 && free == -1 { free = n }
                }
                if d.vel[k] == 0 { for n in 0..<4 { d.notes[k * 4 + n] = 0 }; free = 0 }
                if free >= 0 { d.notes[k * 4 + free] = UInt8(clamping: note) }
            }
            d.vel[k] = UInt8(clamping: max(1, Int(vel)))
            d.nudge[k] = Int8(nudge)
            self.dirty = true
            return Int32(step)
        } as @convention(block) (Int32, Int32, Int32, Int32) -> Int32)
        def(h, "song", { [unowned self] (sections: JSValue, loop: Bool) in
            let list = (sections.toArray() ?? []).prefix(PkgSequencer.maxSections)
            let T = seq.tracks.count
            for (i, s) in list.enumerated() {
                let o = s as? [String: Any]
                let pats = (o?["patterns"] as? [Any]) ?? []
                for t in 0..<T {
                    let v = t < pats.count ? (pats[t] as? NSNumber)?.intValue ?? -1 : -1
                    seq.songPatterns[i * T + t] = v < 0 ? PkgSequencer.rest : UInt8(clamping: min(v, seq.patterns - 1))
                }
                seq.songRepeats[i] = UInt8(clamping: max(1, (o?["repeats"] as? NSNumber)?.intValue ?? 1))
            }
            seq.songLength = list.count
            seq.songLoop = loop
            self.dirty = true
        } as @convention(block) (JSValue, Bool) -> Void)
        def(h, "songOn", { (v: Int32) -> Bool in if v >= 0 { seq.songOn = v == 1 }; return seq.songOn } as @convention(block) (Int32) -> Bool)
        def(h, "songSection", { Int32(seq.songSection) } as @convention(block) () -> Int32)

        // master, fx
        def(h, "master", { (o: JSValue) in
            guard let d = o.toDictionary() as? [String: Any] else { return }
            if let v = (d["filter"] as? NSNumber)?.floatValue { e.master.filter = min(1, max(-1, v)) }
            if let v = (d["dust"] as? NSNumber)?.floatValue { e.master.dust = min(1, max(0, v)) }
            if let v = (d["duck"] as? NSNumber)?.floatValue { e.master.duck = min(1, max(0, v)) }
        } as @convention(block) (JSValue) -> Void)
        def(h, "punch", { (name: String, beats: Double) in
            e.master.punchBeats = Float(max(0.03125, min(4, beats)))
            e.master.punch = MasterBus.Punch.named(name) ?? .off
            e.master.punchSerial &+= 1
        } as @convention(block) (String, Double) -> Void)
        def(h, "fx", { [unowned self] (kind: String, on: Bool, a: Double, b: Double, c: Double) in
            guard let k = FXChain.Kind.allCases.first(where: { $0.name.lowercased() == kind.lowercased() }) else { return }
            self.model.fx.enabled[k.rawValue] = on
            for (i, v) in [a, b, c].enumerated() where v >= 0 { self.model.fx.setParam(k, i, Int(v)) }
        } as @convention(block) (String, Bool, Double, Double, Double) -> Void)

        // misc
        def(h, "octave", { [unowned self] in Int32(self.model.globals.octave) } as @convention(block) () -> Int32)
        def(h, "velocity", { [unowned self] in Int32(self.model.globals.velocity) } as @convention(block) () -> Int32)
        def(h, "now", { Date().timeIntervalSince1970 * 1000 } as @convention(block) () -> Double)
        def(h, "log", { [unowned self] (s: String) in print("[\(self.firmware.id)] \(s)") } as @convention(block) (String) -> Void)
        def(h, "storeGet", { [unowned self] (k: String) -> Any in self.store[k] ?? NSNull() } as @convention(block) (String) -> Any)
        def(h, "storeSet", { [unowned self] (k: String, v: String) in self.store[k] = v; self.dirty = true } as @convention(block) (String, String) -> Void)
        ctx.setObject(h, forKeyedSubscript: "__host" as NSString)
    }

    // MARK: persistence (Application Support/FirmwareData/<id>/)

    private var dataURL: URL { FirmwareCatalog.dataFolder(for: firmware.id).appendingPathComponent("state.plist") }
    private var pendingParams: [[Double]] = []
    private var pendingSlots: [String: Any] = [:]

    func save() {
        let seq = engine.seq
        func dump(_ inst: PkgInstrument) -> [Double] {
            inst.kind == "fm" ? (0..<FMPatch.size).map { Double(inst.param($0)) } : (0..<inst.paramTable.count).map { Double(inst.param($0)) }
        }
        // slots keep every engine's sound and the selection: [instrument index: {engine, params}]
        var params: [[Double]] = []
        var slots: [String: Any] = [:]
        for (i, inst) in engine.instruments.enumerated() {
            if let s = inst as? SlotInstrument {
                params.append([])
                slots[String(i)] = ["engine": s.engineNames[s.selected], "names": s.engineNames, "params": s.engines.map(dump)]
            } else { params.append(dump(inst)) }
        }
        let T = seq.tracks.count
        let dict: [String: Any] = [
            "version": firmware.version,
            "tracks": seq.data.map { $0.serialize() },
            "trackIDs": seq.tracks.map(\.id),
            "tempo": seq.tempo, "swing": seq.swing,
            "selected": (0..<T).map { seq.selected[$0] },
            "levels": (0..<engine.instruments.count).map { Double(engine.levels[$0]) },
            "params": params,
            "slots": slots,
            "arps": engine.arps.map { PackageHost.arpState($0).filter { $0.key != "step" && $0.key != "modeName" && $0.key != "rateName" } },
            "store": store,
            "song": Data(bytes: seq.songPatterns, count: PkgSequencer.maxSections * max(1, T)),
            "songRepeats": Data(bytes: seq.songRepeats, count: PkgSequencer.maxSections),
            "songLength": seq.songLength, "songOn": seq.songOn, "songLoop": seq.songLoop,
        ]
        do {
            try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let d = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
            try d.write(to: dataURL, options: .atomic)
            dirty = false
            lastSave = Date()
        } catch {
            print("PackageHost: save failed \(error)")
        }
    }

    private func loadPersisted() {
        guard let d = try? Data(contentsOf: dataURL),
              let dict = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any] else { return }
        let seq = engine.seq
        // only restore tracks whose layout still matches the manifest
        if let ids = dict["trackIDs"] as? [String], ids == seq.tracks.map(\.id), let tracks = dict["tracks"] as? [Data] {
            for (i, td) in tracks.enumerated() where i < seq.data.count { seq.data[i].restore(td) }
            if let sel = dict["selected"] as? [Int] { for (i, p) in sel.enumerated() where i < seq.tracks.count { seq.selected[i] = min(p, seq.patterns - 1) } }
            if let s = dict["song"] as? Data, s.count == PkgSequencer.maxSections * max(1, seq.tracks.count) {
                s.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in for k in 0..<s.count { seq.songPatterns[k] = raw[k] } }
            }
            if let s = dict["songRepeats"] as? Data, s.count == PkgSequencer.maxSections {
                s.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in for k in 0..<s.count { seq.songRepeats[k] = raw[k] } }
            }
            seq.songLength = dict["songLength"] as? Int ?? 0
            seq.songOn = dict["songOn"] as? Bool ?? false
            seq.songLoop = dict["songLoop"] as? Bool ?? true
        }
        if let t = dict["tempo"] as? Double { seq.tempo = t }
        if let s = dict["swing"] as? Double { seq.swing = s }
        if let l = dict["levels"] as? [Double] { for (i, v) in l.enumerated() where i < engine.instruments.count { engine.levels[i] = Float(v) } }
        if let st = dict["store"] as? [String: String] { store = st }
        if let arps = dict["arps"] as? [[String: Any]], arps.count == engine.arps.count {
            for (a, d) in zip(engine.arps, arps) { PackageHost.applyArp(a, d) }
        }
        pendingParams = dict["params"] as? [[Double]] ?? []
        pendingSlots = dict["slots"] as? [String: Any] ?? [:]
    }

    /// Applied after the scripts ran (so a script's defaults are overridden by the saved sound).
    private func restoreParams() {
        guard pendingParams.count == engine.instruments.count, store["__restore"] != "\"no\"" else { return }
        func load(_ inst: PkgInstrument, _ ps: [Double]) {
            if inst.kind == "fm" { if ps.count == FMPatch.size { for (i, v) in ps.enumerated() { inst.setParam(i, Float(v)) } } }
            else if ps.count == inst.paramTable.count { for (i, v) in ps.enumerated() { inst.setParam(i, Float(v)) } }
        }
        for (k, (inst, ps)) in zip(engine.instruments, pendingParams).enumerated() {
            if let s = inst as? SlotInstrument {
                guard let d = pendingSlots[String(k)] as? [String: Any], let names = d["names"] as? [String],
                      names == s.engineNames, let all = d["params"] as? [[Double]], all.count == s.engines.count else { continue }
                for (sub, p) in zip(s.engines, all) { load(sub, p) }
                if let e = d["engine"] as? String { _ = s.select(e) }
            } else { load(inst, ps) }
        }
        pendingParams = []; pendingSlots = [:]
    }
}

extension PackageHost {
    /// Applies script/persisted arp settings (names or indices; out-of-range values are clamped).
    nonisolated static func applyArp(_ a: PkgArp, _ d: [String: Any]) {
        func index(_ v: Any?, _ names: [String]) -> Int? {
            if let s = v as? String { return names.firstIndex(of: s.uppercased()) }
            if let n = v as? NSNumber { return min(max(n.intValue, 0), names.count - 1) }
            return nil
        }
        if let m = index(d["mode"], PkgArp.modeNames) { a.mode = m }
        if let r = index(d["rate"], PkgArp.rateNames) { a.rate = r }
        if let o = (d["octaves"] as? NSNumber)?.intValue { a.octaves = min(max(o, 1), 4) }
        if let g = (d["gate"] as? NSNumber)?.doubleValue { a.gate = min(max(g, 0.05), 1) }
        if let l = d["latch"] as? Bool { a.latch = l }
        if let on = d["on"] as? Bool { a.on = on }
    }
    nonisolated static func arpState(_ a: PkgArp) -> [String: Any] {
        ["on": a.on, "mode": a.mode, "modeName": PkgArp.modeNames[a.mode], "rate": a.rate, "rateName": PkgArp.rateNames[a.rate],
         "octaves": a.octaves, "gate": a.gate, "latch": a.latch, "step": a.stepCount]
    }
}

/// A few DX7 VCED parameter names for `fm.inst(...).set("algorithm", 4)` (indices otherwise).
enum FMParamNames {
    static let names: [String: Int] = [
        "algorithm": 134, "feedback": 135, "oscsync": 136, "lfospeed": 137, "lfodelay": 138,
        "lfopmd": 139, "lfoamd": 140, "lfosync": 141, "lfowave": 142, "lfopms": 143, "transpose": 144,
    ]
    static func index(_ s: String) -> Int? {
        if let i = names[s.lowercased()] { return i }
        // "op1.level" … "op6.level" (output level), "op<n>.coarse", "op<n>.fine"
        let parts = s.lowercased().split(separator: ".")
        guard parts.count == 2, parts[0].hasPrefix("op"), let n = Int(parts[0].dropFirst(2)), (1...6).contains(n) else { return nil }
        let base = (6 - n) * 21
        switch parts[1] {
        case "level": return base + 16
        case "coarse": return base + 18
        case "fine": return base + 19
        case "detune": return base + 20
        default: return nil
        }
    }
}
