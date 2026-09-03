import Foundation
import TmdSwift

enum MIDIMessage {
    case trackName(String)
    case tempo(Double)
    case timeSignature(Beat)
    case endOfTrack
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8)
    case programChange(channel: UInt8, program: UInt8)
}

struct MIDIEvent {
    var tick: UInt32
    var message: MIDIMessage
}

/// Encodes typed MIDI content into Standard MIDI File binary data.
final class TMDMIDIEncoder {
    static func encodeFile(tracks: [Data], ticksPerQuarter: UInt16) -> Data {
        let header = Data("MThd".utf8)
            + Data(UInt32(6).bigEndianBytes)
            + Data(UInt16(1).bigEndianBytes)
            + Data(UInt16(tracks.count).bigEndianBytes)
            + Data(ticksPerQuarter.bigEndianBytes)
        return tracks.reduce(into: header) { midi, track in
            midi.append(contentsOf: "MTrk".utf8)
            midi.append(contentsOf: UInt32(track.count).bigEndianBytes)
            midi.append(track)
        }
    }

    static func encodeTrack(events: [MIDIEvent]) -> Data {
        var sorted = events.sorted { $0.tick < $1.tick }
        let lastTick = sorted.last?.tick ?? 0
        sorted.append(MIDIEvent(tick: lastTick, message: .endOfTrack))

        return sorted.reduce(into: (data: Data(), lastTick: UInt32(0))) { result, event in
            let delta = event.tick >= result.lastTick ? event.tick - result.lastTick : 0
            result.data.append(contentsOf: variableLengthQuantity(delta))
            result.data.append(encodeMessage(event.message))
            result.lastTick = event.tick
        }.data
    }

    private static func encodeMessage(_ message: MIDIMessage) -> Data {
        switch message {
        case .trackName(let name):
            return metaEvent(type: 0x03, data: Data(name.utf8))
        case .tempo(let bpm):
            let mpqn = UInt32(60_000_000.0 / max(1, bpm))
            let data = Data([UInt8((mpqn >> 16) & 0xFF), UInt8((mpqn >> 8) & 0xFF), UInt8(mpqn & 0xFF)])
            return metaEvent(type: 0x51, data: data)
        case .timeSignature(let beat):
            let denominator = UInt8(round(log2(Double(max(1, beat.noteValue)))))
            return metaEvent(type: 0x58, data: Data([UInt8(max(1, beat.count)), denominator, 24, 8]))
        case .endOfTrack:
            return metaEvent(type: 0x2F, data: Data())
        case .noteOn(let channel, let note, let velocity):
            return Data([0x90 | channel, note, velocity])
        case .noteOff(let channel, let note):
            return Data([0x80 | channel, note, 0])
        case .programChange(let channel, let program):
            return Data([0xC0 | channel, program])
        }
    }

    private static func metaEvent(type: UInt8, data: Data) -> Data {
        Data([0xFF, type]) + Data(variableLengthQuantity(UInt32(data.count))) + data
    }

    private static func variableLengthQuantity(_ value: UInt32) -> [UInt8] {
        var buffer = [UInt8(value & 0x7F)]
        var value = value >> 7
        while value > 0 {
            buffer.append(UInt8((value & 0x7F) | 0x80))
            value >>= 7
        }
        return buffer.reversed()
    }
}

private extension FixedWidthInteger {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian
        return withUnsafeBytes(of: &value) { Array($0) }
    }
}
