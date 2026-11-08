import SwiftUI

/// Groove mode: the opt-in groovebox sequencer (synth track + 808-style drum
/// track) using the community FM-1 firmware panel grammar.
///
/// SEQ page:  white keys = 16 steps of the page · OCT−/OCT+ = step page ·
///            black keys = drum lane · SEL = synth/drum track ·
///            hold a step + K1–K4 = step attributes, + SELECT = gate/tie,
///            + ALGORITHM = lock parameter, + PRESETS = lock value.
/// Hold GLO:  perform layer (mute / solo / fill / tap tempo, black keys mute lanes).
extension SynthModel {
    var groove: GrooveSeq { audio.groove }
    var drums: DrumKit { audio.drums }

    /// Keys act as the step grid.
    var grooveGrid: Bool { grooveMode && mode == .seq && groove.on }

    static let groovePageNames = ["Pattern", "Euclid", "Kit", "Tools"]

    /// Parameters that can be locked per step: (VCED index, name)
    static let lockables: [(Int, String)] = {
        var l: [(Int, String)] = [(134, "Algorithm"), (135, "Feedback"), (144, "Transpose"),
                                  (137, "LFO Speed"), (139, "LFO PMD"), (140, "LFO AMD")]
        for op in 1...6 { l.append((FMPatch.opBase(op) + 16, "OP\(op) Level")) }
        for op in 1...6 { l.append((FMPatch.opBase(op) + 18, "OP\(op) Coarse")) }
        for op in 1...6 { l.append((FMPatch.opBase(op) + 3, "OP\(op) Rate4")) }
        return l
    }()

    // MARK: Mode switching

    func setGrooveMode(_ on: Bool, quiet: Bool = false) {
        guard on != grooveMode else { return }
        // stop everything first
        seq.playing = false; seq.seqOn = false
        groove.playing = false; groove.on = false
        recording = false
        engine.allNotesOff()
        grooveMode = on
        UserDefaults.standard.set(on, forKey: "grooveMode")
        if mode == .seq { mode = .home }
        if !quiet { showPopup(.message(on ? "Groove Mode" : "Stock Sequencer", on ? "SEQ = groovebox" : "V15 behaviour"), duration: 1.2) }
    }

    func syncGrooveBase() {
        groove.basePatch.update(from: patch.data, count: FMPatch.size)
    }

    // MARK: Buttons

    /// Returns true when the press was handled by groove mode.
    func grooveButton(_ b: PanelButton) -> Bool {
        guard grooveMode else { return false }
        switch b {
        case .seq:
            if seq.arpOn { showPopup(.message("Disable ARP to enter", nil), duration: 1.2); return true }
            if mode == .seq && groove.on {
                groove.playing = false; groove.on = false; recording = false
                engine.allNotesOff(); mode = .home
            } else {
                groove.on = true
                mode = .seq; page = 0; grooveHeld = nil
            }
            return true
        case .play:
            guard groove.on else { showPopup(.message("Enable SEQ first", nil), duration: 1.2); return true }
            groove.playing.toggle()
            if !groove.playing { engine.allNotesOff() }
            return true
        case .rec:
            guard groove.on else { showPopup(.message("Enable SEQ first", nil), duration: 1.2); return true }
            recording.toggle()
            grooveRecCursor = 0
            recChordCount = 0
            if recording { showPopup(.message("REC Synth", groove.playing ? "Live: play keys" : "Step: play keys"), duration: 1.0) }
            return true
        case .sel where mode == .seq && groove.on:
            grooveTrack = grooveTrack == 0 ? 1 : 0
            grooveHeld = nil
            return true
        case .glo where gloLayerUsed:
            gloLayerUsed = false
            return true
        default:
            return false
        }
    }

    /// OCT buttons page through steps on the SEQ grid.
    func grooveOct(_ dir: Int) -> Bool {
        guard grooveGrid else { return false }
        let len = grooveTrack == 0 ? groove.synthLen[groove.pattern] : groove.drumLen[groove.pattern]
        let pages = max(1, (len + 15) / 16)
        groovePage = max(0, min(pages - 1, groovePage + dir))
        return true
    }

