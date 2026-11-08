import SwiftUI
import UniformTypeIdentifiers
import CoreAudioKit

@main
struct FM1App: App {
    @StateObject private var model = SynthModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onChange(of: phase) { _, p in
                    if p == .active { model.audio.start() }
                    if p == .background { model.persistGlobalsNow() }
                }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: SynthModel
    @State private var importing = false
    @State private var exporting = false
    @State private var exportBank = 0
    @State private var showHelp = false
    /// Full-screen mode: no case, no toolbar — the iPad is the device.
    @AppStorage("fullScreenPanel") private var fullScreen = false

    var body: some View {
        GeometryReader { geo in
            if fullScreen {
                ZStack(alignment: .topTrailing) {
                    PanelView(model: model, width: geo.size.width, height: geo.size.height, framed: false)
                    optionsMenu {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(model.colorway.silkscreen.opacity(0.45))
                            .frame(width: 44, height: 44)
                    }
                    .padding(.top, 6)
                    .padding(.trailing, 8)
                }
            } else {
                let avail = CGSize(width: geo.size.width - 40, height: geo.size.height - 90)
                let w = min(avail.width, avail.height * PanelView.aspect)
                ZStack {
                    backdrop
                    VStack(spacing: 0) {
                        toolbar
                            .frame(height: 54)
                            .padding(.horizontal, 24)
                        Spacer(minLength: 0)
                        PanelView(model: model, width: w)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 18)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: fullScreen)
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "syx") ?? .data, .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let d = try? Data(contentsOf: url) { model.importFile(d) }
            }
        }
        .fileExporter(isPresented: $exporting, document: SysExDocument(data: model.exportBank(exportBank)),
                      contentType: UTType(filenameExtension: "syx") ?? .data,
                      defaultFilename: "FM1_bank_\(["A", "B", "C", "D"][exportBank]).syx") { _ in }
        .sheet(isPresented: $model.showBluetooth) {
            BluetoothMIDIView().ignoresSafeArea()
        }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2b2d31), Color(hex: 0x141517)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .center, startRadius: 10, endRadius: 900)
        }
        .ignoresSafeArea()
    }

    private var toolbar: some View {
        HStack(spacing: 18) {
            Text("FM POCKET")
                .font(PanelFont.legend(15))
                .foregroundStyle(.white.opacity(0.75))
            Text("6-OP FM SYNTHESIZER")
                .font(PanelFont.silkscreen(11))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            HStack(spacing: 10) {
                ForEach(Colorway.all) { c in
                    Circle()
                        .fill(LinearGradient(colors: [c.body, c.swatch], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white.opacity(model.globals.colorway == c.id ? 0.95 : 0.2), lineWidth: 2))
                        .onTapGesture { model.globals.colorway = c.id; model.persistGlobalsNow() }
                        .accessibilityLabel(c.name)
                }
            }
            Divider().frame(height: 24).overlay(Color.white.opacity(0.2))
            Button { fullScreen = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Full screen")
            optionsMenu {
                Image(systemName: "tray.and.arrow.down").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 36, height: 36)
            }
            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle").font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 36, height: 36)
            }
        }
    }

    /// Shared menu (toolbar + full-screen corner button).
    private func optionsMenu<L: View>(@ViewBuilder label: () -> L) -> some View {
        Menu {
            if fullScreen {
                Button { fullScreen = false } label: { Label("Show Device Frame", systemImage: "arrow.down.right.and.arrow.up.left") }
                Menu("Colour") {
                    ForEach(Colorway.all) { c in
                        Button(c.name) { model.globals.colorway = c.id; model.persistGlobalsNow() }
                    }
                }
                Button { showHelp = true } label: { Label("Controls", systemImage: "questionmark.circle") }
                Divider()
            } else {
                Button { fullScreen = true } label: { Label("Full Screen (iPad as device)", systemImage: "arrow.up.left.and.arrow.down.right") }
                Divider()
            }
            Button { importing = true } label: { Label("Import SysEx (.syx)…", systemImage: "square.and.arrow.down") }
                Menu("Export Bank") {
                    ForEach(0..<4, id: \.self) { b in
                        Button("Bank \(["A", "B", "C", "D"][b]) (\(String(format: "%03d–%03d", b * 32 + 1, b * 32 + 32)))") {
                            exportBank = b; exporting = true
                        }
                    }
                }
                Divider()
                Button { model.showBluetooth = true } label: { Label("Bluetooth MIDI…", systemImage: "dot.radiowaves.left.and.right") }
                Button(role: .destructive) { model.engine.panic() } label: { Label("Panic (all notes off)", systemImage: "exclamationmark.octagon") }
        } label: { label() }
    }
}

struct SysExDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "syx") ?? .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Apple's Bluetooth LE MIDI pairing UI.
struct BluetoothMIDIView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = CABTMIDICentralViewController()
        vc.navigationItem.title = "Bluetooth MIDI"
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let rows: [(String, String)] = [
        ("MASTER", "Output volume"),
        ("SELECT", "Change page · move FX cursor · confirm dialogs · (SEQ rec) extend long notes; hold REC + turn to move step"),
        ("PRESETS", "Load presets 001–128 (bank A–D)"),
        ("ALGORITHM", "Algorithm 1–32 · hold OCT− / OCT+ and turn = transpose"),
        ("KNOB1–4", "The four parameters shown on screen"),
        ("OCT− / OCT+", "Octave −3…+3 · press both = reset octave & transpose"),
        ("FX", "Effect chain: SELECT moves, SEL grabs to reorder, K1–K3 params, K4 on/off"),
        ("ENV", "Global ADSR on/off and edit"),
        ("LFO", "LFO pages"),
        ("EDIT", "Operator editor: black keys select OP1–6, PIT, GLO (voice), MONO / POLY · hold OP key = mute"),
        ("GLO", "Global settings: MIDI channels, bend range, reset bank, velocity, glide"),
        ("HOME", "Back to oscilloscope · hold = Bluetooth MIDI"),
        ("SAVE", "Hold to save the current preset"),
        ("ARP / SEQ", "Arpeggiator / 16-step sequencer (white keys show steps)"),
        ("PLAY/STOP · REC", "Sequencer transport and step recording · hold PLAY = panic"),
    ]
    var body: some View {
        NavigationStack {
            List(rows, id: \.0) { r in
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.0).font(.headline)
                    Text(r.1).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Controls")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
