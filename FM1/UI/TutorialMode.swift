import SwiftUI

// MARK: - Tutorial mode
//
// When tutorial mode is on, every knob and button on the panel (not the
// piano keys) shows a small badge. Tapping it opens a card explaining how to
// use the control, how it affects the sound and anything else worth knowing.
// Detailed content exists for the native firmware (FM-1 Stock V15); for any
// other firmware only the firmware-independent behaviour is described.

enum TutorialSettings {
    static let key = "tutorialMode"
}

/// Every panel control that can carry a tutorial badge.
enum TutorialControl: String, Identifiable, CaseIterable {
    case master, select, presets, algorithm
    case knob1, knob2, knob3, knob4
    case octDown, octUp
    case fx, sel, env, lfo, edit, glo
    case home, save, arp, seq, play, rec

    var id: String { rawValue }

    init(_ b: PanelButton) {
        switch b {
        case .fx: self = .fx
        case .sel: self = .sel
        case .env: self = .env
        case .lfo: self = .lfo
        case .edit: self = .edit
        case .glo: self = .glo
        case .home: self = .home
        case .save: self = .save
        case .arp: self = .arp
        case .seq: self = .seq
        case .play: self = .play
        case .rec: self = .rec
        case .octDown: self = .octDown
        case .octUp: self = .octUp
        }
    }

    static func knob(_ k: Int) -> TutorialControl { [.knob1, .knob2, .knob3, .knob4][k] }

    var knobIndex: Int? {
        switch self {
        case .knob1: return 0
        case .knob2: return 1
        case .knob3: return 2
        case .knob4: return 3
        default: return nil
        }
    }

    /// The name printed on the panel.
    var panelName: String {
        switch self {
        case .master: return "MASTER"
        case .select: return "SELECT"
        case .presets: return "PRESETS"
        case .algorithm: return "ALGORITHM"
        case .knob1, .knob2, .knob3, .knob4: return "KNOB\(knobIndex! + 1)"
        case .octDown: return "OCT−"
        case .octUp: return "OCT+"
        case .play: return "PLAY / STOP"
        default: return rawValue.uppercased()
        }
    }

    enum Kind { case pot, encoder, button }

    var kind: Kind {
        switch self {
        case .master: return .pot
        case .select, .presets, .algorithm, .knob1, .knob2, .knob3, .knob4: return .encoder
        default: return .button
        }
    }
}

/// One tutorial card.
struct TutorialTopic {
    var title: String
    var subtitle: String
    var icon: String
    var summary: String
    var howTo: [String] = []
    var sound: [String] = []
    var notes: [String] = []
    /// What the control does at this moment (live panel state).
    var now: String? = nil
    /// Shown when the installed firmware has no detailed tutorial.
    var firmwareNote: String? = nil
}

// MARK: - Content

@MainActor
enum TutorialContent {

    static func topic(_ c: TutorialControl, model: SynthModel) -> TutorialTopic {
        guard model.firmware.isStock else { return common(c, firmware: model.firmware) }
        var t = stock(c)
        t.now = liveState(c, model: model)
        return t
    }

    // MARK: Firmware-independent behaviour

    private static func subtitle(_ k: TutorialControl.Kind) -> String {
        switch k {
        case .pot: return "Rotary potentiometer"
        case .encoder: return "Endless rotary encoder"
        case .button: return "Backlit rubber button"
        }
    }

    private static func icon(_ k: TutorialControl.Kind) -> String {
        switch k {
        case .pot: return "dial.medium"
        case .encoder: return "dial.low"
        case .button: return "button.horizontal.top.press"
        }
    }

    private static let encoderGesture = [
        "Drag up or right to turn clockwise (increase); down or left to turn anticlockwise (decrease).",
        "Move slowly for single detents. A quick flick accelerates, so a full sweep fits in one swipe.",
        "It is endless: there are no end stops and the pointer only shows that the knob moved, not a value.",
    ]

