import SwiftUI
import Combine

/// Extra per-preset data stored beyond the DX7 voice (FX chain, ENV, voice mode).
struct PresetExtra: Codable, Equatable {
    var fxOrder: [Int] = [0, 1, 2, 3, 4, 5]
    var fxOn: [Bool] = Array(repeating: false, count: 6)
    var fxParams: [Int] = FXChain.Kind.allCases.flatMap { $0.defaults }
    var envOn = false
    var adsr: [Int] = [0, 30, 100, 20]
    var mono = false
}

struct GlobalSettings: Codable, Equatable {
    var midiChannel = 0          // 0 = ALL
    var fxChannel = 2
    var bendUp = 2
    var bendDown = 2
    var velocity = 100
    var glideFingered = false
    var glide = 0                // 0...100 → 0...1 s
    var master: Double = 0.75
    var colorway = "black"
    var octave = 0
    var transpose = 0
    var tempo = 120
}

/// Snapshot persisted to disk.
struct SavedState: Codable {
    var presets: [[UInt8]]
    var extras: [PresetExtra]
    var lastImported: [[UInt8]]
    var current: Int
    var globals: GlobalSettings
    var seqNotes: [UInt8]
    var seqTie: [UInt8]
    var seqRate: [UInt8]
    var patLength: [Int], patRate: [Int], patGate: [Int], patSwing: [Int], patChain: [Int], patTranspose: [Int], patVoice: [Int]
    var arp: [Int]?              // mode, octaves, rate, gate, swing, latch
}

enum Mode: Equatable { case home, fx, env, lfo, edit, glo, arp, seq }

enum EditSection: Equatable {
    case op(Int)       // 1...6
    case pitch
    case voice
    var label: String {
        switch self { case .op(let n): return "OP\(n)"; case .pitch: return "PIT"; case .voice: return "GLO" }
    }
}

/// One knob-mapped parameter on a page.
struct PageParam {
    var name: String
    var value: () -> String
    var step: (Int) -> Void
    var hideValue = false
    var bar: (() -> Double)? = nil
}

struct Page {
    var title: String
    var params: [PageParam?]   // up to 4 (K1...K4)
}

@MainActor
final class SynthModel: ObservableObject {
    let audio = AudioController()
    var engine: FMEngine { audio.engine }
    var fx: FXChain { audio.fx }
    var seq: ArpSeq { audio.engine.arpSeq }

    // MARK: Presets
    @Published private(set) var presets: [FMPatch] = []
    @Published private(set) var extras: [PresetExtra] = []
    private var lastImported: [FMPatch] = []
    @Published private(set) var current = 0
    @Published var patch: FMPatch = .initVoice        // edit buffer
    @Published var extra = PresetExtra()               // edit buffer extras
    @Published var globals = GlobalSettings()

    // MARK: UI state
    @Published var mode: Mode = .home
    @Published var page = 0
    @Published var section: EditSection = .op(1)
    private var opPageMemory: [Int] = Array(repeating: 0, count: 6)
    @Published var fxCursor = 0
    @Published var fxGrabbed = false
    @Published var fxLastParam: String? = nil
    @Published var popup: ScreenContent? = nil
    @Published var popupFooter: String? = nil
    @Published var footerOverride: String? = nil
    @Published var mutedOps: Set<Int> = []
    @Published var pressedKeys: Set<Int> = []       // 0...26 physical keys held
    @Published var soundingNotes: Set<Int> = []     // MIDI notes sounding (polled)
    @Published var octHeld: Set<Int> = []           // -1 / +1
    @Published var recording = false
    @Published var recCursor = 0
    @Published var recHeld = false
    @Published var saving = false
    @Published var blinkPhase = false
    @Published var bluetoothConnected = false
    @Published var showBluetooth = false
    @Published var pendingImport: [FMPatch]? = nil
    @Published var importBank = 0
    @Published var dialog: Dialog? = nil
    @Published var renameBuffer = ""
    @Published var renameClass = 0
    @Published var renameChar = 0
    @Published var copySource = 0
    @Published var resetBank = 0
    @Published var transientTick = 0

    enum Dialog: Equatable { case rename, copy, reset }

    private var recChordNotes: [Int] = []
    private var popupTask: Task<Void, Never>?
    private var footerTask: Task<Void, Never>?
    private var timer: Timer?

    var colorway: Colorway { Colorway.all.first { $0.id == globals.colorway } ?? .black }

    // MARK: Init