    // MARK: Keys

    func grooveKeyDown(_ k: Int) -> Bool {
        // GLO perform layer
        if gloHeld && grooveMode && groove.on {
            gloLayerUsed = true
            if let w = SynthModel.whiteKeys.firstIndex(of: k) {
                switch w {
                case 0: groove.synthMute.toggle()
                case 1: groove.drumMute.toggle()
                case 4: groove.synthSolo.toggle()
                case 5: groove.drumSolo.toggle()
                case 8: groove.fill = true
                case 15: tapTempo()
                default: break
                }
            } else if let b = SynthModel.blackKeys.firstIndex(of: k) {
                groove.laneMute[b].toggle()
            }
            objectWillChange.send()
            return true
        }
        guard grooveGrid else { return false }
        if let w = SynthModel.whiteKeys.firstIndex(of: k) {
            grooveHeld = groovePage * 16 + w
            grooveHeldUsed = false
            return true
        }
        if let b = SynthModel.blackKeys.firstIndex(of: k) {
            grooveTrack = 1
            grooveLane = b
            drums.preview(b, velocity: 100)
            return true
        }
        return true
    }

    func grooveKeyUp(_ k: Int) -> Bool {
        if grooveMode && groove.on && (gloHeld || gloLayerUsed) {
            if SynthModel.whiteKeys.firstIndex(of: k) == 8 { groove.fill = false }
            if gloHeld || !grooveGrid { return true }
        }
        guard grooveGrid else { return false }
        if let w = SynthModel.whiteKeys.firstIndex(of: k) {
            let step = groovePage * 16 + w
            if grooveHeld == step && !grooveHeldUsed { toggleStep(step) }
            if grooveHeld == step { grooveHeld = nil }
        }
        return true
    }

    private func toggleStep(_ step: Int) {
        let p = groove.pattern
        if grooveTrack == 1 {
            let i = groove.di(p, grooveLane, step)
            groove.dVel[i] = groove.dVel[i] == 0 ? 100 : 0
            if groove.dVel[i] != 0 && !groove.playing { drums.preview(grooveLane, velocity: 100) }
        } else {
            if groove.synthHas(p, step) {
                groove.setSynthNotes(p, step, [])
            } else {
                groove.setSynthNotes(p, step, [grooveLastNote], velocity: globals.velocity)
                if !groove.playing { engine.noteOn(grooveLastNote, velocity: globals.velocity); let n = grooveLastNote
                    Task { try? await Task.sleep(for: .seconds(0.2)); self.engine.noteOff(n) } }
            }
        }
        objectWillChange.send()
    }

    /// Recording from the normal keyboard (any page except the step grid).
    func grooveRecordNote(_ note: Int) {
        guard grooveMode && groove.on && recording else { return }
        grooveLastNote = note
        let p = groove.pattern
        if groove.playing {
            let s = groove.nearestSynthStep()
            groove.addSynthNote(p, s, note, velocity: globals.velocity)
        } else {
            if recChordCount == 0 { groove.setSynthNotes(p, grooveRecCursor, []) }
            groove.addSynthNote(p, grooveRecCursor, note, velocity: globals.velocity)
            recChordCount += 1
        }
    }

    func grooveRecordRelease() {
        guard grooveMode && groove.on && recording && !groove.playing && recChordCount > 0 else { return }
        if pressedKeys.isEmpty {
            recChordCount = 0
            grooveRecCursor = (grooveRecCursor + 1) % max(1, groove.synthLen[groove.pattern])
        }
    }

    private func tapTempo() {
        let now = Date()
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        if tapTimes.count >= 2 {
            let iv = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
            let bpm = 60 / (iv.reduce(0, +) / Double(iv.count))
            globals.tempo = Int(min(300, max(30, bpm)).rounded())
            applyGlobals()
            showPopup(.message("Tempo \(globals.tempo)", nil), duration: 0.8)
        }
    }

    // MARK: Encoders