    /// Gesture lines that still apply when the card goes on to list functions.
    private static var encoderBasics: [String] { Array(encoderGesture.prefix(2)) }

    private static let buttonGesture = [
        "Tap to press. Some functions trigger only on a long press (hold about 0.7 s); you feel a second haptic tick when it fires.",
        "The legend lights up to show state. What each colour means is decided by the firmware.",
    ]

    static func common(_ c: TutorialControl, firmware: Firmware) -> TutorialTopic {
        var t = TutorialTopic(title: c.panelName, subtitle: subtitle(c.kind), icon: icon(c.kind), summary: "")
        switch c.kind {
        case .pot:
            t.summary = "Output volume of the instrument. This control works the same in every firmware."
            t.howTo = [
                "Drag up or right to raise the volume, down or left to lower it.",
                "Unlike the other knobs it has end stops: the pointer shows the actual level (0 at the left stop, 100 at the right).",
                "The screen briefly shows “Volume N” while you turn.",
            ]
            t.sound = ["Scales the final output after all effects. It does not change the timbre, only the loudness."]
            t.notes = ["The level is remembered when you leave the app."]
            return t
        case .encoder:
            t.summary = "A detented encoder whose function is assigned by the installed firmware."
            t.howTo = encoderGesture
        case .button:
            t.summary = "A function button whose meaning is assigned by the installed firmware."
            t.howTo = buttonGesture
            if c == .octDown || c == .octUp {
                t.howTo.append("Press and release are reported separately, so the firmware can use it in combinations (held together with another control).")
            }
        }
        t.firmwareNote = "\(firmware.name) \(firmware.version) is installed. Only the behaviour shared by every firmware is described here. Install FM-1 Stock V15 from the Firmware menu for the full tutorial of this control."
        return t
    }

    // MARK: FM-1 Stock V15

