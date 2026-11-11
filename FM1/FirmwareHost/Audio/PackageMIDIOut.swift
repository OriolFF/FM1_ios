import AVFoundation
import CoreMIDI
import os

/// MIDI output for package firmwares (`"type": "midi"` instruments). The audio thread queues
/// 3-byte messages without blocking; a sender thread drains them every millisecond and sends
/// them to every MIDI destination and to the app's own virtual source ("FM Pocket"), stamped
/// with the time the audio rendered alongside them will be heard.
final class PackageMIDIOut: @unchecked Sendable {
    static let shared = PackageMIDIOut()
    /// The app's virtual source, so the app's MIDI input can skip it (no feedback loop).
    nonisolated(unsafe) static var ownSource: MIDIEndpointRef = 0

    private struct Msg { var time: UInt64 = 0; var b0: UInt8 = 0; var b1: UInt8 = 0; var b2: UInt8 = 0 }
    private struct Ring {
        static let cap = 1024
        var items = [Msg](repeating: Msg(), count: Ring.cap)
        var head = 0, count = 0
    }
    private let ring = OSAllocatedUnfairLock(initialState: Ring())
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var source = MIDIEndpointRef()
    private var started = false
    private var latencyTicks: UInt64 = 0
    private let startLock = NSLock()

    /// Sets up CoreMIDI on first use (main thread, when a package with MIDI tracks starts).
    func start() {
        startLock.lock(); defer { startLock.unlock() }
        guard !started else { return }
        started = true
        MIDIClientCreateWithBlock("FM Pocket Out" as CFString, &client) { _ in }
        MIDIOutputPortCreate(client, "FM Pocket Out" as CFString, &port)
        if MIDISourceCreateWithProtocol(client, "FM Pocket" as CFString, ._1_0, &source) == noErr {
            PackageMIDIOut.ownSource = source
        }
        // audio is rendered ahead of the speaker by the output latency and one IO buffer
        #if os(iOS)
        let s = AVAudioSession.sharedInstance()
        let seconds = s.outputLatency + s.ioBufferDuration
        #else
        let seconds = 0.0
        #endif
        var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
        latencyTicks = UInt64(seconds * 1e9 * Double(tb.denom) / Double(tb.numer))
        let t = Thread { [unowned self] in self.loop() }
        t.name = "FM Pocket MIDI out"
        t.qualityOfService = .userInteractive
        t.start()
    }

    /// Audio thread: never blocks; drops the message if the sender holds the lock or the ring is full.
    @inline(__always) func send(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8) {
        let now = mach_absolute_time()
        _ = ring.withLockIfAvailableUnchecked { r in
            guard r.count < Ring.cap else { return }
            r.items[(r.head + r.count) % Ring.cap] = Msg(time: now, b0: b0, b1: b1, b2: b2)
            r.count += 1
        }
    }

    private func loop() {
        var batch = [Msg](repeating: Msg(), count: Ring.cap)
        let listSize = 64 * 1024
        let raw = UnsafeMutableRawPointer.allocate(byteCount: listSize, alignment: 8)
        while true {
            var n = 0
            ring.withLock { r in
                while r.count > 0 { batch[n] = r.items[r.head]; n += 1; r.head = (r.head + 1) % Ring.cap; r.count -= 1 }
            }
            if n > 0 {
                let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
                var packet = MIDIEventListInit(list, ._1_0)
                for k in 0..<n {
                    let m = batch[k]
                    var word: UInt32 = 0x2000_0000 | UInt32(m.b0) << 16 | UInt32(m.b1) << 8 | UInt32(m.b2)
                    packet = MIDIEventListAdd(list, listSize, packet, m.time &+ latencyTicks, 1, &word)
                }
                for d in 0..<MIDIGetNumberOfDestinations() { MIDISendEventList(port, MIDIGetDestination(d), list) }
                if source != 0 { MIDIReceivedEventList(source, list) }
            }
            usleep(1000)
        }
    }
}

/// `"type": "midi"`: a track that plays an external instrument over MIDI instead of a sound.
/// Parameter `channel` (0–15 = channel 1–16). Notes, the arpeggiator and the sequencer drive it
/// like any synth; it renders no audio.
final class MIDIOutInstrument: PkgInstrument {
    let kind = "midi"
    static let table = [PkgParam("channel", 0, count: 16)]
    var paramTable: [PkgParam] { MIDIOutInstrument.table }
    private var channel: Int
    private var lockedChannel = -1
    private var noteChannel = [Int8](repeating: -1, count: 128)   // channel a sounding note was sent on
    private var sounding = 0
    var meter: Float { sounding > 0 ? 0.6 : 0 }

    init(channel: Int) {
        self.channel = min(max(channel, 0), 15)
        PackageMIDIOut.shared.start()
    }
    func setParam(_ i: Int, _ v: Float) { if i == 0 { channel = min(max(Int(v.rounded()), 0), 15) } }
    func param(_ i: Int) -> Float { i == 0 ? Float(channel) : 0 }
    private var ch: Int { lockedChannel >= 0 ? lockedChannel : channel }

    func noteOn(_ note: Int, vel: Int, slide: Bool, accent: Bool) {
        guard note >= 0 && note < 128 else { return }
        if noteChannel[note] >= 0 { noteOff(note) }
        let c = ch
        PackageMIDIOut.shared.send(UInt8(0x90 | c), UInt8(note), UInt8(clamping: max(1, accent ? min(127, vel + 20) : vel)))
        noteChannel[note] = Int8(c); sounding += 1
    }
    func noteOff(_ note: Int) {
        guard note >= 0 && note < 128, noteChannel[note] >= 0 else { return }
        PackageMIDIOut.shared.send(UInt8(0x80 | Int(noteChannel[note])), UInt8(note), 0)
        noteChannel[note] = -1; sounding = max(0, sounding - 1)
    }
    func hit(_ lane: Int, vel: Int) {}
    func allOff() { for n in 0..<128 where noteChannel[n] >= 0 { noteOff(n) } }
    func applyLock(_ i: Int, _ v: UInt8) { if i == 0 { lockedChannel = Int(v) & 15 } }
    func clearLocks() { lockedChannel = -1 }
    func render(frames: Int, out: UnsafeMutablePointer<Float>) {}
}