    func grooveKnob(_ k: Int, _ d: Int) -> Bool {
        guard grooveGrid else { return false }
        let p = groove.pattern
        if let step = grooveHeld {
            grooveHeldUsed = true
            if grooveTrack == 1 {
                let i = groove.di(p, grooveLane, step)
                switch k {
                case 0: groove.dVel[i] = UInt8(clamping: min(127, max(0, Int(groove.dVel[i]) + d * 4)))
                case 1: groove.dCond[i] = UInt8(min(9, max(0, Int(groove.dCond[i]) + d)))
                case 2: groove.dRatchet[i] = UInt8(min(4, max(1, Int(groove.dRatchet[i]) + d)))
                default: break
                }
                if groove.dVel[i] == 0 && k != 0 { groove.dVel[i] = 100 }
            } else {
                let i = groove.si(p, step)
                if !groove.synthHas(p, step) { groove.setSynthNotes(p, step, [grooveLastNote], velocity: globals.velocity) }
                switch k {
                case 0:
                    let notes = groove.synthNotes(p, step).map { min(127, max(1, $0 + d)) }
                    groove.setSynthNotes(p, step, notes, velocity: Int(groove.sVel[i]))
                    grooveLastNote = notes.first ?? grooveLastNote
                case 1: groove.sVel[i] = UInt8(clamping: min(127, max(1, Int(groove.sVel[i]) + d * 4)))
                case 2: groove.sCond[i] = UInt8(min(9, max(0, Int(groove.sCond[i]) + d)))
                case 3: groove.sRatchet[i] = UInt8(min(4, max(1, Int(groove.sRatchet[i]) + d)))
                default: break
                }
            }
            objectWillChange.send()
            return true
        }
        switch page {
        case 0: // Pattern
            switch k {
            case 0:
                let to = min(GrooveSeq.patterns - 1, max(0, (groove.queuedPattern >= 0 ? groove.queuedPattern : groove.pattern) + d))
                if groove.playing { groove.queuedPattern = to == groove.pattern ? -1 : to } else { groove.pattern = to }
            case 1:
                if grooveTrack == 0 { groove.synthLen[p] = min(64, max(1, groove.synthLen[p] + d)) }
                else { groove.drumLen[p] = min(64, max(1, groove.drumLen[p] + d)) }
                let len = grooveTrack == 0 ? groove.synthLen[p] : groove.drumLen[p]
                groovePage = min(groovePage, (len - 1) / 16)
            case 2: globals.tempo = min(300, max(30, globals.tempo + d)); applyGlobals()
            default: groove.swing[p] = min(75, max(50, groove.swing[p] + d))
            }
        case 1: // Euclid (drum lane)
            var e = euclidSettings[p][grooveLane]
            switch k {
            case 0: e.hits = min(e.steps, max(0, e.hits + d))
            case 1: e.steps = min(64, max(1, e.steps + d)); e.hits = min(e.hits, e.steps)
            case 2: e.rotate = ((e.rotate + d) % e.steps + e.steps) % e.steps
            default: e.velocity = min(127, max(20, e.velocity + d * 4))
            }
            euclidSettings[p][grooveLane] = e
            grooveTrack = 1
            groove.euclid(p, lane: grooveLane, hits: e.hits, steps: e.steps, rotate: e.rotate, velocity: e.velocity)
        case 2: // Kit
            let idx = grooveLane * 4 + k
            drums.params[idx] = UInt8(min(127, max(0, Int(drums.params[idx]) + d * 2)))
            grooveTrack = 1
            if !groove.playing { drums.preview(grooveLane, velocity: 100) }
        default: // Tools
            switch k {
            case 0 where d > 0:
                if grooveTrack == 0 { groove.clearSynth(p) } else { groove.clearLane(p, grooveLane) }
                showPopup(.message(grooveTrack == 0 ? "Synth Cleared" : "\(DrumKit.names[grooveLane]) Cleared", nil), duration: 0.8)
            case 1 where d > 0:
                let to = (p + 1) % GrooveSeq.patterns
                groove.copyPattern(p, to)
                euclidSettings[to] = euclidSettings[p]
                showPopup(.message("Copied", "Pattern \(p + 1) → \(to + 1)"), duration: 1.0)
            case 2:
                densityValue = min(100, max(0, densityValue + d * 5))
                grooveTrack = 1
                groove.densityFill(p, lane: grooveLane, density: Double(densityValue) / 100)
            case 3:
                globals.drumLevel = min(100, max(0, (globals.drumLevel ?? 80) + d * 2)); applyGlobals()
            default: break
            }
        }
        objectWillChange.send()
        return true
    }