    static func stock(_ c: TutorialControl) -> TutorialTopic {
        let sub = subtitle(c.kind)
        let ic = icon(c.kind)
        switch c {
        case .master:
            var t = common(.master, firmware: .stockV15)
            t.firmwareNote = nil
            return t

        case .select:
            return TutorialTopic(
                title: "SELECT", subtitle: sub, icon: ic,
                summary: "Navigation encoder: moves between the pages of the current menu, and confirms or cancels dialogs.",
                howTo: encoderBasics + [
                    "On menus with several pages (the footer shows e.g. “1/2”), turn to change page. KNOB1–4 then edit the four values of the new page.",
                    "In FX: moves the cursor along the chain of six effects. With SEL lit (effect grabbed), it moves the effect to a new position in the chain.",
                    "In dialogs (Rename, Copy Voice, Reset Patches, SysEx import): turn clockwise to confirm, anticlockwise to cancel.",
                    "While step-recording in SEQ: hold REC and turn to move the record cursor. Holding a chord and turning clockwise stretches it over the following steps (a long, tied note).",
                ],
                sound: [
                    "Turning pages never changes the sound by itself.",
                    "Reordering effects does: e.g. Distortion → Reverb sounds clean in the tail, Reverb → Distortion distorts the whole reverb.",
                ],
                notes: ["In EDIT, each operator remembers the last page you viewed."])

        case .presets:
            return TutorialTopic(
                title: "PRESETS", subtitle: sub, icon: ic,
                summary: "Browses the 128 voice memories (001–128).",
                howTo: encoderBasics + [
                    "Turn to load the next / previous preset. They are organised in four banks of 32: A (001–032), B (033–064), C (065–096), D (097–128).",
                    "The new voice loads immediately, ready to play.",
                ],
                sound: ["Replaces the whole sound: algorithm, the six operators, pitch envelope, LFO, plus that preset’s ENV and effect-chain settings."],
                notes: [
                    "Unsaved edits are discarded when you move to another preset. Hold SAVE first to keep them.",
                    "While SEQ is on, each pattern is bound to a voice, so PRESETS is locked (“Disable SEQ”). Choose the voice on the SEQ page instead.",
                    "Import / export whole banks as .syx from the toolbar menu.",
                ])

        case .algorithm:
            return TutorialTopic(
                title: "ALGORITHM", subtitle: sub, icon: ic,
                summary: "Selects one of the 32 classic 6-operator FM algorithms: how the operators are wired together.",
                howTo: encoderBasics + [
                    "Turn to step through algorithms 1–32. The screen draws the routing diagram and the current feedback amount.",
                    "Hold OCT− or OCT+ and turn ALGORITHM to transpose the keyboard in semitones (−12…0 with OCT−, 0…+12 with OCT+).",
                ],
                sound: [
                    "Operators on the bottom row of the diagram are carriers: you hear them directly. Operators stacked above are modulators: they are not heard, they bend the waveform of the operator below and add harmonics.",
                    "Many carriers (e.g. algorithm 32) = organ-like, additive sounds. Long stacks of modulators (e.g. algorithm 1) = bright, complex, metallic or bell-like tones.",
                    "The same operator settings can sound completely different under another algorithm, because carriers become modulators and vice versa.",
                ],
                notes: [
                    "The feedback loop shown on the diagram is set in EDIT → GLO (Feedback).",
                    "Changes are part of the edit buffer: hold SAVE to keep them.",
                ])

        case .knob1, .knob2, .knob3, .knob4:
            let k = c.knobIndex! + 1
            return TutorialTopic(
                title: "KNOB\(k)", subtitle: sub, icon: ic,
                summary: "Edits parameter \(k) of the four shown on screen. Its job changes with the page you are on.",
                howTo: encoderBasics + [
                    "The screen shows four tiles; KNOB\(k) edits tile \(k). The footer confirms the new value (e.g. “Detune: 3”).",
                    "Each detent changes the value by one step. On/off and list parameters step through their choices.",
                    k == 4 ? "In FX: switches the highlighted effect ON (clockwise) or OFF (anticlockwise)."
                           : "In FX: edits parameter \(k) of the highlighted effect (KNOB4 switches it on/off).",
                ] + dialogUse(k),
                sound: [
                    "Depends on the parameter: e.g. OutLevel on a carrier changes loudness, on a modulator changes brightness; Attack changes how the note starts; CutOff darkens or opens the filter.",
                    "On the HOME screen it has no function.",
                ],
                notes: ["Voice and FX edits live in the edit buffer until you hold SAVE. GLO settings are global and saved automatically."])

        case .octDown, .octUp:
            let up = c == .octUp
            return TutorialTopic(
                title: up ? "OCT+" : "OCT−", subtitle: sub, icon: ic,
                summary: up ? "Shifts the keyboard one octave up." : "Shifts the keyboard one octave down.",
                howTo: [
                    "Tap to move the keyboard \(up ? "up" : "down") an octave. The range is −3…+3 and the screen shows the new octave.",
                    "Press OCT− and OCT+ together to reset both octave and transpose to 0.",
                    "Hold \(up ? "OCT+" : "OCT−") and turn ALGORITHM to transpose in semitones (\(up ? "0…+12" : "−12…0")). The octave is not changed when you use it this way.",
                ],
                sound: [
                    "Changes the pitch of the notes you play by 12 semitones per step. Bright FM sounds get thinner up high and rumble lower down, because the operator ratios stay the same.",
                    "Notes already sounding are cut when the octave changes, to avoid stuck notes.",
                ],
                notes: ["Octave and transpose are global: they apply to every preset and are remembered."])

        case .fx:
            return TutorialTopic(
                title: "FX", subtitle: sub, icon: ic,
                summary: "Opens the effect chain: six effects processed in series, in the order shown on screen.",
                howTo: [
                    "Tap to open the FX screen; tap again (or HOME) to leave. The legend is white while the page is open.",
                    "SELECT moves the cursor between effects. KNOB1–3 edit the highlighted effect, KNOB4 switches it on/off.",
                    "Press SEL to grab the highlighted effect, then turn SELECT to move it in the chain. Press SEL again to drop it.",
                ],
                sound: [
                    "Filter — Type (Low Pass / Band Pass / High Pass), CutOff, Q (resonance).",
                    "Reverb — Type (Room / Hall / Plate), Decay, Mix.",
                    "Delay — Decay (feedback), Rate (time), Mix.",
                    "Distortion — Gain, Tone, Level.",
                    "Chorus and Phaser — Freq (speed), Depth, Mix.",
                    "Order matters: each effect processes the output of the previous one.",
                ],
                notes: ["The chain (on/off, order and values) is stored with each preset. Hold SAVE to keep changes."])

        case .sel:
            return TutorialTopic(
                title: "SEL", subtitle: sub, icon: ic,
                summary: "Grab / release an effect to reorder the FX chain.",
                howTo: [
                    "Open FX, highlight an effect with SELECT and press SEL. The legend lights to show the effect is grabbed.",
                    "Turn SELECT to move it left or right in the chain, then press SEL again to release it.",
                    "Outside the FX page it has no function in this firmware.",
                ],
                sound: ["Changing the order changes the result: a filter before distortion shapes what gets distorted; after it, it tames the distortion’s harshness."])

        case .env:
            return TutorialTopic(
                title: "ENV", subtitle: sub, icon: ic,
                summary: "A global ADSR amplitude envelope applied on top of the voice, for quick shaping without editing six operators.",
                howTo: [
                    "Tap to switch ENV on and open its page. While you are on the page the legend is white; elsewhere it stays blue to show ENV is active.",
                    "Tap again while on the ENV page to switch it off and return HOME.",
                    "KNOB1–4: Attack, Decay, Sustain, Release (0–100%).",
                ],
                sound: [
                    "Attack: fade-in time, about 0–0.8 s. Raise it for pads and swells.",
                    "Decay: time to fall to the sustain level, about 0.1–0.9 s.",
                    "Sustain: level held while the key is down, about 10–80%.",
                    "Release: fade-out after you let go, about 0.1–2 s.",
                    "The operator envelopes still run underneath, so ENV can make a sound shorter or softer, but not longer than the voice itself.",
                ],
                notes: ["ENV on/off and its values are stored with each preset."])

        case .lfo:
            return TutorialTopic(
                title: "LFO", subtitle: sub, icon: ic,
                summary: "The low-frequency oscillator: slow, repeating movement of pitch (vibrato) and/or level (tremolo, wah).",
                howTo: [
                    "Tap to open the LFO pages; tap again to leave. Turn SELECT for page 2.",
                    "Page 1: Wave, Speed, PMD (pitch depth), AMD (amplitude depth).",
                    "Page 2: Delay, Pitch Sens, Key Sync, Osc Sync.",
                ],
                sound: [
                    "Wave: Triangle and Sine = smooth; Saw Up / Down = ramps; Square = trill; S&Hold = random steps.",
                    "PMD and Pitch Sens together set the vibrato amount. With either at 0 there is no pitch movement.",
                    "AMD sets the level movement, heard only on operators whose AmpMod sensitivity (EDIT → OP → Sens) is above 0. On a modulator it gives a wah-like change in brightness.",
                    "Delay fades the LFO in after the key is pressed, a natural-sounding delayed vibrato.",
                    "Key Sync restarts the LFO with each note; Free lets it run continuously.",
                    "Osc Sync restarts the operators’ waveforms at each note, for a consistent attack.",
                ],
                notes: ["LFO settings belong to the voice: hold SAVE to keep them."])

        case .edit:
            return TutorialTopic(
                title: "EDIT", subtitle: sub, icon: ic,
                summary: "The deep voice editor: every parameter of the six operators, the pitch envelope and the voice.",
                howTo: [
                    "Tap to enter EDIT; tap again to leave. While in EDIT the labelled black keys choose what you edit: OP1–OP6, PIT (pitch envelope), GLO (voice settings).",
                    "Hold an OP key for more than ~0.6 s to mute / unmute that operator, handy to hear what each one adds.",
                    "Turn SELECT for the pages. Per operator: Tuning (Detune, FreqCoarse, FreqFine, OutLevel), Envelope rates 1–4, Env levels 1–4, Sens (AmpMod, Key Velo, OscMode), Scaling (L/R Depth, BreakPoint), Curves (L/R Curve, Rate Scale).",
                    "PIT: pitch envelope rates and levels. GLO: Algorithm, Feedback, Osc Sync, Transpose; page 2 has Init Voice, Rename and Copy Voice (turn KNOB clockwise to run).",
                ],
                sound: [
                    "FreqCoarse / FreqFine set the operator’s frequency ratio. Whole-number ratios on modulators give harmonic tones; odd ratios give bells and metal.",
                    "OutLevel: on a carrier, its volume; on a modulator, how much it brightens the sound.",
                    "Envelope rates and levels shape how each operator evolves over time, e.g. a modulator that decays fast gives a bright attack that mellows.",
                    "Key Velo makes the operator respond to velocity; Scaling and Curves change level across the keyboard.",
                ],
                notes: ["All edits stay in the edit buffer until you hold SAVE. Moving to another preset discards them."])

        case .glo:
            return TutorialTopic(
                title: "GLO", subtitle: sub, icon: ic,
                summary: "Global settings for the whole instrument, not stored per preset.",
                howTo: [
                    "Tap to open; tap again to leave. Turn SELECT for page 2.",
                    "Page 1: MIDI Ch (ALL or 1–16), Effect Ch, Bend Up, Bend Down (1–24 semitones).",
                    "Page 2: Reset (restore factory patches per bank, asks for confirmation), Velocity (1–127), Glide Mode (Fingered / Full Time), Glide Val (0–100).",
                ],
                sound: [
                    "Velocity is the fixed velocity used by the on-screen keys. Operators with Key Velo sensitivity get louder and/or brighter at higher values.",
                    "Glide slides the pitch between notes. Fingered: only when notes overlap (legato). Full Time: always.",
                    "Bend Up / Down set the range of a MIDI pitch-bend wheel.",
                ],
                notes: ["Global settings are saved automatically. Reset Patches overwrites the chosen bank: it cannot be undone."])

        case .home:
            return TutorialTopic(
                title: "HOME", subtitle: sub, icon: ic,
                summary: "Returns to the main oscilloscope screen from any menu.",
                howTo: [
                    "Tap to go back HOME. It also cancels an open dialog or a pending SysEx import.",
                    "Hold to open Bluetooth MIDI pairing. The legend stays lit while a Bluetooth MIDI device is connected.",
                ],
                sound: ["None. Leaving a menu keeps every change you made there (ENV, ARP and SEQ keep running in the background)."],
                notes: ["The HOME scope draws the live output waveform, a quick visual check of what the operators are doing."])

        case .save:
            return TutorialTopic(
                title: "SAVE", subtitle: sub, icon: ic,
                summary: "Stores the current sound into the current preset slot.",
                howTo: [
                    "Hold for about 0.7 s to save. A short tap only shows a reminder, to avoid saving by accident.",
                    "During a SysEx import, a tap confirms the import into the chosen bank.",
                ],
                sound: ["None directly. Saving keeps your edits (EDIT, LFO, FX, ENV, algorithm) so the preset sounds like this the next time it is loaded."],
                notes: [
                    "Saving overwrites the slot. To save to another slot, first move there, use EDIT → GLO → Copy Voice, then hold SAVE.",
                    "Restore factory sounds with GLO → Reset.",
                ])

        case .arp:
            return TutorialTopic(
                title: "ARP", subtitle: sub, icon: ic,
                summary: "Arpeggiator: hold a chord and the notes play one after another in rhythm.",
                howTo: [
                    "Tap to switch the arpeggiator on and open its page (legend white; blue while it runs in the background).",
                    "Tap again while on the ARP page to switch it off.",
                    "Page 1: Mode, Octave (1–4), Rate, Tempo (30–300 BPM). Page 2: Gate (20–100%), Swing (50–75%), Latch.",
                ],
                sound: [
                    "Mode: Up, Down, Inclusive and Exclusive (up-and-down, repeating or not the end notes), Random, Order (as played), Repeat.",
                    "Octave repeats the pattern over more octaves. Rate sets the note value relative to Tempo.",
                    "Gate: short values = staccato plucks, 100% = legato.",
                    "Swing delays every second note for a shuffled groove.",
                    "Latch keeps the arpeggio playing after you release the keys.",
                ],
                notes: ["ARP and SEQ cannot run at the same time: switch SEQ off first."])

        case .seq:
            return TutorialTopic(
                title: "SEQ", subtitle: sub, icon: ic,
                summary: "The step sequencer: 16 patterns of up to 16 steps, with chords and tied notes.",
                howTo: [
                    "Tap to switch SEQ on and open its pages (legend white; blue while it runs in the background). Tap again on the SEQ page to switch it off.",
                    "Page 1: Pattern (1–16), Clear, Chain (patterns played in sequence), Step (pattern length).",
                    "Page 2: Voice (preset bound to the pattern), Rate, Tempo, Gate. Page 3: Swing, Sync, Transpose.",
                    "The white keys’ LEDs show the steps. Use PLAY / STOP to run it and REC to enter notes.",
                ],
                sound: [
                    "Voice binds a preset to the pattern, so chaining patterns can switch sounds.",
                    "Gate and Swing work like on the arpeggiator; Transpose shifts the whole pattern ±24 semitones.",
                ],
                notes: [
                    "While SEQ is on PRESETS is locked; choose the sound with Voice.",
                    "ARP and SEQ cannot run at the same time: switch ARP off first.",
                ])

        case .play:
            return TutorialTopic(
                title: "PLAY / STOP", subtitle: sub, icon: ic,
                summary: "Sequencer transport.",
                howTo: [
                    "With SEQ on, tap to start; tap again to stop. The legend is green while playing and red when stopped.",
                    "Hold to panic: stops playback and silences every note (useful for stuck notes).",
                ],
                sound: ["Stopping cuts all sequencer notes immediately."],
                notes: ["If SEQ is off the screen shows “Enable SEQ first”."])

        case .rec:
            return TutorialTopic(
                title: "REC", subtitle: sub, icon: ic,
                summary: "Step recording into the current SEQ pattern.",
                howTo: [
                    "With SEQ on, tap REC (legend red). The record cursor starts at step 1 and blinks on the white keys.",
                    "Play a note or chord: it is written to the cursor step, and the cursor advances when you release all keys.",
                    "Hold REC and turn SELECT to move the cursor without recording (to skip steps or fix one).",
                    "Holding a chord and turning SELECT clockwise ties it over the next steps for long notes.",
                    "While recording, the Rate value on SEQ page 2 applies to the current step only, for mixed note lengths.",
                    "Tap REC again to stop recording.",
                ],
                sound: ["Notes are recorded with the GLO Velocity value and played back with the pattern’s voice."],
                notes: ["Recording a new chord replaces what was on that step. Use Clear on SEQ page 1 to start over."])
        }
    }

