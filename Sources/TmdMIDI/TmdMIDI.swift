import Foundation
import TmdSwift

/// Standard MIDI file generator for TMD Sheets.
public struct TMDMIDIGenerator {
    public static let defaultTicksPerQuarterNote: UInt16 = 480

    /// Converts a Sheet into Standard MIDI File (SMF Type 1) binary data.
    public static func generateMIDI(from sheet: Sheet, ticksPerQuarter: UInt16 = defaultTicksPerQuarterNote) -> Data {
        var midiData = Data()

        // 1. Collect arrangement playback sequence
        // If sheet.orders is empty, fallback to playing each unique paragraph in declaration order once.
        let orderSequence: [Order]
        if sheet.orders.isEmpty {
            let uniqueNames = Set(sheet.paragraphs.map { $0.name })
            orderSequence = sheet.paragraphs.map { $0.name }.filter { uniqueNames.contains($0) }.map { Order.name($0) }
        } else {
            orderSequence = sheet.orders
        }

        // Group paragraphs by (name, instrument)
        // Tracks in MIDI will correspond to distinct instruments
        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let trackCount = UInt16(distinctInstruments.count + 1) // 1 conductor track + instrument tracks

        // Header Chunk (14 bytes)
        // "MThd", length=6, format=1, tracks=trackCount, division=ticksPerQuarter
        midiData.append(contentsOf: "MThd".utf8)
        midiData.append(contentsOf: UInt32(6).bigEndianBytes)
        midiData.append(contentsOf: UInt16(1).bigEndianBytes) // Format 1 (multi-track)
        midiData.append(contentsOf: trackCount.bigEndianBytes)
        midiData.append(contentsOf: ticksPerQuarter.bigEndianBytes)

        // Track 0: Conductor Track (Tempo, Time Signature, Track Name)
        let conductorTrackData = buildConductorTrack(sheet: sheet, orders: orderSequence, ticksPerQuarter: ticksPerQuarter)
        midiData.append(contentsOf: "MTrk".utf8)
        midiData.append(contentsOf: UInt32(conductorTrackData.count).bigEndianBytes)
        midiData.append(conductorTrackData)

        // Calculate sequence order events per instrument
        for (instrumentIndex, instrument) in distinctInstruments.enumerated() {
            let channel = UInt8(instrumentIndex % 16)
            let trackEvents = buildInstrumentTrackEvents(
                instrument: instrument,
                sheet: sheet,
                orders: orderSequence,
                channel: channel,
                ticksPerQuarter: ticksPerQuarter
            )
            let trackData = encodeTrack(events: trackEvents)
            midiData.append(contentsOf: "MTrk".utf8)
            midiData.append(contentsOf: UInt32(trackData.count).bigEndianBytes)
            midiData.append(trackData)
        }

        return midiData
    }

    // MARK: - Conductor Track