    func grooveSelect(_ d: Int) -> Bool {
        guard grooveGrid else { return false }
        if let step = grooveHeld, grooveTrack == 0 {
            grooveHeldUsed = true
            let i = groove.si(groove.pattern, step)
            if !groove.synthHas(groove.pattern, step) { groove.setSynthNotes(groove.pattern, step, [grooveLastNote], velocity: globals.velocity) }
            groove.sGate[i] = UInt8(min(Int(GrooveSeq.tieGate), max(1, Int(groove.sGate[i]) + d)))
            objectWillChange.send()
            return true
        }
        page = min(SynthModel.groovePageNames.count - 1, max(0, page + d))
        return true
    }

    /// Hold a synth step + ALGORITHM = choose lock parameter.
    func grooveAlgorithm(_ d: Int) -> Bool {
        guard grooveGrid else { return false }
        guard grooveHeld != nil, grooveTrack == 0 else { return true }
        grooveHeldUsed = true
        let n = SynthModel.lockables.count
        lockSelection = ((lockSelection + d) % n + n) % n
        objectWillChange.send()
        return true
    }

    /// Hold a synth step + PRESETS = lock value for the selected parameter.
    func groovePresets(_ d: Int) -> Bool {
        guard grooveGrid else { return false }
        guard let step = grooveHeld, grooveTrack == 0 else { return true }
        grooveHeldUsed = true
        let p = groove.pattern
        let i = groove.si(p, step)
        if !groove.synthHas(p, step) { groove.setSynthNotes(p, step, [grooveLastNote], velocity: globals.velocity) }
        let (prm, _) = SynthModel.lockables[lockSelection]
        let base = i * GrooveSeq.locksPerStep
        var slot = -1
        for k in 0..<GrooveSeq.locksPerStep where groove.sLockParam[base + k] == UInt8(prm) { slot = k }
        if slot < 0 {
            for k in 0..<GrooveSeq.locksPerStep where groove.sLockParam[base + k] == 0xFF { slot = k; break }
            guard slot >= 0 else { showPopup(.message("LOCK FULL", "4 per step"), duration: 1); return true }
            groove.sLockParam[base + slot] = UInt8(prm)
            groove.sLockVal[base + slot] = UInt8(patch.data[prm])
        }
        let maxV = lockMax(prm)
        let v = min(maxV, max(0, Int(groove.sLockVal[base + slot]) + d))
        groove.sLockVal[base + slot] = UInt8(v)
        if v == Int(patch.data[prm]) { groove.sLockParam[base + slot] = 0xFF } // back to preset value = no lock
        objectWillChange.send()
        return true
    }

    private func lockMax(_ prm: Int) -> Int {
        switch prm {
        case 134: return 31
        case 135: return 7
        case 144: return 48
        default:
            let field = prm < 126 ? prm % 21 : -1
            return field == 18 ? 31 : 99
        }
    }

    private func lockDisplay(_ prm: Int, _ v: Int) -> String {
        switch prm {
        case 134: return "\(v + 1)"
        case 144: return "\(v - 24)"
        default: return "\(v)"
        }
    }

    // MARK: Screen