    private static func dialogUse(_ k: Int) -> [String] {
        switch k {
        case 1: return ["In Reset Patches: KNOB1–4 pick bank A–D."]
        case 2: return ["In Rename: turn anticlockwise to cancel."]
        case 3: return ["In Rename: chooses the character to add."]
        case 4: return ["In Copy Voice: chooses the source preset."]
        default: return []
        }
    }

    // MARK: Live state (stock)

    static func liveState(_ c: TutorialControl, model: SynthModel) -> String? {
        if let k = c.knobIndex {
            if model.dialog != nil { return "A dialog is open: see the hints in the screen footer." }
            switch model.mode {
            case .home: return "HOME screen: KNOB\(k + 1) has no function here."
            case .fx:
                let kind = FXChain.Kind(rawValue: model.extra.fxOrder[model.fxCursor])!
                if k == 3 { return "Switches \(kind.name) on/off (now \(model.extra.fxOn[kind.rawValue] ? "ON" : "OFF"))." }
                return "Edits \(kind.name) → \(kind.paramNames[k])."
            default:
                let pgs = model.pages
                guard !pgs.isEmpty else { return nil }
                let pg = pgs[min(model.page, pgs.count - 1)]
                guard k < pg.params.count, let p = pg.params[k] else { return "Unused on the “\(pg.title)” page." }
                let v = p.value()
                return "Edits “\(p.name)” on the \(pg.title) page" + (v.isEmpty || p.hideValue ? "." : " (now \(v)).")
            }
        }
        switch c {
        case .select:
            let n = model.pages.count
            if model.mode == .fx { return "Moves the FX cursor\(model.fxGrabbed ? " (effect grabbed: moves it in the chain)" : "")." }
            return n > 1 ? "Page \(min(model.page, n - 1) + 1) of \(n)." : "This screen has a single page."
        case .presets: return String(format: "Preset %03d “%@” loaded.", model.current + 1, model.patch.name)
        case .algorithm: return "Algorithm \(model.patch[.algorithm] + 1), feedback \(model.patch[.feedback])."
        case .octDown, .octUp: return "Octave \(model.globals.octave), transpose \(model.globals.transpose)."
        case .env: return model.extra.envOn ? "ENV is on for this preset." : "ENV is off for this preset."
        case .arp: return model.seq.arpOn ? "The arpeggiator is running." : "The arpeggiator is off."
        case .seq: return model.seq.seqOn ? "SEQ is on, pattern \(model.seq.pattern + 1)." : "SEQ is off."
        case .play: return model.seq.seqOn ? (model.seq.playing ? "Playing." : "Stopped.") : "SEQ is off."
        case .rec: return model.recording ? "Recording, cursor on step \(model.recCursor + 1)." : "Not recording."
        default: return nil
        }
    }
}

