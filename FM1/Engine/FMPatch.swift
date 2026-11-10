import Foundation

/// A single 6-operator voice stored in the classic 155-byte "VCED" layout
/// (operator 6 first). Keeping the native byte layout makes SysEx import
/// and export a straight copy.
struct FMPatch: Equatable, Codable {
    static let size = 155
    var data: [UInt8]

    init(data: [UInt8]) {
        precondition(data.count >= FMPatch.size)
        self.data = Array(data.prefix(FMPatch.size))
    }

    // MARK: Offsets
    static func opBase(_ op: Int) -> Int { (6 - op) * 21 }   // op: 1...6

    enum OpParam: Int, CaseIterable {
        case r1 = 0, r2, r3, r4, l1, l2, l3, l4
        case breakPoint, leftDepth, rightDepth, leftCurve, rightCurve
        case rateScaling, ampModSens, velSens, outputLevel
        case oscMode, coarse, fine, detune

        var range: ClosedRange<Int> {
            switch self {
            case .leftCurve, .rightCurve, .ampModSens: return 0...3
            case .rateScaling, .velSens: return 0...7
            case .oscMode: return 0...1
            case .coarse: return 0...31
            case .detune: return 0...14
            default: return 0...99
            }
        }
    }

    enum GlobalParam: Int, CaseIterable {
        case pr1 = 126, pr2, pr3, pr4, pl1, pl2, pl3, pl4
        case algorithm, feedback, oscKeySync
        case lfoSpeed, lfoDelay, lfoPMD, lfoAMD, lfoSync, lfoWave, lfoPMS
        case transpose

        var range: ClosedRange<Int> {
            switch self {
            case .algorithm: return 0...31
            case .feedback, .lfoPMS: return 0...7
            case .oscKeySync, .lfoSync: return 0...1
            case .lfoWave: return 0...5
            case .transpose: return 0...48
            default: return 0...99
            }
        }
    }

    subscript(op op: Int, _ p: OpParam) -> Int {
        get { Int(data[FMPatch.opBase(op) + p.rawValue]) }
        set { data[FMPatch.opBase(op) + p.rawValue] = UInt8(clamping: min(max(newValue, p.range.lowerBound), p.range.upperBound)) }
    }

    subscript(_ p: GlobalParam) -> Int {
        get { Int(data[p.rawValue]) }
        set { data[p.rawValue] = UInt8(clamping: min(max(newValue, p.range.lowerBound), p.range.upperBound)) }
    }

