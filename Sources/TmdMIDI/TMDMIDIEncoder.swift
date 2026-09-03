import Foundation

enum MIDIMessage {
    case meta(type: UInt8, data: Data)
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
        sorted.append(MIDIEvent(tick: lastTick, message: .meta(type: 0x2F, data: Data())))

        return sorted.reduce(into: (data: Data(), lastTick: UInt32(0))) { result, event in
            let delta = event.tick >= result.lastTick ? event.tick - result.lastTick : 0
            result.data.append(contentsOf: variableLengthQuantity(delta))
            result.data.append(encodeMessage(event.message))
            result.lastTick = event.tick
        }.data
    }

    private static func encodeMessage(_ message: MIDIMessage) -> Data {
        switch message {
        case .meta(let type, let data):
            return Data([0xFF, type]) + Data(variableLengthQuantity(UInt32(data.count))) + data
        case .noteOn(let channel, let note, let velocity):
            return Data([0x90 | channel, note, velocity])
        case .noteOff(let channel, let note):
            return Data([0x80 | channel, note, 0])
        case .programChange(let channel, let program):
            return Data([0xC0 | channel, program])
        }
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