// MARK: - Views

/// The small badge drawn next to a control in tutorial mode.
struct TutorialBadge: View {
    let control: TutorialControl
    let size: CGFloat
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(hex: 0xffc83d))
                    .shadow(color: .black.opacity(0.45), radius: size * 0.15, y: size * 0.06)
                Image(systemName: "info")
                    .font(.system(size: size * 0.6, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x2a2000))
            }
            .frame(width: size, height: size)
            .frame(width: max(size, 30), height: max(size, 30))   // comfortable touch target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(control.panelName) tutorial")
        .accessibilityIdentifier("tutorial.\(control.rawValue)")
    }
}

/// The card shown when a badge is tapped.
struct TutorialCardView: View {
    let topic: TutorialTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: topic.icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Color(hex: 0xffc83d))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(topic.title).font(.title2.bold())
                            Text(topic.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text(topic.summary).font(.body)

                    if let now = topic.now {
                        Label(now, systemImage: "dot.radiowaves.left.and.right")
                            .font(.callout)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                            .accessibilityIdentifier("tutorial.now")
                    }
                    section("How to use", "hand.point.up.left", topic.howTo)
                    section("Effect on the sound", "waveform", topic.sound)
                    section("Good to know", "lightbulb", topic.notes)

                    if let fw = topic.firmwareNote {
                        Label(fw, systemImage: "cpu")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)))
                    }
                }
                .padding(24)
            }
            .navigationTitle("Tutorial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    @ViewBuilder private func section(_ title: String, _ icon: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).font(.headline)
                ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(s).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