    func grooveScreen() -> (ScreenContent, String)? {
        guard grooveMode && groove.on else { return nil }
        if gloHeld {
            let tiles = [
                ScreenTile(name: "Synth", value: groove.synthMute ? "MUTE" : (groove.synthSolo ? "SOLO" : "ON"), dim: groove.synthMute),
                ScreenTile(name: "Drums", value: groove.drumMute ? "MUTE" : (groove.drumSolo ? "SOLO" : "ON"), dim: groove.drumMute),
                ScreenTile(name: "Fill", value: groove.fill ? "ON" : "key 9"),
                ScreenTile(name: "Tap", value: "\(globals.tempo) BPM"),
            ]
            return (.tiles(tiles), "Perform")
        }
        guard mode == .seq else { return nil }
        let p = groove.pattern
        if let step = grooveHeld {
            if grooveTrack == 1 {
                let i = groove.di(p, grooveLane, step)
                return (.tiles([
                    ScreenTile(name: "Velocity", value: groove.dVel[i] == 0 ? "OFF" : "\(groove.dVel[i])"),
                    ScreenTile(name: "Chance", value: GrooveSeq.conditionNames[Int(groove.dCond[i])]),
                    ScreenTile(name: "Ratchet", value: "x\(groove.dRatchet[i])"),
                    ScreenTile(name: DrumKit.shortNames[grooveLane], value: "Step \(step + 1)"),
                ]), "Step \(step + 1) \(DrumKit.names[grooveLane])")
            }
            let i = groove.si(p, step)
            let notes = groove.synthNotes(p, step)
            let noteName = notes.isEmpty ? "---" : notes.map { SynthModel.noteName($0) }.joined(separator: " ")
            let gate = groove.sGate[i] == GrooveSeq.tieGate ? "TIE" : "\(Int(groove.sGate[i]) * 100 / 16)%"
            let (prm, prmName) = SynthModel.lockables[lockSelection]
            var lockVal = "—"
            let base = i * GrooveSeq.locksPerStep
            for k in 0..<GrooveSeq.locksPerStep where groove.sLockParam[base + k] == UInt8(prm) { lockVal = lockDisplay(prm, Int(groove.sLockVal[base + k])) }
            var locks = 0
            for k in 0..<GrooveSeq.locksPerStep where groove.sLockParam[base + k] != 0xFF { locks += 1 }
            return (.tiles([
                ScreenTile(name: "Note", value: noteName),
                ScreenTile(name: "Velocity", value: notes.isEmpty ? "-" : "\(groove.sVel[i])"),
                ScreenTile(name: "Chance", value: GrooveSeq.conditionNames[Int(groove.sCond[i])]),
                ScreenTile(name: "Ratchet", value: "x\(groove.sRatchet[i])"),
            ]), "S\(step + 1) Gate \(gate) · \(prmName): \(lockVal)" + (locks > 0 ? " [\(locks)L]" : ""))
        }
        // step grid
        let len = grooveTrack == 0 ? groove.synthLen[p] : groove.drumLen[p]
        let playStep = groove.playing ? (grooveTrack == 0 ? groove.synthStep : groove.drumStep) : -1
        var cells: [GrooveCell] = []
        for w in 0..<16 {
            let s = groovePage * 16 + w
            var c = GrooveCell()
            c.inRange = s < len
            c.playhead = s == playStep
            c.cursor = recording && !groove.playing && grooveTrack == 0 && s == grooveRecCursor
            if grooveTrack == 1 {
                let i = groove.di(p, grooveLane, s)
                c.on = groove.dVel[i] != 0
                c.label = c.on ? (groove.dVel[i] >= 110 ? "ACC" : "HIT") : "-"
                c.ratchet = Int(groove.dRatchet[i])
                c.cond = groove.dCond[i] != 0
            } else {
                let i = groove.si(p, s)
                let n = groove.synthNotes(p, s)
                c.on = !n.isEmpty
                c.label = n.isEmpty ? "-" : SynthModel.noteName(n[0]) + (n.count > 1 ? "+" : "")
                c.ratchet = Int(groove.sRatchet[i])
                c.cond = groove.sCond[i] != 0
                c.tie = groove.sGate[i] == GrooveSeq.tieGate
                var locked = false
                for k in 0..<GrooveSeq.locksPerStep where groove.sLockParam[i * GrooveSeq.locksPerStep + k] != 0xFF { locked = true }
                c.lock = locked
            }
            cells.append(c)
        }
        let knobs: [(String, String)]
        switch page {
        case 0:
            let pat = groove.queuedPattern >= 0 ? "\(p + 1)>\(groove.queuedPattern + 1)" : "\(p + 1)"
            knobs = [("PAT", pat), ("LEN", "\(len)"), ("BPM", "\(globals.tempo)"), ("SWG", "\(groove.swing[p])")]
        case 1:
            let e = euclidSettings[p][grooveLane]
            knobs = [("HITS", "\(e.hits)"), ("STEPS", "\(e.steps)"), ("ROT", "\(e.rotate)"), ("VEL", "\(e.velocity)")]
        case 2:
            knobs = (0..<4).map { (DrumKit.paramNames[$0].uppercased(), "\(drums.params[grooveLane * 4 + $0])") }
        default:
            knobs = [("CLEAR", "→"), ("COPY", "→\((p + 1) % GrooveSeq.patterns + 1)"), ("DENS", "\(densityValue)"), ("DRUMS", "\(globals.drumLevel ?? 80)")]
        }
        let g = GrooveScreen(
            track: grooveTrack == 0 ? "SYNTH" : DrumKit.names[grooveLane],
            trackColor: grooveTrack == 0 ? 0 : 1,
            pattern: p + 1,
            page: groovePage, pages: max(1, (len + 15) / 16),
            cells: cells, knobs: knobs.map { GrooveKnob(name: $0.0, value: $0.1) },
            rec: recording, playing: groove.playing,
            mutes: [groove.synthMute, groove.drumMute])
        return (.groove(g), "\(page + 1)/\(SynthModel.groovePageNames.count) \(SynthModel.groovePageNames[page])")
    }

