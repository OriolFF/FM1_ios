import Foundation

/// The firmwares this app can "flash". Each one is a behaviour profile of the
/// same panel — like installing a different .fwsc on the real FM-1.
enum Firmware: String, CaseIterable, Identifiable, Codable {
    case stockV15
    case groove

    var id: String { rawValue }

    var name: String {
        switch self {
        case .stockV15: return "FM-1 Stock"
        case .groove: return "FM Pocket Groove"
        }
    }

    var version: String {
        switch self {
        case .stockV15: return "V15"
        case .groove: return "G1.0"
        }
    }

    var bootTitle: String {
        switch self {
        case .stockV15: return "FM-1"
        case .groove: return "GROOVE"
        }
    }

    var summary: String {
        switch self {
        case .stockV15:
            return "The original M-VAVE firmware (V15): 6-op FM, 128 voices, FX chain, ENV, arpeggiator and the 16 × 16-step sequencer. Restores the factory behaviour."
        case .groove:
            return "Groovebox port: FM synth track + 11-lane 808-style drum track, 8 patterns × 64 steps, chance / FILL, ratchets, ties, parameter locks, Euclid & density generators, perform layer (hold GLO)."
        }
    }

    var credits: String {
        switch self {
        case .stockV15:
            return "Behaviour from M-VAVE's V15 manual and release notes. Factory voices from M-VAVE's Apache-2.0 recovery image."
        case .groove:
            return "Panel layout inspired by community firmwares (Felucca, SLOOP, FM-1+VA) and M-VAVE's FM1 Open. Original code."
        }
    }

    var isStock: Bool { self == .stockV15 }
}
