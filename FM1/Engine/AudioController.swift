import AVFoundation
import CoreMIDI
import os

/// Hosts the FM engine and FX chain in AVAudioEngine and listens to CoreMIDI / Bluetooth MIDI.
final class AudioController {
    let engine = FMEngine()
    private let avEngine = AVAudioEngine()
    private var source: AVAudioSourceNode!
    let fx: FXChain
    let drums: DrumKit
    let groove: GrooveSeq

    private var midiClient = MIDIClientRef()
    private var midiIn = MIDIPortRef()
    private var sysexBuffer: [UInt8] = []
    /// Called on the main thread when a SysEx voice dump arrives over MIDI.
    var onSysExPatches: (([FMPatch]) -> Void)?
    /// Called on the main thread for incoming notes (for keyboard highlighting).
    var onMIDINote: ((Int, Bool) -> Void)?
    var midiChannel: Int = 0   // 0 = omni, 1...16
    var fxChannel: Int = 2
    var onProgramChange: ((Int) -> Void)?
    /// DX7 SysEx voice parameter change (VCED index, value), main thread.
    var onParameterChange: ((Int, Int) -> Void)?
    var onFXControl: ((Int, Int) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    /// While a script firmware runs, channel notes, CCs and program changes go to it (main thread,
    /// status byte with channel, data 1, data 2) instead of to the FM engine. Off for the stock firmware.
    var onPackageMIDI: ((UInt8, Int, Int) -> Void)?
    private let packageRoute = OSAllocatedUnfairLock(initialState: false)
    var routeMIDIToPackage: Bool {
        get { packageRoute.withLock { $0 } }
        set { packageRoute.withLock { $0 = newValue } }
    }

    init() {
        AudioController.configureSession()
        let format = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate > 0 ? AVAudioSession.sharedInstance().sampleRate : 48000, channels: 2)!
        engine.sampleRate = Float(format.sampleRate)
        fx = FXChain(sampleRate: Float(format.sampleRate))
        drums = DrumKit(sampleRate: Float(format.sampleRate))
        groove = GrooveSeq(enginePatch: engine.patch, kit: drums)
        engine.drums = drums
        engine.groove = groove
        let fm = engine
        let chain = fx
        source = AVAudioSourceNode(format: format) { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            fm.render(frames: Int(frameCount), out: left)
            if buffers.count > 1, let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                chain.process(left: left, right: right, frames: Int(frameCount))
            }
            return noErr
        }
        avEngine.attach(source)
        avEngine.connect(source, to: avEngine.mainMixerNode, format: format)
        start()
        setupMIDI()
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.restart()
        }
        // AVAudioEngine stops itself when the output configuration changes
        // (route / sample rate / device). Restart it, or the app goes silent.
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: avEngine, queue: .main) { [weak self] _ in
            self?.restart()
        }
        nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            AudioController.configureSession()
            self?.restart()
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.ensureRunning() }
        }
    }

    private static func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setPreferredIOBufferDuration(0.005)
        try? s.setActive(true)
    }

    func start() {
        if !avEngine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            avEngine.prepare()
            do { try avEngine.start() } catch { print("AudioController: start failed \(error)") }
        }
    }

    /// Stop + start (used after configuration changes).
    func restart() {
        avEngine.stop()
        engine.allNotesOff()
        start()
    }

    var isRunning: Bool { avEngine.isRunning }

    /// Watchdog: restart if the engine has silently stopped.
    func ensureRunning() {
        if !avEngine.isRunning { start() }
    }


    // MARK: MIDI

    private func setupMIDI() {
        MIDIClientCreateWithBlock("FM1 Client" as CFString, &midiClient) { [weak self] _ in
            self?.connectSources()
        }
        MIDIInputPortCreateWithProtocol(midiClient, "FM1 In" as CFString, ._1_0, &midiIn) { [weak self] list, _ in
            self?.receive(list)
        }
        connectSources()
    }

    private func connectSources() {
        var external = false
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            MIDIPortConnectSource(midiIn, src, nil)
            var offline: Int32 = 0
            MIDIObjectGetIntegerProperty(src, kMIDIPropertyOffline, &offline)
            if offline == 0 { external = true }
        }
        DispatchQueue.main.async { self.onConnectionChange?(external) }
    }

    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        for packet in list.unsafeSequence() {
            let words = MIDIEventPacket.WordCollection(packet)
            for w in words {
                let type = (w >> 28) & 0xF
                if type == 0x2 { // MIDI 1.0 channel voice
                    let status = UInt8((w >> 16) & 0xFF)
                    let d1 = Int((w >> 8) & 0x7F), d2 = Int(w & 0x7F)
                    let ch = Int(status & 0x0F) + 1
                    if status & 0xF0 == 0xB0 && ch == fxChannel {
                        let cc = d1, val = d2
                        DispatchQueue.main.async { self.onFXControl?(cc, val) }
                        continue
                    }
                    if midiChannel != 0 && ch != midiChannel { continue }
                    if [0x80, 0x90, 0xB0, 0xC0].contains(status & 0xF0) && routeMIDIToPackage {
                        DispatchQueue.main.async { self.onPackageMIDI?(status, d1, d2) }
                        continue
                    }
                    switch status & 0xF0 {
                    case 0x90 where d2 > 0:
                        engine.noteOn(d1, velocity: d2)
                        DispatchQueue.main.async { self.onMIDINote?(d1, true) }
                    case 0x80, 0x90:
                        engine.noteOff(d1)
                        DispatchQueue.main.async { self.onMIDINote?(d1, false) }
                    case 0xB0: engine.controlChange(d1, d2)
                    case 0xC0: DispatchQueue.main.async { self.onProgramChange?(d1) }
                    case 0xD0: engine.post(.aftertouch(UInt8(d1)))
                    case 0xE0: engine.pitchBend(d1 | (d2 << 7))
                    default: break
                    }
                } else if type == 0x3 { // 64-bit SysEx7 — handled as pairs below
                    break
                }
            }
            // SysEx7 data: messages are spread over 2-word UMPs
            var idx = 0
            let arr = Array(words)
            while idx + 1 < arr.count {
                let w0 = arr[idx], w1 = arr[idx + 1]
                if (w0 >> 28) & 0xF == 0x3 {
                    let status = (w0 >> 20) & 0xF
                    let n = Int((w0 >> 16) & 0xF)
                    let bytes: [UInt8] = [UInt8((w0 >> 8) & 0x7F), UInt8(w0 & 0x7F), UInt8((w1 >> 24) & 0x7F), UInt8((w1 >> 16) & 0x7F), UInt8((w1 >> 8) & 0x7F), UInt8(w1 & 0x7F)]
                    if status == 0 || status == 1 { sysexBuffer = [0xF0] }
                    sysexBuffer += bytes.prefix(n)
                    if status == 0 || status == 3 {
                        sysexBuffer.append(0xF7)
                        if let (index, value) = FMPatch.parseParameterChange(sysexBuffer) {
                            DispatchQueue.main.async { self.onParameterChange?(index, value) }
                        } else {
                            let patches = FMPatch.parseSysEx(sysexBuffer)
                            if !patches.isEmpty { DispatchQueue.main.async { self.onSysExPatches?(patches) } }
                        }
                        sysexBuffer = []
                    }
                    idx += 2
                } else {
                    idx += 1
                }
            }
        }
    }
}