    static func noteName(_ n: Int) -> String { "\(noteNames[n % 12])\(n / 12 - 1)" }

    // MARK: LEDs

    func grooveKeyLED(_ k: Int) -> Color?? {
        guard grooveMode && groove.on else { return nil }
        let lit = Color(hex: 0xd9f3ff)
        if gloHeld {
            if let w = SynthModel.whiteKeys.firstIndex(of: k) {
                switch w {
                case 0: return .some(groove.synthMute ? Color(hex: 0xff5a4a) : lit)
                case 1: return .some(groove.drumMute ? Color(hex: 0xff5a4a) : lit)
                case 4: return .some(groove.synthSolo ? Color(hex: 0xffd24a) : lit.opacity(0.4))
                case 5: return .some(groove.drumSolo ? Color(hex: 0xffd24a) : lit.opacity(0.4))
                case 8: return .some(groove.fill ? Color(hex: 0x5dff7a) : lit.opacity(0.4))
                case 15: return .some(blinkPhase ? lit : lit.opacity(0.3))
                default: return .some(nil)
                }
            }
            if let b = SynthModel.blackKeys.firstIndex(of: k) { return .some(groove.laneMute[b] ? Color(hex: 0xff5a4a) : lit.opacity(0.5)) }
        }
        guard mode == .seq else { return nil }
        let p = groove.pattern
        if let w = SynthModel.whiteKeys.firstIndex(of: k) {
            let s = groovePage * 16 + w
            let len = grooveTrack == 0 ? groove.synthLen[p] : groove.drumLen[p]
            if s >= len { return .some(nil) }
            if pressedKeys.contains(k) { return .some(lit) }
            let on = grooveTrack == 0 ? groove.synthHas(p, s) : groove.drumHas(p, grooveLane, s)
            let play = groove.playing ? (grooveTrack == 0 ? groove.synthStep : groove.drumStep) : -1
            if s == play { return .some(on ? Color(hex: 0x5dff7a) : lit.opacity(0.85)) }
            if recording && !groove.playing && grooveTrack == 0 && s == grooveRecCursor { return .some(blinkPhase ? Color(hex: 0xff6a5a) : nil) }
            if on { return .some(grooveTrack == 0 ? Color(hex: 0x8fd6ff) : Color(hex: 0xffb86b)) }
            return .some(w % 4 == 0 ? lit.opacity(0.12) : nil)  // beat grid hint
        }
        if let b = SynthModel.blackKeys.firstIndex(of: k) {
            if grooveTrack == 1 && b == grooveLane { return .some(Color(hex: 0xffb86b)) }
            if drums.laneMeter[b] > 0.15 { return .some(Color(hex: 0xffb86b).opacity(Double(min(1, drums.laneMeter[b])))) }
            if groove.laneMute[b] { return .some(Color(hex: 0xff5a4a).opacity(0.5)) }
            return .some(groove.laneHasHits(p, b) ? lit.opacity(0.25) : nil)
        }
        return nil
    }
}

