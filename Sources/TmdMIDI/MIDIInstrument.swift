import Foundation

/// A General MIDI instrument selected from a TMD paragraph name.
public enum MIDIInstrument: Equatable {
    case piano
    case electricPiano
    case organ
    case guitar
    case distortionGuitar
    case overdriveGuitar
    case cleanGuitar
    case nylonGuitar
    case bass
    case strings
    case violin
    case cello
    case choir
    case trumpet
    case brass
    case sax
    case flute
    case pad
    case percussion
    case unknown

    /// Resolves a human-readable TMD instrument name.
    public static func resolve(_ name: String) -> MIDIInstrument {
        let name = name.lowercased()
        let aliases: [(MIDIInstrument, [String])] = [
            (.percussion, ["drum", "groove", "percussion"]),
            (.distortionGuitar, ["distortion", "dist", "fuzz", "heavy", "metal"]),
            (.overdriveGuitar, ["overdrive", "od", "rockguitar", "electricguitar", "electric-guitar"]),
            (.cleanGuitar, ["cleanguitar", "electricclean"]),
            (.flute, ["flute", "pipe", "whistle"]),
            (.violin, ["violin", "fiddle"]),
            (.cello, ["cello"]),
            (.trumpet, ["trumpet", "cornet"]),
            (.brass, ["brass", "horn", "trombone", "tuba"]),
            (.sax, ["sax", "saxophone"]),
            (.organ, ["organ", "b3"]),
            (.electricPiano, ["ep", "electricpiano", "rhodes", "wurlitzer"]),
            (.nylonGuitar, ["nylon", "acousticguitar"]),
            (.guitar, ["guitar"]),
            (.bass, ["bass"]),
            (.strings, ["string", "strings"]),
            (.choir, ["choir", "chorus", "vocal", "voice"]),
            (.pad, ["pad", "warm"]),
            (.piano, ["piano", "keyboard"])
        ]
        return aliases.first { _, terms in terms.contains { name.contains($0) } }?.0 ?? .unknown
    }

    /// The zero-based General MIDI program. Unknown instruments safely use piano.
    public var program: UInt8 {
        switch self {
        case .piano, .unknown: 0
        case .electricPiano: 4
        case .organ: 16
        case .nylonGuitar: 24
        case .guitar: 25
        case .cleanGuitar: 27
        case .overdriveGuitar: 29
        case .distortionGuitar: 30
        case .bass: 33
        case .violin: 40
        case .cello: 42
        case .strings: 48
        case .choir: 52
        case .trumpet: 56
        case .brass: 61
        case .sax: 65
        case .flute: 73
        case .pad: 89
        case .percussion: 0
        }
    }

    /// Whether the instrument must use General MIDI channel 10.
    public var isPercussion: Bool {
        self == .percussion
    }
}