    private static func buildConductorTrack(sheet: Sheet, orders: [Order], ticksPerQuarter: UInt16) -> Data {
        var events: [MIDIEvent] = []

        // Sequence / Track Name
        let songName = sheet.name.isEmpty ? "TMD Score" : sheet.name
        events.append(MIDIEvent(tick: 0, rawBytes: metaEvent(type: 0x03, data: Data(songName.utf8))))

        // Tempo event: microseconds per quarter note = 60,000,000 / BPM
        let bpm = sheet.speed > 0 ? sheet.speed : 120.0
        let mpqn = UInt32(60_000_000.0 / bpm)
        let tempoBytes = Data([
            UInt8((mpqn >> 16) & 0xFF),
            UInt8((mpqn >> 8) & 0xFF),
            UInt8(mpqn & 0xFF)
        ])
        events.append(MIDIEvent(tick: 0, rawBytes: metaEvent(type: 0x51, data: tempoBytes)))

        // Time Signature: numerator, denominator as power of 2 (4 -> 2, 8 -> 3), clocks/tick(24), 32nd notes/24 clocks(8)
        let nn = UInt8(sheet.beat.count)
        let dd = UInt8(round(log2(Double(sheet.beat.noteValue > 0 ? sheet.beat.noteValue : 4))))
        let timeSigBytes = Data([nn, dd, 24, 8])
        events.append(MIDIEvent(tick: 0, rawBytes: metaEvent(type: 0x58, data: timeSigBytes)))

        // Local directives are placed on the conductor timeline according to
        // the same arrangement order used by instrument tracks.
        var currentTick: UInt32 = 0
        var currentTempo = sheet.speed > 0 ? sheet.speed : 120.0
        let ticksPerMeasure = UInt32(Double(ticksPerQuarter) * (4.0 / Double(max(1, sheet.beat.noteValue))) * Double(max(1, sheet.beat.count)))
        for order in orders {
            guard case .name(let paragraphName) = order else { continue }
            let candidates = sheet.paragraphs.filter { $0.name == paragraphName && !$0.sections.isEmpty }
            guard let paragraph = candidates.first else { continue }
            let paragraphStart = currentTick + UInt32(max(0, paragraph.start)) * ticksPerMeasure
            var sectionOffset: UInt32 = 0
            for section in paragraph.sections {
                let ticksPerUnit = UInt32((Double(ticksPerQuarter) * 4.0) / Double(max(1, section.noteLength)))
                for directive in section.directives {
                    let tick = paragraphStart + sectionOffset + UInt32(max(0, directive.position)) * ticksPerUnit
                    switch directive.kind {
                    case .tempo(let value):
                        currentTempo = max(1.0, value)
                        let mpqn = UInt32(60_000_000.0 / currentTempo)
                        let bytes = Data([UInt8((mpqn >> 16) & 0xFF), UInt8((mpqn >> 8) & 0xFF), UInt8(mpqn & 0xFF)])
                        events.append(MIDIEvent(tick: tick, rawBytes: metaEvent(type: 0x51, data: bytes)))
                    case .relativeTempo(let value):
                        currentTempo = max(1.0, currentTempo + value)
                        let mpqn = UInt32(60_000_000.0 / currentTempo)
                        let bytes = Data([UInt8((mpqn >> 16) & 0xFF), UInt8((mpqn >> 8) & 0xFF), UInt8(mpqn & 0xFF)])
                        events.append(MIDIEvent(tick: tick, rawBytes: metaEvent(type: 0x51, data: bytes)))
                    case .timeSignature(let beat):
                        let denominator = UInt8(round(log2(Double(max(1, beat.noteValue)))))
                        events.append(MIDIEvent(tick: tick, rawBytes: metaEvent(type: 0x58, data: Data([UInt8(max(1, beat.count)), denominator, 24, 8]))))
                    case .absoluteKey, .relativeKey:
                        break
                    }
                }
                sectionOffset += section.unitGroups.reduce(0) { partial, group in
                    partial + UInt32(max(0, group.length)) * ticksPerUnit
                }
            }
            currentTick += calculateParagraphDurationTicks(paragraphName: paragraphName, sheet: sheet, ticksPerQuarter: ticksPerQuarter)
        }

        return encodeTrack(events: events)
    }

    // MARK: - Instrument Track Construction

    private static func buildInstrumentTrackEvents(
        instrument: String,
        sheet: Sheet,
        orders: [Order],
        channel: UInt8,
        ticksPerQuarter: UInt16
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Track Name
        events.append(MIDIEvent(tick: 0, rawBytes: metaEvent(type: 0x03, data: Data(instrument.utf8))))

        // Program change based on instrument hint
        let programNumber = generalMidiProgram(for: instrument)
        events.append(MIDIEvent(tick: 0, rawBytes: Data([0xC0 | channel, programNumber])))

        var currentTick: UInt32 = 0
        let rootOffsetSemis: Int = parseKeySignatureSemitones(sheet.keySignature.description)
        var currentModulation: Int = 0

        for order in orders {
            switch order {
            case .relative(let rel):
                if let delta = Int(rel.replacingOccurrences(of: "+", with: "")) {
                    currentModulation += delta
                }
            case .absolute(let abs):
                currentModulation = parseKeySignatureSemitones(abs) - rootOffsetSemis
            case .name(let paragraphName):
                // Find paragraph matching name and instrument
                guard let paragraph = sheet.paragraphs.first(where: { $0.name == paragraphName && $0.instrument == instrument }) else {
                    // Even if this instrument isn't in this paragraph, we must advance currentTick by this paragraph's duration!
                    let maxDuration = calculateParagraphDurationTicks(
                        paragraphName: paragraphName,
                        sheet: sheet,
                        ticksPerQuarter: ticksPerQuarter
                    )
                    currentTick += maxDuration
                    continue
                }

                let totalKeyOffset = rootOffsetSemis + currentModulation
                let sectionEvents = renderParagraph(
                    paragraph: paragraph,
                    baseTick: currentTick,
                    keyOffset: totalKeyOffset,
                    channel: channel,
                    sheet: sheet,
                    ticksPerQuarter: ticksPerQuarter
                )
                events.append(contentsOf: sectionEvents.events)

                // Advance by the paragraph's duration (taking other tracks into account to stay synced)
                let maxDuration = calculateParagraphDurationTicks(
                    paragraphName: paragraphName,
                    sheet: sheet,
                    ticksPerQuarter: ticksPerQuarter
                )
                currentTick += max(sectionEvents.duration, maxDuration)
            }
        }

        return events
    }