struct EuclidSetting: Codable, Equatable { var hits = 4; var steps = 16; var rotate = 0; var velocity = 100 }

struct GrooveCell: Equatable {
    var label = "-"
    var on = false
    var inRange = true
    var playhead = false
    var cursor = false
    var ratchet = 1
    var cond = false
    var tie = false
    var lock = false
}
struct GrooveKnob: Equatable { var name: String; var value: String }
struct GrooveScreen: Equatable {
    var track: String
    var trackColor: Int
    var pattern: Int
    var page: Int
    var pages: Int
    var cells: [GrooveCell]
    var knobs: [GrooveKnob]
    var rec: Bool
    var playing: Bool
    var mutes: [Bool]
}

/// Persisted groove data (all byte buffers).
struct GrooveSaved: Codable {
    var sNotes, sVel, sGate, sCond, sRatchet, sLockParam, sLockVal: [UInt8]
    var dVel, dCond, dRatchet: [UInt8]
    var synthLen, drumLen, swing: [Int]
    var kit: [UInt8]
    var euclid: [[EuclidSetting]]

    init(_ g: GrooveSeq, kit k: DrumKit, euclid: [[EuclidSetting]]) {
        let ps = GrooveSeq.patterns * GrooveSeq.steps
        let pd = GrooveSeq.patterns * GrooveSeq.lanes * GrooveSeq.steps
        func a(_ p: UnsafeMutablePointer<UInt8>, _ n: Int) -> [UInt8] { Array(UnsafeBufferPointer(start: p, count: n)) }
        sNotes = a(g.sNotes, ps * GrooveSeq.notesPerStep); sVel = a(g.sVel, ps); sGate = a(g.sGate, ps)
        sCond = a(g.sCond, ps); sRatchet = a(g.sRatchet, ps)
        sLockParam = a(g.sLockParam, ps * GrooveSeq.locksPerStep); sLockVal = a(g.sLockVal, ps * GrooveSeq.locksPerStep)
        dVel = a(g.dVel, pd); dCond = a(g.dCond, pd); dRatchet = a(g.dRatchet, pd)
        synthLen = g.synthLen; drumLen = g.drumLen; swing = g.swing
        kit = a(k.params, DrumKit.laneCount * 4)
        self.euclid = euclid
    }

    func restore(into g: GrooveSeq, kit k: DrumKit) {
        func r(_ src: [UInt8], _ p: UnsafeMutablePointer<UInt8>) { src.withUnsafeBufferPointer { p.update(from: $0.baseAddress!, count: $0.count) } }
        let ps = GrooveSeq.patterns * GrooveSeq.steps
        let pd = GrooveSeq.patterns * GrooveSeq.lanes * GrooveSeq.steps
        guard sVel.count == ps, dVel.count == pd, sNotes.count == ps * GrooveSeq.notesPerStep,
              sLockParam.count == ps * GrooveSeq.locksPerStep, kit.count == DrumKit.laneCount * 4 else { return }
        r(sNotes, g.sNotes); r(sVel, g.sVel); r(sGate, g.sGate); r(sCond, g.sCond); r(sRatchet, g.sRatchet)
        r(sLockParam, g.sLockParam); r(sLockVal, g.sLockVal)
        r(dVel, g.dVel); r(dCond, g.dCond); r(dRatchet, g.dRatchet)
        if synthLen.count == GrooveSeq.patterns { g.synthLen = synthLen; g.drumLen = drumLen; g.swing = swing }
        r(kit, k.params)
    }
}