    var name: String {
        get {
            let bytes = data[145..<155].map { $0 >= 32 && $0 < 127 ? $0 : 32 }
            return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        set {
            var b = Array(newValue.utf8.prefix(10)).map { $0 >= 32 && $0 < 127 ? $0 : 32 }
            while b.count < 10 { b.append(32) }
            for i in 0..<10 { data[145 + i] = b[i] }
        }
    }

    // MARK: Ranges

    private static let opMax: [UInt8] = [99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 3, 3, 7, 3, 7, 99, 1, 31, 99, 14]
    private static let globalMax: [UInt8] = [99, 99, 99, 99, 99, 99, 99, 99, 31, 7, 1, 99, 99, 99, 99, 1, 5, 7, 48]
    /// Highest legal value of VCED byte `i` (the FM-1 clamps anything above it).
    static func maxValue(at i: Int) -> UInt8 {
        if i < 126 { return opMax[i % 21] }
        if i < 145 { return globalMax[i - 126] }
        return 127
    }
    /// Clamps every parameter into its DX7 range.
    mutating func sanitize() {
        for i in 0..<FMPatch.size { data[i] = min(data[i], FMPatch.maxValue(at: i)) }
    }
    /// Sets one VCED parameter (SysEx parameter change); ignores unknown indices.
    mutating func setParameter(_ i: Int, _ value: Int) {
        guard i >= 0 && i < FMPatch.size else { return }
        data[i] = min(UInt8(clamping: value), FMPatch.maxValue(at: i))
    }

    // MARK: Builders

    static var initVoice: FMPatch {
        var d = [UInt8](repeating: 0, count: size)
        for op in 1...6 {
            let b = opBase(op)
            d[b + 0] = 99; d[b + 1] = 99; d[b + 2] = 99; d[b + 3] = 99
            d[b + 4] = 99; d[b + 5] = 99; d[b + 6] = 99; d[b + 7] = 0
            d[b + 8] = 39 // break point C3
            d[b + 16] = op == 1 ? 99 : 0
            d[b + 18] = 1 // coarse 1
            d[b + 20] = 7 // detune center
        }
        for i in 126...129 { d[i] = 99 }
        for i in 130...133 { d[i] = 50 }
        d[136] = 1 // osc key sync
        d[137] = 35 // lfo speed
        d[141] = 1
        d[143] = 3
        d[144] = 24 // transpose C3
        var p = FMPatch(data: d)
        p.name = "INIT VOICE"
        return p
    }

    // MARK: SysEx (packed 128-byte VMEM format)

    init(packed v: ArraySlice<UInt8>) {
        let v = Array(v)
        var d = [UInt8](repeating: 0, count: FMPatch.size)
        for i in 0..<6 {   // packed op order is also 6 → 1
            let s = i * 17, o = i * 21
            for k in 0..<11 { d[o + k] = v[s + k] & 0x7F }
            d[o + 11] = v[s + 11] & 0x03                 // left curve
            d[o + 12] = (v[s + 11] >> 2) & 0x03          // right curve
            d[o + 13] = v[s + 12] & 0x07                 // rate scaling
            d[o + 20] = min((v[s + 12] >> 3) & 0x0F, 14) // detune
            d[o + 14] = v[s + 13] & 0x03                 // AMS
            d[o + 15] = (v[s + 13] >> 2) & 0x07          // KVS
            d[o + 16] = min(v[s + 14] & 0x7F, 99)        // output level
            d[o + 17] = v[s + 15] & 0x01                 // osc mode
            d[o + 18] = (v[s + 15] >> 1) & 0x1F          // coarse
            d[o + 19] = min(v[s + 16] & 0x7F, 99)        // fine
        }
        for k in 0..<8 { d[126 + k] = min(v[102 + k] & 0x7F, 99) }
        d[134] = v[110] & 0x1F
        d[135] = v[111] & 0x07
        d[136] = (v[111] >> 3) & 0x01
        d[137] = min(v[112] & 0x7F, 99)
        d[138] = min(v[113] & 0x7F, 99)
        d[139] = min(v[114] & 0x7F, 99)
        d[140] = min(v[115] & 0x7F, 99)
        d[141] = v[116] & 0x01
        d[142] = min((v[116] >> 1) & 0x07, 5)
        d[143] = (v[116] >> 4) & 0x07
        d[144] = min(v[117] & 0x7F, 48)
        for k in 0..<10 { d[145 + k] = v[118 + k] & 0x7F }
        // sanitize ranges
        for op in 0..<6 {
            let o = op * 21
            for k in 0..<11 { d[o + k] = min(d[o + k], 99) }
        }
        self.data = d
    }

    var packed: [UInt8] {
        var v = [UInt8](repeating: 0, count: 128)
        let d = data
        for i in 0..<6 {
            let s = i * 17, o = i * 21
            for k in 0..<11 { v[s + k] = d[o + k] }
            v[s + 11] = (d[o + 12] << 2) | d[o + 11]
            v[s + 12] = (d[o + 20] << 3) | d[o + 13]
            v[s + 13] = (d[o + 15] << 2) | d[o + 14]
            v[s + 14] = d[o + 16]
            v[s + 15] = (d[o + 18] << 1) | d[o + 17]
            v[s + 16] = d[o + 19]
        }
        for k in 0..<8 { v[102 + k] = d[126 + k] }
        v[110] = d[134]
        v[111] = (d[136] << 3) | d[135]
        v[112] = d[137]; v[113] = d[138]; v[114] = d[139]; v[115] = d[140]
        v[116] = (d[143] << 4) | (d[142] << 1) | d[141]
        v[117] = d[144]
        for k in 0..<10 { v[118 + k] = d[145 + k] }
        return v
    }

    /// Parses a 32-voice bulk dump (4104 bytes) or a single-voice dump (163 bytes).
    static func parseSysEx(_ bytes: [UInt8]) -> [FMPatch] {
        var result: [FMPatch] = []
        var i = 0
        while i < bytes.count {
            guard bytes[i] == 0xF0 else { i += 1; continue }
            // find the end of this message
            guard let end = bytes[i...].firstIndex(of: 0xF7) else { break }
            let msg = Array(bytes[i...end])
            if msg.count >= 6, msg[1] == 0x43 {
                let format = msg[3]
                if format == 0x09, msg.count >= 6 + 4096 {
                    for v in 0..<32 {
                        let s = 6 + v * 128
                        result.append(FMPatch(packed: msg[s..<(s + 128)]))
                    }
                } else if format == 0x00, msg.count >= 6 + 155 {
                    var single = FMPatch(data: Array(msg[6..<(6 + 155)]).map { $0 & 0x7F })
                    single.sanitize()
                    result.append(single)
                }
            }
            i = end + 1
        }
        // headerless raw 4096-byte bank
        if result.isEmpty, bytes.count == 4096 {
            for v in 0..<32 { result.append(FMPatch(packed: bytes[(v * 128)..<(v * 128 + 128)])) }
        }
        return result
    }

    /// DX7 voice parameter change `F0 43 1n pp qq vv F7` → (VCED index pp·128 + qq, value).
    static func parseParameterChange(_ msg: [UInt8]) -> (Int, Int)? {
        guard msg.count == 7, msg[0] == 0xF0, msg[1] == 0x43, msg[2] & 0xF0 == 0x10, msg[3] < 4, msg[6] == 0xF7 else { return nil }
        return (Int(msg[3] & 0x01) * 128 + Int(msg[4] & 0x7F), Int(msg[5] & 0x7F))
    }

    static func bankSysEx(_ patches: [FMPatch]) -> [UInt8] {
        var p = Array(patches.prefix(32))
        while p.count < 32 { p.append(.initVoice) }
        var body: [UInt8] = []
        for v in p { body += v.packed }
        let sum = body.reduce(0) { ($0 + Int($1)) & 0x7F }
        let checksum = UInt8((128 - sum) & 0x7F)
        return [0xF0, 0x43, 0x00, 0x09, 0x20, 0x00] + body + [checksum, 0xF7]
    }

    static func singleSysEx(_ patch: FMPatch) -> [UInt8] {
        let body = patch.data
        let sum = body.reduce(0) { ($0 + Int($1)) & 0x7F }
        return [0xF0, 0x43, 0x00, 0x00, 0x01, 0x1B] + body + [UInt8((128 - sum) & 0x7F), 0xF7]
    }
}
