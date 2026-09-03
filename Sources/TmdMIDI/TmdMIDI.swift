import Foundation
import TmdSwift

/// Standard MIDI file generator for TMD Sheets.
public struct TMDMIDIGenerator {
    public static let defaultTicksPerQuarterNote: UInt16 = 480

    /// Converts a Sheet into Standard MIDI File (SMF Type 1) binary data.
    public static func generateMIDI(from sheet: Sheet, ticksPerQuarter: UInt16 = defaultTicksPerQuarterNote) -> Data {
        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let timelineInstrument = sheet.paragraphs.first {
            $0.sections.contains { !$0.directives.isEmpty }
        }?.instrument ?? distinctInstruments.first ?? "Piano"
        let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: timelineInstrument)
        var trackData = [TMDMIDIEncoder.encodeTrack(events: conductorEvents(
            sheet: sheet, timeline: timeline, ticksPerQuarter: ticksPerQuarter
        ))]
        for (instrumentIndex, instrument) in distinctInstruments.enumerated() {
            let midiInstrument = MIDIInstrument.resolve(instrument)
            let channel = midiInstrument.isPercussion ? 9 : UInt8(instrumentIndex % 9)
            let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: instrument)
            trackData.append(TMDMIDIEncoder.encodeTrack(events: instrumentEvents(
                timeline: timeline, instrument: instrument, midiInstrument: midiInstrument,
                channel: channel, ticksPerQuarter: ticksPerQuarter
            )))
        }
        return TMDMIDIEncoder.encodeFile(tracks: trackData, ticksPerQuarter: ticksPerQuarter)
    }

    private static func conductorEvents(sheet: Sheet, timeline: PlaybackTimeline, ticksPerQuarter: UInt16) -> [MIDIEvent] {
        let initial = [
            MIDIEvent(tick: 0, message: .trackName(sheet.name.isEmpty ? "TMD Score" : sheet.name)),
            MIDIEvent(tick: 0, message: .tempo(sheet.speed > 0 ? sheet.speed : 120)),
            MIDIEvent(tick: 0, message: .timeSignature(sheet.beat))
        ]
        let directives = timeline.directives.compactMap { directive -> MIDIEvent? in
            let tick = midiTick(directive.position, ticksPerQuarter: ticksPerQuarter)
            switch directive.kind {
            case .tempo, .relativeTempo: return MIDIEvent(tick: tick, message: .tempo(directive.state.tempo))
            case .timeSignature: return MIDIEvent(tick: tick, message: .timeSignature(directive.state.timeSignature))
            case .absoluteKey, .relativeKey: return nil
            }
        }
        return initial + directives
    }

    private static func instrumentEvents(
        timeline: PlaybackTimeline,
        instrument: String,
        midiInstrument: MIDIInstrument,
        channel: UInt8,
        ticksPerQuarter: UInt16
    ) -> [MIDIEvent] {
        var events = [MIDIEvent(tick: 0, message: .trackName(instrument))]
        if !midiInstrument.isPercussion {
            events.append(MIDIEvent(tick: 0, message: .programChange(channel: channel, program: midiInstrument.program)))
        }
        for event in timeline.events {
            let start = midiTick(event.position, ticksPerQuarter: ticksPerQuarter)
            let duration = max(1, midiTick(event.duration, ticksPerQuarter: ticksPerQuarter))
            switch event.content {
            case .note(let note):
                appendNote(&events, start: start, duration: duration, channel: channel, pitch: noteToMIDIPitch(note, keyOffset: event.state.keyOffset), velocity: 96)
            case .chord(let chord):
                chordToMIDIPitches(chord, keyOffset: event.state.keyOffset).forEach {
                    appendNote(&events, start: start, duration: duration, channel: channel, pitch: $0, velocity: 88)
                }
            case .percussion(let pattern):
                let step = max(1, duration / UInt32(max(1, pattern.count)))
                for (index, character) in pattern.enumerated() {
                    if let pitch = percussionMIDIPitch(for: character) {
                        appendNote(&events, start: start + UInt32(index) * step, duration: step, channel: 9, pitch: pitch, velocity: 96)
                    }
                }
            case .rest:
                break
            }
        }
        return events
    }

    private static func appendNote(_ events: inout [MIDIEvent], start: UInt32, duration: UInt32, channel: UInt8, pitch: Int, velocity: UInt8) {
        guard (0...127).contains(pitch) else { return }
        events.append(MIDIEvent(tick: start, message: .noteOn(channel: channel, note: UInt8(pitch), velocity: velocity)))
        events.append(MIDIEvent(tick: start + max(1, duration - 2), message: .noteOff(channel: channel, note: UInt8(pitch))))
    }

    private static func midiTick(_ quarterNotes: Double, ticksPerQuarter: UInt16) -> UInt32 {
        UInt32(max(0, (quarterNotes * Double(ticksPerQuarter)).rounded()))
    }

    // MARK: - Musical Helpers

    /// Converts scale degree (1~7) + accidental + octave into MIDI pitch (Middle C = 60).
    public static func noteToMIDIPitch(_ note: Note, keyOffset: Int) -> Int {
        var pitch = 60 + keyOffset + note.degree.semitoneOffset

        switch note.accidental {
        case .sharp: pitch += 1
        case .flat: pitch -= 1
        case .natural: break
        }

        pitch += note.octave * 12
        return pitch
    }

    private static func percussionMIDIPitch(for character: Character) -> Int? {
        ["X": 42, "x": 42, "T": 45, "t": 45, "S": 38, "s": 38][character]
    }

    /// Resolves chord names (degree numbers like `1`, `6m`, `4`, `5`, or chord names like `Cmaj7`).
    public static func chordToMIDIPitches(_ chord: String, keyOffset: Int) -> [Int] {
        chordToMIDIPitches(ChordSymbol(string: chord), keyOffset: keyOffset)
    }

    /// Resolves a typed chord symbol into MIDI pitches.
    public static func chordToMIDIPitches(_ chord: ChordSymbol, keyOffset: Int) -> [Int] {
        let rootPitch: Int
        if chord.root.isScaleDegree {
            let note = Note(accidental: chord.root.accidental, degree: chord.root.degree)
            rootPitch = noteToMIDIPitch(note, keyOffset: keyOffset) - 12
        } else {
            rootPitch = 48 + chord.root.semitoneOffset
        }
        return chord.quality.semitoneIntervals.map { rootPitch + $0 }
    }

    public static func generalMidiProgram(for instrument: String) -> UInt8 {
        MIDIInstrument.resolve(instrument).program
    }

}
