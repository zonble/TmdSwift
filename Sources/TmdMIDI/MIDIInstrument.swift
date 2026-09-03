import Foundation

/// A General MIDI instrument selected from a TMD paragraph name.
public enum MIDIInstrument: Equatable {
    case piano
    case guitar
    case bass
    case strings
    case choir
    case percussion
    case unknown

    /// Resolves a human-readable TMD instrument name.
    public static func resolve(_ name: String) -> MIDIInstrument {
        let name = name.lowercased()
        let aliases: [(MIDIInstrument, [String])] = [
            (.percussion, ["drum", "groove", "percussion"]),
            (.piano, ["piano", "keyboard"]),
            (.guitar, ["guitar"]),
            (.bass, ["bass"]),
            (.strings, ["string", "strings"]),
            (.choir, ["choir", "chorus", "vocal", "voice"])
        ]
        return aliases.first { _, terms in terms.contains { name.contains($0) } }?.0 ?? .unknown
    }

    /// The zero-based General MIDI program. Unknown instruments safely use piano.
    public var program: UInt8 {
        switch self {
        case .piano, .unknown: 0
        case .guitar: 25
        case .bass: 33
        case .strings: 48
        case .choir: 52
        case .percussion: 0
        }
    }

    /// Whether the instrument must use General MIDI channel 10.
    public var isPercussion: Bool {
        self == .percussion
    }
}
