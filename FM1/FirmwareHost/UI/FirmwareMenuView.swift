import SwiftUI
import UniformTypeIdentifiers

/// Firmware updater: pick which firmware the panel runs, and install new firmware
/// packages from a URL or the Files app (no rebuild of the app needed).
struct FirmwareView: View {
    @ObservedObject var model: SynthModel
    @ObservedObject private var catalog = FirmwareCatalog.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Firmware? = nil
    @State private var urlText = Self.defaultURL
    @State private var importing = false
    @State private var importingSamples = false
    @State private var sampleMessage: String? = nil
    @State private var sampleCount = 0
    @State private var busy = false
    @State private var message: String? = nil

    var body: some View {
        let choice = selected ?? model.firmware
        NavigationStack {
            List {
                Section {
                    ForEach(catalog.all) { fw in
                        row(fw, choice: choice)
                            .swipeActions {
                                if fw.origin == .installed {
                                    Button(role: .destructive) { uninstall(fw) } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                    }
                } footer: {
                    Text("Switching firmware stops playback and reboots the panel. Presets, sequencer patterns and global settings are kept. Choose FM-1 Stock V15 to restore the original firmware.")
                }
                if choice.manifest.engine?.userSamples == true {
                    Section {
                        Button { importingSamples = true } label: { Label("Add samples…", systemImage: "waveform.badge.plus") }
                        if sampleCount > 0 {
                            Button(role: .destructive) {
                                FirmwareCatalog.removeUserSamples(for: choice.id)
                                samplesChanged(choice, "Removed the user samples.")
                            } label: { Label("Remove user samples", systemImage: "trash") }
                        }
                        if let sampleMessage { Text(sampleMessage).font(.footnote).foregroundStyle(.secondary) }
                    } header: {
                        Text("Samples for \(choice.name)")
                    } footer: {
                        Text("\(sampleCount) of your own WAV files. They appear as extra sounds of the SAMPLE engine (root note C4).")
                    }
                    .fileImporter(isPresented: $importingSamples, allowedContentTypes: [.wav, .audio], allowsMultipleSelection: true) { result in
                        guard case .success(let urls) = result else { return }
                        let r = FirmwareCatalog.importUserSamples(urls, to: choice.id)
                        samplesChanged(choice, r.error.map { "Added \(r.added). \($0)" } ?? "Added \(r.added) sample\(r.added == 1 ? "" : "s").")
                    }
                    .onAppear { sampleCount = FirmwareCatalog.userSamples(for: choice.id).count }
                    .onChange(of: choice.id) { _, id in sampleCount = FirmwareCatalog.userSamples(for: id).count; sampleMessage = nil }
                }
                Section {
                    NavigationLink {
                        urlPage
                    } label: { Label("Install from URL…", systemImage: "link.badge.plus") }
                        .disabled(busy)
                    Button { importing = true } label: { Label("Install from Files…", systemImage: "folder.badge.plus") }
                        .disabled(busy)
                    if busy { HStack { ProgressView(); Text("Installing…").foregroundStyle(.secondary) } }
                    if let message { Text(message).font(.footnote).foregroundStyle(message.hasPrefix("Installed") ? Color.green : Color.red) }
                } header: {
                    Text("Firmware packages")
                } footer: {
                    Text("A package is a .fm1fw file (or a manifest.json URL): sound engine settings, sequencer layout and a script for screens, keys and knobs, run by this app's built-in engine. Packages cannot run native code.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let fw = choice
                    dismiss()
                    // start flashing once the sheet has gone
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        model.installFirmware(fw)
                    }
                } label: {
                    Text(choice.id == model.firmware.id && choice.version == model.firmware.version
                         ? "\(choice.name) is installed" : "Install \(choice.name) \(choice.version)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(choice == model.firmware)
                .padding()
                .background(.bar)
            }
            .navigationTitle("Firmware")
            .toolbar { Button("Cancel") { dismiss() } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "fm1fw") ?? .json, .json, .data], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { installURL(url.absoluteString, file: url) }
            }
        }
    }

    /// Refreshes the count and reboots the firmware if it is the one running, so it loads the samples.
    private func samplesChanged(_ fw: Firmware, _ msg: String) {
        sampleCount = FirmwareCatalog.userSamples(for: fw.id).count
        sampleMessage = msg
        if model.firmware.id == fw.id && model.packageHost != nil { model.startPackage(model.firmware) }
    }

    private var urlPage: some View {
        Form {
            Section {
                TextField("https://…/package.fm1fw", text: $urlText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .lineLimit(1...4)
                    .accessibilityIdentifier("PackageURL")
                Button { installURL(urlText) } label: {
                    HStack { Text("Download & Install"); if busy { Spacer(); ProgressView() } }
                }
                .disabled(busy || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("A .fm1fw package, or the manifest.json of a package folder whose scripts sit next to it.")
            }
            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(message.hasPrefix("Installed") ? Color.green : Color.red) }
            }
        }
        .navigationTitle("Install from URL")
    }

    /// DEBUG/UI tests may pre-fill the URL field (FM1_TEST_PACKAGE_URL).
    private static var defaultURL: String {
        #if DEBUG
        if let u = ProcessInfo.processInfo.environment["FM1_TEST_PACKAGE_URL"] { return u }
        #endif
        return ""
    }

    private func row(_ fw: Firmware, choice: Firmware) -> some View {
        Button { selected = fw } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: fw.id == choice.id ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundStyle(fw.id == choice.id ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fw.name).font(.headline)
                        Text(fw.version).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                        if fw.isStock { badge("ORIGINAL", .blue) }
                        if fw.isScript { badge(fw.origin == .installed ? "DOWNLOADED" : "PACKAGE", .purple) }
                        if fw.id == model.firmware.id { badge("INSTALLED", .green) }
                    }
                    Text(fw.summary).font(.subheadline).foregroundStyle(.primary.opacity(0.85))
                    if !fw.credits.isEmpty { Text(fw.credits).font(.caption).foregroundStyle(.secondary) }
                    if let l = fw.manifest.license, !l.isEmpty { Text("Licence: \(l)").font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func installURL(_ text: String, file: URL? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = file ?? URL(string: trimmed), url.scheme != nil else { message = "Not a valid URL"; return }
        busy = true; message = nil
        Task { @MainActor in
            do {
                let fw = try await catalog.install(from: url)
                selected = fw
                message = "Installed \(fw.name) \(fw.version). Tap Install to flash it."
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }

    private func uninstall(_ fw: Firmware) {
        if fw.id == model.firmware.id { message = "Switch to another firmware before deleting this one"; return }
        catalog.uninstall(fw)
        if selected?.id == fw.id { selected = nil }
    }

    private func badge(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(c.opacity(0.25)))
    }
}