    init() {
        loadState()
        applyGlobals()
        loadPreset(current, discardEdits: true)
        audio.onSysExPatches = { [weak self] p in self?.receiveSysEx(p) }
        audio.onMIDINote = { _, _ in }
        audio.onProgramChange = { [weak self] pc in self?.selectPreset(pc) }
        audio.onFXControl = { [weak self] cc, v in self?.fxControlChange(cc, v) }
        audio.onConnectionChange = { [weak self] connected in self?.bluetoothConnected = connected }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "-demo"), i + 1 < CommandLine.arguments.count {
            demo(CommandLine.arguments[i + 1])
        }
        #endif
    }

    #if DEBUG
    /// Puts the UI into a given state for screenshot checks.
    private func demo(_ name: String) {
        let parts = name.split(separator: ",").map(String.init)
        for p in parts {
            switch p {
            case "fx": mode = .fx; setExtra { $0.fxOn[0] = true; $0.fxOn[5] = true }; fxCursor = 5; fxLastParam = "Freq: 30%"
            case "env": press(.env)
            case "lfo": press(.lfo)
            case "edit": press(.edit)
            case "tuning": press(.edit); page = 2
            case "voice": press(.edit); section = .voice
            case "glo": press(.glo)
            case "arp": press(.arp)
            case "seq":
                press(.seq)
                for (i, n) in [60, 64, 67, 72, 60, 0, 67, 0, 62, 65, 69, 74, 0, 0, 59, 55].enumerated() where n > 0 { seq.setNotes(pattern: 0, step: i, [n]) }
                seq.playing = true
            case "algo": turnAlgorithm(0); popupTask?.cancel()
            case let c where c.hasPrefix("alg="): setPatch { $0[.algorithm] = (Int(c.dropFirst(4)) ?? 1) - 1 }
            case "presets": selectPreset(127); popupTask?.cancel()
            case "import": pendingImport = presets.prefix(32).map { $0 }; importBank = 1
            case "play": engine.noteOn(60, velocity: 100); engine.noteOn(67, velocity: 100); pressedKeys = [7, 14]
            case let c where c.hasPrefix("color="): globals.colorway = String(c.dropFirst(6))
            case let c where c.hasPrefix("preset="): loadPreset((Int(c.dropFirst(7)) ?? 1) - 1)
            default: break
            }
        }
    }
    #endif

    private var tickCount = 0
    private func tick() {
        tickCount += 1
        if tickCount % 4 == 0 { blinkPhase.toggle() }
        let notes = Set(engine.soundingNotes())
        if notes != soundingNotes { soundingNotes = notes }
        if seq.seqOn { objectWillChange.send() } // step LED playhead
    }

    // MARK: Factory data

    static func factoryBank() -> [FMPatch] {
        var all: [FMPatch] = []
        for b in ["A", "B", "C", "D"] {
            if let url = Bundle.main.url(forResource: "FM1_V15_factory_bank_\(b)", withExtension: "syx"),
               let d = try? Data(contentsOf: url) {
                all += FMPatch.parseSysEx([UInt8](d)).prefix(32)
            }
        }
        while all.count < 128 { all.append(.initVoice) }
        return Array(all.prefix(128))
    }

    // MARK: Persistence

    private var stateURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fm1-state.json")
    }

    private func loadState() {
        if let d = try? Data(contentsOf: stateURL), let s = try? JSONDecoder().decode(SavedState.self, from: d), s.presets.count == 128 {
            presets = s.presets.map { FMPatch(data: $0) }
            extras = s.extras.count == 128 ? s.extras : Array(repeating: PresetExtra(), count: 128)
            lastImported = s.lastImported.count == 128 ? s.lastImported.map { FMPatch(data: $0) } : SynthModel.factoryBank()
            current = min(127, max(0, s.current))
            globals = s.globals
            let n = ArpSeq.patterns * ArpSeq.steps
            if s.seqNotes.count == n * ArpSeq.notesPerStep { for i in 0..<s.seqNotes.count { seq.stepNotes[i] = s.seqNotes[i] } }
            if s.seqTie.count == n { for i in 0..<n { seq.stepTie[i] = s.seqTie[i] } }
            if s.seqRate.count == n { for i in 0..<n { seq.stepRate[i] = s.seqRate[i] } }
            if s.patLength.count == 16 {
                seq.patLength = s.patLength; seq.patRate = s.patRate; seq.patGate = s.patGate
                seq.patSwing = s.patSwing; seq.patChain = s.patChain; seq.patTranspose = s.patTranspose; seq.patVoice = s.patVoice
            }
            if let a = s.arp, a.count >= 6 {
                seq.arpMode = ArpSeq.ArpMode(rawValue: a[0]) ?? .up
                seq.arpOctaves = a[1]; seq.arpRate = a[2]; seq.arpGate = a[3]; seq.arpSwing = a[4]; seq.arpLatch = a[5] != 0
            }
        } else {
            presets = SynthModel.factoryBank()
            lastImported = presets
            extras = Array(repeating: PresetExtra(), count: 128)
        }
    }

    func persist() {
        let n = ArpSeq.patterns * ArpSeq.steps
        let s = SavedState(
            presets: presets.map(\.data), extras: extras, lastImported: lastImported.map(\.data),
            current: current, globals: globals,
            seqNotes: Array(UnsafeBufferPointer(start: seq.stepNotes, count: n * ArpSeq.notesPerStep)),
            seqTie: Array(UnsafeBufferPointer(start: seq.stepTie, count: n)),
            seqRate: Array(UnsafeBufferPointer(start: seq.stepRate, count: n)),
            patLength: seq.patLength, patRate: seq.patRate, patGate: seq.patGate, patSwing: seq.patSwing,
            patChain: seq.patChain, patTranspose: seq.patTranspose, patVoice: seq.patVoice,
            arp: [seq.arpMode.rawValue, seq.arpOctaves, seq.arpRate, seq.arpGate, seq.arpSwing, seq.arpLatch ? 1 : 0])
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: stateURL, options: .atomic) }
    }

    /// Globals that the hardware auto-saves (octave, transpose, master …).
    private func persistGlobalsSoon() {
        globalsSaveTask?.cancel()
        globalsSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.persistGlobalsOnly()
        }
    }
    private var globalsSaveTask: Task<Void, Never>?
    func persistGlobalsNow() { persist() }
    private func persistGlobalsOnly() {
        // Only globals: re-encode with saved presets (edit buffer is NOT written)
        persist()
    }

    // MARK: Engine sync

    func applyGlobals() {
        engine.masterVolume = Float(globals.master)
        engine.bendUp = Float(globals.bendUp)
        engine.bendDown = Float(globals.bendDown)
        engine.glideTime = Float(globals.glide) / 100
        engine.glideFingered = globals.glideFingered
        seq.tempo = Double(globals.tempo)
        seq.velocity = UInt8(clamping: globals.velocity)
        audio.midiChannel = globals.midiChannel
        audio.fxChannel = globals.fxChannel
    }

    private func pushPatch() { engine.loadPatch(patch) }

    private func pushExtra() {
        for i in 0..<6 { fx.order[i] = extra.fxOrder[i]; fx.enabled[i] = extra.fxOn[i] }
        for i in 0..<18 { fx.params[i] = extra.fxParams[i] }
        engine.envOn = extra.envOn
        engine.envA = Float(extra.adsr[0]) / 100
        engine.envD = Float(extra.adsr[1]) / 100
        engine.envS = Float(extra.adsr[2]) / 100
        engine.envR = Float(extra.adsr[3]) / 100
        engine.monoMode = extra.mono
    }

    func setPatch(_ mutate: (inout FMPatch) -> Void) {
        mutate(&patch)
        pushPatch()
    }

    func setExtra(_ mutate: (inout PresetExtra) -> Void) {
        mutate(&extra)
        pushExtra()
    }

    // MARK: Presets

    func loadPreset(_ i: Int, discardEdits: Bool = true) {
        current = (i % 128 + 128) % 128
        patch = presets[current]
        extra = extras[current]
        mutedOps = []
        engine.opMuteMask = 0
        if extra.mono != engine.monoMode { engine.allNotesOff() }
        pushPatch()
        pushExtra()
    }

    func selectPreset(_ i: Int) {
        loadPreset(i)
        showPopup(.presetList(2, (-2...2).map { d in
            let k = ((current + d) % 128 + 128) % 128
            return String(format: "%03d %@", k + 1, presets[k].name)
        }), duration: 1.0)
        persistGlobalsSoon()
    }

    func saveCurrent() {
        presets[current] = patch
        extras[current] = extra
        saving = true
        persist()
        showPopup(.message("Preset Saved", nil), duration: 1.0)
        Task { try? await Task.sleep(for: .seconds(0.6)); saving = false }
    }

    // MARK: SysEx

    func receiveSysEx(_ patches: [FMPatch]) {
        if patches.count >= 32 {
            pendingImport = Array(patches.prefix(32))
            importBank = current / 32
        } else if let p = patches.first {
            // single voice → edit buffer
            setPatch { $0 = p }
            showPopup(.message("Voice Received", p.name), duration: 1.2)
        }
    }

    func importFile(_ data: Data) {
        let ps = FMPatch.parseSysEx([UInt8](data))
        if ps.isEmpty { showPopup(.message("Invalid SysEx", nil), duration: 1.5) } else { receiveSysEx(ps) }
    }

    func confirmImport() {
        guard let ps = pendingImport else { return }
        let base = importBank * 32
        for i in 0..<32 {
            presets[base + i] = ps[i]
            lastImported[base + i] = ps[i]
            extras[base + i] = PresetExtra()
        }
        pendingImport = nil
        persist()
        loadPreset(base)
        showPopup(.message("Bank \(["A", "B", "C", "D"][importBank]) Loaded", "32 voices"), duration: 1.5)
    }

    func exportBank(_ bank: Int) -> Data {
        Data(FMPatch.bankSysEx(Array(presets[(bank * 32)..<(bank * 32 + 32)])))
    }

    // MARK: Popups

    func showPopup(_ c: ScreenContent, footer: String? = nil, duration: Double) {
        popup = c
        popupFooter = footer
        popupTask?.cancel()
        popupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.popup = nil
            self?.popupFooter = nil
        }
    }

    private func flashFooter(_ text: String) {
        footerOverride = text
        footerTask?.cancel()
        footerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            self?.footerOverride = nil
        }
    }

    // MARK: Pages

    private func opParam(_ op: Int, _ p: FMPatch.OpParam, _ name: String, format: ((Int) -> String)? = nil) -> PageParam {
        PageParam(name: name,
                  value: { [unowned self] in format?(patch[op: op, p]) ?? "\(patch[op: op, p])" },
                  step: { [unowned self] d in setPatch { $0[op: op, p] += d } })
    }

    private func gParam(_ p: FMPatch.GlobalParam, _ name: String, format: ((Int) -> String)? = nil) -> PageParam {
        PageParam(name: name,
                  value: { [unowned self] in format?(patch[p]) ?? "\(patch[p])" },
                  step: { [unowned self] d in setPatch { $0[p] += d } })
    }

    private func cycle(_ v: Int, _ d: Int, _ range: ClosedRange<Int>) -> Int { min(max(v + d, range.lowerBound), range.upperBound) }

    static let curveNames = ["-LN", "-EX", "+EX", "+LN"]
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static func breakPointName(_ v: Int) -> String {
        let n = v + 21 // A-1 = MIDI 21
        return "\(noteNames[n % 12])\(n / 12 - 2)"
    }

    func freqString(op: Int) -> String {
        let coarse = patch[op: op, .coarse], fine = patch[op: op, .fine]
        if patch[op: op, .oscMode] == 1 {
            let hz = pow(10, Double(coarse & 3) + Double(fine) / 100)
            return hz >= 1000 ? String(format: "%.2fkHz", hz / 1000) : String(format: "%.2fHz", hz)
        }
        let r = (coarse == 0 ? 0.5 : Double(coarse)) * (1 + Double(fine) / 100)
        return String(format: "%.2f", r)
    }

    var pages: [Page] {
        switch mode {
        case .home: return []
        case .fx: return []
        case .env:
            let names = ["Attack", "Decay", "Sustain", "Release"]
            return [Page(title: "ENV", params: (0..<4).map { i in
                PageParam(name: names[i],
                          value: { [unowned self] in "\(extra.adsr[i])%" },
                          step: { [unowned self] d in setExtra { $0.adsr[i] = cycle($0.adsr[i], d, 0...100) } },
                          hideValue: true,
                          bar: { [unowned self] in Double(extra.adsr[i]) / 100 })
            })]
        case .lfo:
            let waves = ["Triangle", "Saw Down", "Saw Up", "Square", "Sine", "S&Hold"]
            return [
                Page(title: "LFO", params: [
                    gParam(.lfoWave, "Wave", format: { waves[min(5, $0)] }),
                    gParam(.lfoSpeed, "Speed"), gParam(.lfoPMD, "PMD"), gParam(.lfoAMD, "AMD")]),
                Page(title: "LFO", params: [
                    gParam(.lfoDelay, "Delay"), gParam(.lfoPMS, "Pitch Sens"),
                    gParam(.lfoSync, "Key Sync", format: { $0 == 1 ? "Sync" : "Free" }),
                    gParam(.oscKeySync, "Osc Sync", format: { $0 == 1 ? "ON" : "OFF" })]),
            ]
        case .edit:
            switch section {
            case .op(let op):
                let n = "OP\(op)"
                return [
                    Page(title: "\(n) Envelope", params: [opParam(op, .r1, "Rate 1"), opParam(op, .r2, "Rate 2"), opParam(op, .r3, "Rate 3"), opParam(op, .r4, "Rate 4")]),
                    Page(title: "\(n) Env Level", params: [opParam(op, .l1, "Level 1"), opParam(op, .l2, "Level 2"), opParam(op, .l3, "Level 3"), opParam(op, .l4, "Level 4")]),
                    Page(title: "\(n) Tuning", params: [
                        opParam(op, .detune, "Detune", format: { "\($0 - 7)" }),
                        opParam(op, .coarse, "FreqCoarse"),
                        opParam(op, .fine, "FreqFine"),
                        opParam(op, .oscMode, "OscMode", format: { $0 == 1 ? "Fixed" : "Ratio" })]),
                    Page(title: "\(n) Output", params: [
                        opParam(op, .outputLevel, "Level"),
                        opParam(op, .velSens, "Key Velo"),
                        opParam(op, .ampModSens, "AmpMod"),
                        PageParam(name: "Freq", value: { [unowned self] in freqString(op: op) }, step: { _ in })]),
                    Page(title: "\(n) Scaling", params: [
                        opParam(op, .leftDepth, "L Depth"), opParam(op, .rightDepth, "R Depth"),
                        opParam(op, .breakPoint, "BreakPoint", format: SynthModel.breakPointName), nil]),
                    Page(title: "\(n) Curves", params: [
                        opParam(op, .leftCurve, "L Curve", format: { SynthModel.curveNames[$0] }),
                        opParam(op, .rightCurve, "R Curve", format: { SynthModel.curveNames[$0] }),
                        opParam(op, .rateScaling, "Rate Scale"), nil]),
                ]
            case .pitch:
                return [
                    Page(title: "Pitch EG Rate", params: [gParam(.pr1, "Rate 1"), gParam(.pr2, "Rate 2"), gParam(.pr3, "Rate 3"), gParam(.pr4, "Rate 4")]),
                    Page(title: "Pitch EG Level", params: [gParam(.pl1, "Level 1"), gParam(.pl2, "Level 2"), gParam(.pl3, "Level 3"), gParam(.pl4, "Level 4")]),
                ]
            case .voice:
                return [
                    Page(title: "Globe", params: [
                        gParam(.algorithm, "Algorithm", format: { "\($0 + 1)" }),
                        gParam(.feedback, "Feedback"),
                        gParam(.oscKeySync, "Osc Sync", format: { $0 == 1 ? "ON" : "OFF" }),
                        gParam(.transpose, "Transpose", format: { "\($0 - 24)" })]),
                    Page(title: "Globe", params: [
                        PageParam(name: "Init Voice", value: { "" }, step: { [unowned self] d in
                            if d > 0 { setPatch { $0 = .initVoice }; showPopup(.message("Init Voice", nil), duration: 0.8) } }, hideValue: true),
                        PageParam(name: "Rename", value: { "" }, step: { [unowned self] d in if d > 0 { openRename() } }, hideValue: true),
                        PageParam(name: "Copy Voice", value: { "" }, step: { [unowned self] d in if d > 0 { copySource = current; dialog = .copy } }, hideValue: true),
                        nil]),
                ]
            }
        case .glo:
            return [
                Page(title: "Global", params: [
                    PageParam(name: "MIDI Ch", value: { [unowned self] in globals.midiChannel == 0 ? "ALL" : "\(globals.midiChannel)" },
                              step: { [unowned self] d in globals.midiChannel = cycle(globals.midiChannel, d, 0...16); applyGlobals() }),
                    PageParam(name: "Effect Ch", value: { [unowned self] in "\(globals.fxChannel)" },
                              step: { [unowned self] d in globals.fxChannel = cycle(globals.fxChannel, d, 1...16); applyGlobals() }),
                    PageParam(name: "Bend Up", value: { [unowned self] in "\(globals.bendUp)" },
                              step: { [unowned self] d in globals.bendUp = cycle(globals.bendUp, d, 1...24); applyGlobals() }),
                    PageParam(name: "Bend Down", value: { [unowned self] in "\(globals.bendDown)" },
                              step: { [unowned self] d in globals.bendDown = cycle(globals.bendDown, d, 1...24); applyGlobals() }),
                ]),
                Page(title: "Global", params: [
                    PageParam(name: "Reset", value: { "Patches" }, step: { [unowned self] d in if d > 0 { resetBank = 0; dialog = .reset } }),
                    PageParam(name: "Velocity", value: { [unowned self] in "\(globals.velocity)" },
                              step: { [unowned self] d in globals.velocity = cycle(globals.velocity, d, 1...127); applyGlobals() }),
                    PageParam(name: "Glide Mode", value: { [unowned self] in globals.glideFingered ? "Fingered" : "Full Time" },
                              step: { [unowned self] _ in globals.glideFingered.toggle(); applyGlobals() }),
                    PageParam(name: "Glide Val", value: { [unowned self] in "\(globals.glide)" },
                              step: { [unowned self] d in globals.glide = cycle(globals.glide, d, 0...100); applyGlobals() }),
                ]),
            ]
        case .arp:
            return [
                Page(title: "Arpeggio", params: [
                    PageParam(name: "Mode", value: { [unowned self] in seq.arpMode.label },
                              step: { [unowned self] d in seq.arpMode = ArpSeq.ArpMode(rawValue: cycle(seq.arpMode.rawValue, d, 0...6))!; objectWillChange.send() }, hideValue: true),
                    PageParam(name: "Octave", value: { [unowned self] in "\(seq.arpOctaves)" },
                              step: { [unowned self] d in seq.arpOctaves = cycle(seq.arpOctaves, d, 1...4); objectWillChange.send() }),
                    PageParam(name: "Rate", value: { [unowned self] in ArpSeq.rates[seq.arpRate].0 },
                              step: { [unowned self] d in seq.arpRate = cycle(seq.arpRate, d, 0...(ArpSeq.rates.count - 1)); objectWillChange.send() }),
                    tempoParam(),
                ]),
                Page(title: "Arpeggio", params: [
                    PageParam(name: "Gate", value: { [unowned self] in "\(seq.arpGate)%" },
                              step: { [unowned self] d in seq.arpGate = cycle(seq.arpGate, d, 20...100); objectWillChange.send() }),
                    PageParam(name: "Swing", value: { [unowned self] in "\(seq.arpSwing)%" },
                              step: { [unowned self] d in seq.arpSwing = cycle(seq.arpSwing, d, 50...75); objectWillChange.send() }),
                    PageParam(name: "Latch", value: { [unowned self] in seq.arpLatch ? "ON" : "OFF" },
                              step: { [unowned self] d in seq.arpLatch = d > 0; if !seq.arpLatch { engine.allNotesOff() }; objectWillChange.send() }),
                    PageParam(name: "Sync", value: { "OFF" }, step: { _ in }),
                ]),
            ]
        case .seq:
            let p = seq.pattern
            return [
                Page(title: "Sequencer", params: [
                    PageParam(name: "Pattern", value: { [unowned self] in "\(seq.pattern + 1)" },
                              step: { [unowned self] d in seq.pattern = cycle(seq.pattern, d, 0...15); recCursor = 0; bindPatternVoice(); objectWillChange.send() }),
                    PageParam(name: "Clear", value: { "" }, step: { [unowned self] d in
                        if d > 0 { seq.clear(pattern: seq.pattern); recCursor = 0; showPopup(.message("Pattern Cleared", nil), duration: 0.8) } }, hideValue: true),
                    PageParam(name: "Chain", value: { [unowned self] in "\(seq.patChain[p])" },
                              step: { [unowned self] d in seq.patChain[p] = cycle(seq.patChain[p], d, 1...16); objectWillChange.send() }),
                    PageParam(name: "Step", value: { [unowned self] in "\(seq.patLength[p])" },
                              step: { [unowned self] d in seq.patLength[p] = cycle(seq.patLength[p], d, 1...16); objectWillChange.send() }),
                ]),
                Page(title: "Sequencer", params: [
                    PageParam(name: "Voice", value: { [unowned self] in seq.patVoice[p] < 0 ? "---" : String(format: "%03d", seq.patVoice[p] + 1) },
                              step: { [unowned self] d in
                                  seq.patVoice[p] = cycle(seq.patVoice[p], d, -1...127)
                                  if seq.patVoice[p] >= 0 { loadPreset(seq.patVoice[p]) }
                                  objectWillChange.send() }),
                    PageParam(name: "Rate", value: { [unowned self] in
                                  if recording, seq.stepRate[p * 16 + recCursor] != 0xFF { return ArpSeq.rates[Int(seq.stepRate[p * 16 + recCursor])].0 }
                                  return ArpSeq.rates[seq.patRate[p]].0 },
                              step: { [unowned self] d in
                                  if recording {
                                      let i = p * 16 + recCursor
                                      let cur = seq.stepRate[i] == 0xFF ? seq.patRate[p] : Int(seq.stepRate[i])
                                      seq.stepRate[i] = UInt8(cycle(cur, d, 0...(ArpSeq.rates.count - 1)))
                                  } else {
                                      seq.patRate[p] = cycle(seq.patRate[p], d, 0...(ArpSeq.rates.count - 1))
                                  }
                                  objectWillChange.send() }),
                    tempoParam(),
                    PageParam(name: "Gate", value: { [unowned self] in "\(seq.patGate[p])%" },
                              step: { [unowned self] d in seq.patGate[p] = cycle(seq.patGate[p], d, 20...100); objectWillChange.send() }),
                ]),
                Page(title: "Sequencer", params: [
                    PageParam(name: "Swing", value: { [unowned self] in "\(seq.patSwing[p])%" },
                              step: { [unowned self] d in seq.patSwing[p] = cycle(seq.patSwing[p], d, 50...75); objectWillChange.send() }),
                    PageParam(name: "Sync", value: { "OFF" }, step: { _ in }),
                    PageParam(name: "Transpose", value: { [unowned self] in "\(seq.patTranspose[p])" },
                              step: { [unowned self] d in seq.patTranspose[p] = cycle(seq.patTranspose[p], d, -24...24); objectWillChange.send() }),
                    nil,
                ]),
            ]
        }
    }

    private func tempoParam() -> PageParam {
        PageParam(name: "Tempo", value: { [unowned self] in "\(globals.tempo)" },
                  step: { [unowned self] d in globals.tempo = cycle(globals.tempo, d, 30...300); applyGlobals() })
    }

    var currentPages: [Page] { pages }

    // MARK: Screen state

    var screen: ScreenState {
        var s = ScreenState()
        s.presetNumber = current + 1
        s.presetName = patch.name
        s.trailing = "\(globals.octave + 3)"
        let pgs = pages
        let pg = pgs.isEmpty ? nil : pgs[min(page, pgs.count - 1)]
        let pageLabel = pgs.count > 1 ? "\(min(page, pgs.count - 1) + 1)/\(pgs.count) " : ""

        if let pending = pendingImport {
            _ = pending
            s.content = .save(bankName: "", selected: importBank)
            s.footer = "OSC"
            return s
        }
        if let d = dialog {
            switch d {
            case .rename:
                s.content = .message("Rename", renameDisplay)
                s.footer = "K3 Char  OP5 Del  SELECT OK"
            case .copy:
                s.content = .message("Copy Voice", String(format: "%03d %@ →\n%03d", copySource + 1, presets[copySource].name, current + 1))
                s.footer = "K4 Source  SELECT OK"
            case .reset:
                s.content = .message("Reset Patches", "Bank \(["A", "B", "C", "D"][resetBank])")
                s.footer = "K1-K4 Bank  SELECT OK"
            }
            return s
        }
        if let p = popup {
            s.content = p
            s.footer = popupFooter ?? (mode == .home ? "OSC" : footerTitle(pageLabel, pg))
            return s
        }
        switch mode {
        case .home:
            s.content = .osc
            s.footer = footerOverride ?? "OSC"
        case .fx:
            let active = (0..<6).map { extra.fxOn[extra.fxOrder[$0]] }
            s.content = .fx(selected: fxCursor, active: active)
            s.fxNames = extra.fxOrder.map { FXChain.Kind(rawValue: $0)!.name }
            s.fxGrabbed = fxGrabbed
            s.footer = footerOverride ?? fxLastParam ?? FXChain.Kind(rawValue: extra.fxOrder[fxCursor])!.name
        default:
            if let pg {
                s.content = .tiles(pg.params.map { p in
                    guard let p else { return ScreenTile(name: "", value: nil) }
                    let v = p.value()
                    // value-only tiles (e.g. ARP mode shows "Up")
                    let name = (p.hideValue && p.bar == nil && !v.isEmpty) ? v : p.name
                    return ScreenTile(name: name, value: p.hideValue ? nil : v, bar: p.bar?())
                })
            }
            s.footer = footerOverride ?? footerTitle(pageLabel, pg)
        }
        return s
    }

    private var renameDisplay: String {
        let classes = SynthModel.renameClasses
        let ch = classes[renameClass][renameChar % classes[renameClass].count]
        return renameBuffer + "[\(ch)]"
    }
    static let renameClasses: [[Character]] = [
        Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), Array("abcdefghijklmnopqrstuvwxyz"),
        Array(" .-_!#&()*+/:<=>?@"), Array("0123456789"),
    ]

    private func footerTitle(_ label: String, _ pg: Page?) -> String {
        guard let pg else { return "OSC" }
        return label + pg.title
    }

    // MARK: Controls — encoders

    func turnMaster(_ d: Int) {
        globals.master = min(1, max(0, globals.master + Double(d) * 0.02))
        applyGlobals()
        showPopup(.message("Volume \(Int(globals.master * 100))", nil), duration: 0.8)
        persistGlobalsSoon()
    }

    func turnSelect(_ d: Int) {
        if let dlg = dialog {
            if d > 0 {
                switch dlg {
                case .rename: commitRename()
                case .copy:
                    setPatch { $0 = presets[copySource] }
                    setExtra { $0 = extras[copySource] }
                    dialog = nil
                    showPopup(.message("Copy Done", "Hold SAVE to store"), duration: 1.2)
                case .reset:
                    let base = resetBank * 32
                    for i in 0..<32 { presets[base + i] = lastImported[base + i]; extras[base + i] = PresetExtra() }
                    persist()
                    dialog = nil
                    loadPreset(current)
                    showPopup(.message("Reset Success", nil), duration: 1.0)
                }
            } else { dialog = nil }
            return
        }
        if pendingImport != nil { if d > 0 { confirmImport() } else { pendingImport = nil }; return }
        if mode == .seq && recording && recHeld {
            recCursor = cycle(recCursor, d, 0...(seq.patLength[seq.pattern] - 1))
            return
        }
        if mode == .seq && recording && !recChordNotes.isEmpty && d > 0 {
            // long note: extend the held chord over following steps
            let p = seq.pattern
            for _ in 0..<d where recCursor < seq.patLength[p] - 1 {
                recCursor += 1
                seq.stepTie[p * 16 + recCursor] = 1
                seq.setNotes(pattern: p, step: recCursor, [])
            }
            tieExtended = true
            return
        }
        if mode == .fx {
            if fxGrabbed {
                let to = cycle(fxCursor, d, 0...5)
                if to != fxCursor { setExtra { $0.fxOrder.swapAt(fxCursor, to) }; fxCursor = to }
            } else {
                fxCursor = cycle(fxCursor, d, 0...5)
            }
            fxLastParam = nil
            return
        }
        let n = pages.count
        guard n > 0 else { return }
        page = cycle(page, d, 0...(n - 1))
        if mode == .edit, case .op(let op) = section { opPageMemory[op - 1] = page }
        footerOverride = nil
    }
    private var tieExtended = false

    func turnPresets(_ d: Int) {
        if seq.seqOn { showPopup(.message("Disable SEQ", "Voice bound to pattern"), duration: 1); return }
        selectPreset(current + d)
    }

    func turnAlgorithm(_ d: Int) {
        if !octHeld.isEmpty {
            let sign = octHeld.contains(1) ? 1 : -1
            let range = sign > 0 ? 0...12 : -12...0
            globals.transpose = cycle(globals.transpose, d, range)
            if globals.transpose != 0 && (globals.transpose > 0) != (sign > 0) { globals.transpose = 0 }
            engine.allNotesOff()
            showPopup(.message("Transpose \(globals.transpose)", nil), duration: 1)
            octTransposeUsed = true
            persistGlobalsSoon()
            return
        }
        setPatch { $0[.algorithm] += d }
        showPopup(.algorithm(patch[.algorithm] + 1, feedback: patch[.feedback]), footer: "OSC", duration: 1.0)
    }

    func turnKnob(_ k: Int, _ d: Int) {
        if pendingImport != nil { importBank = k; return }
        if let dlg = dialog {
            switch dlg {
            case .reset: resetBank = k
            case .copy: if k == 3 { copySource = ((copySource + d) % 128 + 128) % 128 }
            case .rename:
                if k == 2 {
                    let c = SynthModel.renameClasses[renameClass].count
                    renameChar = ((renameChar + d) % c + c) % c
                } else if k == 1 && d < 0 { dialog = nil }
            }
            return
        }
        if mode == .fx {
            let kind = FXChain.Kind(rawValue: extra.fxOrder[fxCursor])!
            if k == 3 {
                setExtra { $0.fxOn[kind.rawValue] = d > 0 }
                fxLastParam = "\(kind.name): \(extra.fxOn[kind.rawValue] ? "ON" : "OFF")"
            } else {
                let idx = kind.rawValue * 3 + k
                let r = kind.range(k)
                setExtra { $0.fxParams[idx] = min(max($0.fxParams[idx] + d, r.lowerBound), r.upperBound) }
                fxLastParam = "\(kind.paramNames[k]): \(kind.display(k, extra.fxParams[idx]))"
            }
            return
        }
        let pgs = pages
        guard !pgs.isEmpty else { return }
        let pg = pgs[min(page, pgs.count - 1)]
        guard k < pg.params.count, let p = pg.params[k] else { return }
        p.step(d)
        // re-read the param after the change for the footer
        let fresh = pages[min(page, pages.count - 1)].params[k]
        if let fresh { flashFooter("\(fresh.name): \(fresh.value())") }
        objectWillChange.send()
    }

    // MARK: Controls — buttons

    func press(_ b: PanelButton) {
        if pendingImport != nil {
            if b == .home { pendingImport = nil } else if b == .save { confirmImport() }
            return
        }
        if dialog != nil && b == .home { dialog = nil; return }
        switch b {
        case .fx: toggleMode(.fx)
        case .sel:
            if mode == .fx { fxGrabbed.toggle() }
        case .env:
            if mode == .env && extra.envOn { setExtra { $0.envOn = false }; mode = .home }
            else { setExtra { $0.envOn = true }; enter(.env) }
        case .lfo: toggleMode(.lfo)
        case .edit: toggleMode(.edit)
        case .glo: toggleMode(.glo)
        case .home:
            mode = .home; page = 0; fxGrabbed = false
        case .save:
            showPopup(.message("Hold SAVE", "to store preset"), duration: 0.9)
        case .arp:
            if seq.seqOn { showPopup(.message("Disable SEQ to enter", nil), duration: 1.2); return }
            if mode == .arp && seq.arpOn {
                seq.arpOn = false; engine.allNotesOff(); mode = .home
            } else if seq.arpOn {
                enter(.arp)
            } else {
                engine.allNotesOff(); seq.arpOn = true; enter(.arp)
            }
        case .seq:
            if seq.arpOn { showPopup(.message("Disable ARP to enter", nil), duration: 1.2); return }
            if mode == .seq && seq.seqOn {
                seq.playing = false; seq.seqOn = false; recording = false; engine.allNotesOff(); mode = .home
            } else if seq.seqOn {
                enter(.seq)
            } else {
                seq.seqOn = true; enter(.seq); bindPatternVoice()
            }
        case .play:
            guard seq.seqOn else { showPopup(.message("Enable SEQ first", nil), duration: 1.2); return }
            seq.playing.toggle()
            if !seq.playing { engine.allNotesOff() }
        case .rec:
            guard seq.seqOn else { showPopup(.message("Enable SEQ first", nil), duration: 1.2); return }
            recording.toggle()
            if recording { recCursor = 0 }
            recChordNotes = []
        case .octDown, .octUp: break
        }
        objectWillChange.send()
    }

    func longPress(_ b: PanelButton) {
        switch b {
        case .save: saveCurrent()
        case .home: showBluetooth = true
        case .play:
            engine.panic(); seq.playing = false
            showPopup(.message("Panic", "All notes off"), duration: 0.8)
        default: break
        }
    }

    private var octTransposeUsed = false

    func octDown(_ dir: Int) {
        octHeld.insert(dir)
        octTransposeUsed = false
        if octHeld.count == 2 {
            globals.octave = 0; globals.transpose = 0
            engine.allNotesOff()
            showPopup(.message("Octave 0", "Transpose 0"), duration: 1)
            octTransposeUsed = true
            persistGlobalsSoon()
        }
    }

    func octUp(_ dir: Int) {
        octHeld.remove(dir)
        if !octTransposeUsed {
            globals.octave = cycle(globals.octave, dir, -3...3)
            engine.allNotesOff()
            showPopup(.message("Octave \(globals.octave)", nil), duration: 1)
            persistGlobalsSoon()
        }
        if octHeld.isEmpty { octTransposeUsed = false }
    }

    private func toggleMode(_ m: Mode) {
        if mode == m { mode = .home; page = 0; fxGrabbed = false } else { enter(m) }
    }

    private func enter(_ m: Mode) {
        mode = m
        fxGrabbed = false
        footerOverride = nil
        if m == .edit, case .op(let op) = section { page = opPageMemory[op - 1] } else { page = 0 }
    }

    private func bindPatternVoice() {
        let v = seq.patVoice[seq.pattern]
        if v >= 0 && v != current { loadPreset(v) }
    }

    // MARK: Rename

    private func openRename() {
        renameBuffer = patch.name
        renameClass = 0; renameChar = 0
        dialog = .rename
    }

    private func commitRename() {
        setPatch { $0.name = renameBuffer }
        dialog = nil
        showPopup(.message("Renamed", patch.name), duration: 1)
    }

    // MARK: Keyboard

    static let blackKeys: [Int] = [1, 3, 5, 8, 10, 13, 15, 17, 20, 22, 25]
    static let whiteKeys: [Int] = [0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18, 19, 21, 23, 24, 26]
    static let editLabels: [Int: String] = [1: "OP1", 3: "OP2", 5: "OP3", 8: "OP4", 10: "OP5", 13: "OP6", 15: "PIT", 17: "GLO", 20: "MONO", 22: "POLY"]

    func midiNote(forKey k: Int) -> Int { 53 + k + globals.octave * 12 + globals.transpose }

    private var keyNoteMap: [Int: Int] = [:]
    private var keyDownTime: [Int: Date] = [:]

    func keyDown(_ k: Int, velocity: Int) {
        pressedKeys.insert(k)
        // Rename: OP1-4 select class, OP5 delete
        if dialog == .rename, let label = SynthModel.editLabels[k] {
            switch label {
            case "OP1": renameClass = 0
            case "OP2": renameClass = 1
            case "OP3": renameClass = 2
            case "OP4": renameClass = 3
            case "OP5": if !renameBuffer.isEmpty { renameBuffer.removeLast() }
            default: break
            }
            renameChar = 0
            return
        }
        if dialog == .rename && SynthModel.whiteKeys.contains(k) {
            // white keys append the current character
            if renameBuffer.count < 10 {
                let cls = SynthModel.renameClasses[renameClass]
                renameBuffer.append(cls[renameChar % cls.count])
            }
            return
        }
        if mode == .edit, let label = SynthModel.editLabels[k] {
            keyDownTime[k] = Date()
            switch label {
            case "PIT": section = .pitch; page = 0
            case "GLO": section = .voice; page = 0
            case "MONO": setExtra { $0.mono = true }; engine.allNotesOff()
            case "POLY": setExtra { $0.mono = false }; engine.allNotesOff()
            default:
                if let n = Int(label.dropFirst(2)) {
                    if section != .op(n) { section = .op(n); page = opPageMemory[n - 1] }
                }
            }
            footerOverride = nil
            return
        }
        let note = midiNote(forKey: k)
        keyNoteMap[k] = note
        engine.noteOn(note, velocity: globals.velocity)
        if mode == .seq && recording {
            if !recChordNotes.contains(note) { recChordNotes.append(note) }
            let p = seq.pattern
            if recChordNotes.count == 1 && !tieExtended {
                // starting a new chord replaces the step contents
                seq.setNotes(pattern: p, step: recCursor, [])
                seq.stepTie[p * 16 + recCursor] = 0
            }
            seq.addNote(pattern: p, step: recCursor, note)
        }
    }

    func keyUp(_ k: Int) {
        pressedKeys.remove(k)
        if mode == .edit, let label = SynthModel.editLabels[k], label.hasPrefix("OP"), let n = Int(label.dropFirst(2)) {
            if let t = keyDownTime[k], Date().timeIntervalSince(t) > 0.6 {
                if mutedOps.contains(n) { mutedOps.remove(n) } else { mutedOps.insert(n) }
                var mask = 0
                for o in mutedOps { mask |= 1 << (o - 1) }
                engine.opMuteMask = mask
                showPopup(.message("OP\(n) \(mutedOps.contains(n) ? "Muted" : "On")", nil), duration: 0.8)
            }
            keyDownTime[k] = nil
            return
        }
        if dialog == .rename || (mode == .edit && SynthModel.editLabels[k] != nil) { return }
        if let note = keyNoteMap.removeValue(forKey: k) {
            engine.noteOff(note)
            if mode == .seq && recording {
                recChordNotes.removeAll { $0 == note }
                if recChordNotes.isEmpty {
                    tieExtended = false
                    recCursor = (recCursor + 1) % max(1, seq.patLength[seq.pattern])
                }
            }
        }
    }

    // MARK: LEDs

    func keyLED(_ k: Int) -> Color? {
        let lit = Color(hex: 0xd9f3ff)
        if pressedKeys.contains(k) { return lit }
        if mode == .edit, let label = SynthModel.editLabels[k] {
            let selected: Bool
            switch label {
            case "PIT": selected = section == .pitch
            case "GLO": selected = section == .voice
            case "MONO": selected = extra.mono
            case "POLY": selected = !extra.mono
            default:
                let n = Int(label.dropFirst(2)) ?? 0
                if mutedOps.contains(n) { return blinkPhase ? Color(hex: 0xff5a4a) : nil }
                selected = section == .op(n)
            }
            return selected ? lit : (blinkPhase ? lit.opacity(0.55) : nil)
        }
        if seq.seqOn, let si = SynthModel.whiteKeys.firstIndex(of: k) {
            let p = seq.playing ? seq.currentPattern : seq.pattern
            if si >= seq.patLength[seq.pattern] { return nil }
            if seq.playing && seq.currentStep == si { return blinkPhase ? lit : Color(hex: 0x58b8ff) }
            if recording && recCursor == si { return blinkPhase ? Color(hex: 0xff6a5a) : nil }
            if seq.hasNotes(pattern: p, step: si) { return Color(hex: 0x8fd6ff) }
            return nil
        }
        if soundingNotes.contains(midiNote(forKey: k)) { return lit }
        return nil
    }

    func buttonLight(_ b: PanelButton) -> ButtonLight {
        switch b {
        case .fx: return mode == .fx ? .on : .off
        case .sel: return fxGrabbed ? .on : .off
        case .env: return mode == .env ? .on : (extra.envOn ? .blue : .off)
        case .lfo: return mode == .lfo ? .on : .off
        case .edit: return mode == .edit ? .on : .off
        case .glo: return mode == .glo ? .on : .off
        case .home: return bluetoothConnected ? .on : .off
        case .save: return saving ? .on : .off
        case .arp: return mode == .arp ? .on : (seq.arpOn ? .blue : .off)
        case .seq: return mode == .seq ? .on : (seq.seqOn ? .blue : .off)
        case .play:
            guard seq.seqOn else { return .off }
            return seq.playing ? .green : .red
        case .rec: return recording ? .red : .off
        case .octDown:
            return octLight(sign: -1)
        case .octUp:
            return octLight(sign: 1)
        }
    }

    private func octLight(sign: Int) -> ButtonLight {
        let o = globals.octave
        guard o != 0, (o > 0) == (sign > 0) else { return .off }
        switch abs(o) {
        case 1: return (tickCount / 8) % 2 == 0 ? .on : .off   // slow blink
        case 2: return blinkPhase ? .on : .off                  // fast blink
        default: return .on
        }
    }

    // MARK: MIDI FX CCs (V15 map CC0-23 on the effect channel)

    func fxControlChange(_ cc: Int, _ v: Int) {
        guard cc >= 0 && cc < 24 else { return }
        let ccKind = cc / 4   // 0 Filter, 1 Reverb, 2 Delay, 3 Distortion, 4 Chorus, 5 Phaser
        let slot = cc % 4
        setExtra { e in
            if slot == 0 { e.fxOn[ccKind] = v >= 1; return }
            let kind = FXChain.Kind(rawValue: ccKind)!
            var value = v
            if kind == .filter && slot == 2 { value = Int(Double(min(v, 107)) / 107 * 100) }
            if kind == .filter && slot == 3 { value = min(v, 10) * 10 }
            let r = kind.range(slot - 1)
            e.fxParams[ccKind * 3 + slot - 1] = min(max(value, r.lowerBound), r.upperBound)
        }
    }
}

enum PanelButton: Hashable {
    case fx, sel, env, lfo, edit, glo, home, save, arp, seq, play, rec, octDown, octUp
}