    private static func calculateParagraphDurationTicks(paragraphName: String, sheet: Sheet, ticksPerQuarter: UInt16) -> UInt32 {
        let matchingParagraphs = sheet.paragraphs.filter { $0.name == paragraphName }
        var maxTicks: UInt32 = 0
        for p in matchingParagraphs {
            let beatsPerMeasure = Double(sheet.beat.count)
            let ticksPerMeasure = UInt32(Double(ticksPerQuarter) * (4.0 / Double(max(1, sheet.beat.noteValue))) * beatsPerMeasure)
            var pTicks = UInt32(max(0, p.start)) * ticksPerMeasure
            for sec in p.sections {
                let ticksPerUnit = UInt32((Double(ticksPerQuarter) * 4.0) / Double(sec.noteLength))
                for ug in sec.unitGroups {
                    pTicks += UInt32(ug.length) * ticksPerUnit
                }
            }
            if pTicks > maxTicks {
                maxTicks = pTicks
            }
        }
        return maxTicks
    }

    private static func renderParagraph(
        paragraph: Paragraph,
        baseTick: UInt32,
        keyOffset: Int,
        channel: UInt8,
        sheet: Sheet,
        ticksPerQuarter: UInt16
    ) -> (events: [MIDIEvent], duration: UInt32) {
        var events: [MIDIEvent] = []
        let beatsPerMeasure = Double(sheet.beat.count)
        let ticksPerMeasure = UInt32(Double(ticksPerQuarter) * (4.0 / Double(max(1, sheet.beat.noteValue))) * beatsPerMeasure)

        var trackTick = baseTick + (UInt32(max(0, paragraph.start)) * ticksPerMeasure)
        let startTick = trackTick

        var localKeyOffset = keyOffset
        for section in paragraph.sections {
            let ticksPerUnit = UInt32((Double(ticksPerQuarter) * 4.0) / Double(section.noteLength))
            var sectionPosition = 0
            var directiveIndex = 0
            let directives = section.directives.sorted { $0.position < $1.position }

            for unitGroup in section.unitGroups {
                while directiveIndex < directives.count && directives[directiveIndex].position == sectionPosition {
                    applyKeyDirective(directives[directiveIndex].kind, to: &localKeyOffset)
                    directiveIndex += 1
                }
                let groupDuration = UInt32(unitGroup.length) * ticksPerUnit
                let activeUnits = unitGroup.units.filter { $0 != .tie }

                if !activeUnits.isEmpty {
                    let subDuration = groupDuration / UInt32(activeUnits.count)
                    var unitStartTick = trackTick

                    for unit in activeUnits {
                        switch unit {
                        case .note(let note):
                            let midiPitch = noteToMIDIPitch(note, keyOffset: localKeyOffset)
                            if (0...127).contains(midiPitch) {
                                let noteOn = Data([0x90 | channel, UInt8(midiPitch), 96])
                                let noteOff = Data([0x80 | channel, UInt8(midiPitch), 0])
                                events.append(MIDIEvent(tick: unitStartTick, rawBytes: noteOn))
                                events.append(MIDIEvent(tick: unitStartTick + max(1, subDuration - 2), rawBytes: noteOff))
                            }
                        case .chord(let chordName):
                            let pitches = chordToMIDIPitches(chordName, keyOffset: localKeyOffset)
                            for p in pitches where (0...127).contains(p) {
                                let noteOn = Data([0x90 | channel, UInt8(p), 88])
                                let noteOff = Data([0x80 | channel, UInt8(p), 0])
                                events.append(MIDIEvent(tick: unitStartTick, rawBytes: noteOn))
                                events.append(MIDIEvent(tick: unitStartTick + max(1, subDuration - 2), rawBytes: noteOff))
                            }
                        case .tie:
                            break
                        case .rest:
                            break
                        case .percussion(let pattern):
                            let drumDuration = max(1, subDuration / UInt32(max(1, pattern.count)))
                            for (index, character) in pattern.enumerated() {
                                guard let pitch = percussionMIDIPitch(for: character) else { continue }
                                let tick = unitStartTick + UInt32(index) * drumDuration
                                events.append(MIDIEvent(tick: tick, rawBytes: Data([0x99, UInt8(pitch), 96])))
                                events.append(MIDIEvent(tick: tick + max(1, drumDuration - 1), rawBytes: Data([0x89, UInt8(pitch), 0])))
                            }
                        }
                        unitStartTick += subDuration
                    }
                }
                trackTick += groupDuration
                sectionPosition += unitGroup.length
            }
        }

        return (events, trackTick - startTick)
    }

    private static func applyKeyDirective(_ kind: SectionDirectiveKind, to offset: inout Int) {
        switch kind {
        case .relativeKey(let delta): offset += delta
        case .absoluteKey(let key): offset = parseKeySignatureSemitones(key)
        default: break
        }
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

    public static func parseKeySignatureSemitones(_ key: String) -> Int {
        let signature = KeySignature(string: key)
        return signature.tonic.semitoneOffset + signature.accidental.semitoneOffset
    }

    public static func generalMidiProgram(for instrument: String) -> UInt8 {
        let lower = instrument.lowercased()
        let mappings: [(terms: [String], program: UInt8)] = [
            (["piano"], 0),
            (["guitar"], 25),
            (["chord"], 4),
            (["bass"], 33),
            (["drum", "groove"], 118),
            (["chrous", "chorus", "voice"], 52),
            (["string"], 48)
        ]
        return mappings.first { mapping in
            mapping.terms.contains { lower.contains($0) }
        }?.program ?? 0
    }

    // MARK: - MIDI Binary Encoding

    private struct MIDIEvent {
        var tick: UInt32
        var rawBytes: Data
    }

    private static func encodeTrack(events: [MIDIEvent]) -> Data {
        var sorted = events.sorted { $0.tick < $1.tick }
        // Append End Of Track meta event (FF 2F 00)
        let lastTick = sorted.last?.tick ?? 0
        sorted.append(MIDIEvent(tick: lastTick, rawBytes: metaEvent(type: 0x2F, data: Data())))

        var trackBytes = Data()
        var lastTickWritten: UInt32 = 0

        for event in sorted {
            let delta = event.tick >= lastTickWritten ? (event.tick - lastTickWritten) : 0
            trackBytes.append(contentsOf: variableLengthQuantity(delta))
            trackBytes.append(event.rawBytes)
            lastTickWritten = event.tick
        }
        return trackBytes
    }

    private static func metaEvent(type: UInt8, data: Data) -> Data {
        var bytes = Data([0xFF, type])
        bytes.append(contentsOf: variableLengthQuantity(UInt32(data.count)))
        bytes.append(data)
        return bytes
    }

    private static func variableLengthQuantity(_ value: UInt32) -> [UInt8] {
        var buffer: [UInt8] = []
        var val = value
        buffer.append(UInt8(val & 0x7F))
        val >>= 7
        while val > 0 {
            buffer.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        return buffer.reversed()
    }
}

private extension FixedWidthInteger {
    var bigEndianBytes: [UInt8] {
        var value = self.bigEndian
        return withUnsafeBytes(of: &value) { Array($0) }
    }
}
