import Foundation
import TmdSwift

/// ABC Notation exporter for TMD Sheets.
///
/// Converts a Sheet into standard ABC Notation (v2.1+), widely supported by web players
/// (e.g. abcjs), Markdown previewers, and traditional tune archives.
public struct TMDABCGenerator {

    /// Generates ABC notation string from a Sheet.
    public static func generateABC(from sheet: Sheet) -> String {
        var abc = ""

        // Header fields
        abc += "X:1\n"
        abc += "T:\(sheet.name.isEmpty ? "Untitled" : sheet.name)\n"
        abc += "C:\(sheet.metadata["composer"] ?? "TMD (Chen, Chih-Han / aguai)")\n"
        abc += "M:\(sheet.beat.count)/\(sheet.beat.noteValue)\n"
        abc += "L:1/16\n" // Base unit length = 16th note for high rhythm precision
        abc += "Q:1/4=\(Int(sheet.speed > 0 ? sheet.speed : 120))\n"
        abc += "K:\(abcKey(sheet.keySignature.description))\n\n"

        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let instruments = distinctInstruments.isEmpty ? ["Piano"] : distinctInstruments

        let orders: [Order]
        if sheet.orders.isEmpty {
            let uniqueNames = Set(sheet.paragraphs.map { $0.name })
            orders = sheet.paragraphs.map { $0.name }.filter { uniqueNames.contains($0) }.map { Order.name($0) }
        } else {
            orders = sheet.orders
        }

        // Output Voice headers
        for (idx, inst) in instruments.enumerated() {
            let vId = "V\(idx + 1)"
            abc += "V:\(vId) name=\"\(inst)\" snm=\"\(inst.prefix(3))\"\n"
        }
        abc += "\n"

        // Generate lines per instrument track
        for (idx, inst) in instruments.enumerated() {
            let vId = "V\(idx + 1)"
            abc += "[V:\(vId)]\n"
            if paragraphsContainPercussion(sheet.paragraphs, instrument: inst) {
                abc += "%%MIDI channel 10\n"
            }
            abc += generateTrackMusic(instrument: inst, sheet: sheet, orders: orders)
            abc += "\n\n"
        }

        return abc
    }

    private static func generateTrackMusic(
        instrument: String,
        sheet: Sheet,
        orders: [Order]
    ) -> String {
        let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: instrument)
        var result = ""
        var directiveIndex = 0
        for event in timeline.events {
            while directiveIndex < timeline.directives.count,
                  timeline.directives[directiveIndex].position <= event.position {
                result += formatDirective(timeline.directives[directiveIndex].kind)
                directiveIndex += 1
            }
            result += formatPlaybackEvent(event)
            result += " "
        }
        while directiveIndex < timeline.directives.count {
            result += formatDirective(timeline.directives[directiveIndex].kind)
            directiveIndex += 1
        }
        result += "|\n"
        return result
    }

    private static func formatDirective(_ kind: SectionDirectiveKind) -> String {
        switch kind {
        case .tempo(let value), .relativeTempo(let value): "Q:1/4=\(Int(value.rounded())) "
        case .timeSignature(let beat): "M:\(beat.count)/\(beat.noteValue) "
        case .absoluteKey(let key): "K:\(abcKey(key)) "
        case .relativeKey: "% TMD relative key modulation "
        }
    }

    private static func formatPlaybackEvent(_ event: PlaybackEvent) -> String {
        let multiplier = Int((event.duration * 4).rounded())
        let suffix = multiplier > 1 ? "\(multiplier)" : ""
        switch event.content {
        case .note(let note): return "\(noteToABCPitch(note, keyOffset: event.state.keyOffset))\(suffix)"
        case .chord(let chord): return "\"\(chord.description)\"z\(suffix)"
        case .rest: return "z\(suffix)"
        case .percussion(let pattern):
            let pitches = pattern.compactMap { ["X": "^F", "x": "^F", "T": "A", "t": "A", "S": "D", "s": "D"][$0] }
            return pitches.map { "\($0)\(suffix)" }.joined(separator: " ")
        }
    }

    private static func generateSectionMusic(section: Section, keyOffset: Int) -> String {
        var tokens: [String] = []
        // In L:1/16, 16th note has multiplier 1. Quarter note (4) has multiplier 4.
        let base16thMultiplier = max(1, 16 / max(1, section.noteLength))

        for directive in section.directives {
            switch directive.kind {
            case .tempo(let value), .relativeTempo(let value):
                tokens.append("Q:1/4=\(Int(value.rounded()))")
            case .timeSignature(let beat):
                tokens.append("M:\(beat.count)/\(beat.noteValue)")
            case .absoluteKey(let key):
                tokens.append("K:\(abcKey(key))")
            case .relativeKey:
                tokens.append("% TMD relative key modulation")
            }
        }

        if section.unitGroups.isEmpty {
            return "z4"
        }

        var localKeyOffset = keyOffset
        var sectionPosition = 0
        var directiveIndex = 0
        let sortedDirectives = section.directives.sorted { $0.position < $1.position }
        for unitGroup in section.unitGroups {
            while directiveIndex < sortedDirectives.count && sortedDirectives[directiveIndex].position == sectionPosition {
                switch sortedDirectives[directiveIndex].kind {
                case .relativeKey(let delta): localKeyOffset += delta
                case .absoluteKey(let key): localKeyOffset = KeySignature(string: key).semitoneOffset
                default: break
                }
                directiveIndex += 1
            }
            let totalMultiplier = unitGroup.length * base16thMultiplier
            let activeUnits = unitGroup.units.filter { $0 != .tie }

            if activeUnits.isEmpty {
                // Rest
                let multStr = totalMultiplier > 1 ? "\(totalMultiplier)" : ""
                tokens.append("z\(multStr)")
            } else if activeUnits.count == 1 {
                let multStr = totalMultiplier > 1 ? "\(totalMultiplier)" : ""
                tokens.append(formatUnit(activeUnits[0], multiplier: multStr, keyOffset: localKeyOffset))
            } else {
                // Tuplet: (p:q:r means p notes in the time of q)
                let p = activeUnits.count
                let q = unitGroup.length
                tokens.append("(\(p):\(q)")
                let subMult = max(1, totalMultiplier / p)
                let subMultStr = subMult > 1 ? "\(subMult)" : ""
                for u in activeUnits {
                    tokens.append(formatUnit(u, multiplier: subMultStr, keyOffset: localKeyOffset))
                }
            }
            sectionPosition += unitGroup.length
        }

        return tokens.joined(separator: " ")
    }

    private static func formatUnit(_ unit: TmdSwift.Unit, multiplier: String, keyOffset: Int) -> String {
        switch unit {
        case .note(let note):
            let pitchName = noteToABCPitch(note, keyOffset: keyOffset)
            return "\(pitchName)\(multiplier)"
        case .chord(let chordName):
            return "\"\(chordName.description)\"z\(multiplier)"
        case .tie:
            return "z\(multiplier)"
        case .rest:
            return "z\(multiplier)"
        case .percussion(let pattern):
            let pitches = pattern.compactMap { character -> String? in
                switch character {
                case "X", "x": return "^F"
                case "T", "t": return "A"
                case "S", "s": return "D"
                default: return nil
                }
            }
            return pitches.map { "\($0)\(multiplier)" }.joined(separator: " ")
        }
    }

    private static func paragraphsContainPercussion(_ paragraphs: [Paragraph], instrument: String) -> Bool {
        paragraphs.filter { $0.instrument == instrument }.contains { paragraph in
            paragraph.sections.contains { section in
                section.unitGroups.contains { group in
                    group.units.contains { if case .percussion = $0 { return true }; return false }
                }
            }
        }
    }

    // MARK: - Pitch Helpers

    private static func noteToABCPitch(_ note: Note, keyOffset: Int) -> String {
        var midiPitch = 60 + keyOffset + note.degree.semitoneOffset

        switch note.accidental {
        case .sharp: midiPitch += 1
        case .flat: midiPitch -= 1
        case .natural: break
        }
        midiPitch += note.octave * 12

        return midiPitchToABC(midiPitch)
    }

    private static func midiPitchToABC(_ pitch: Int) -> String {
        // In ABC notation:
        // C, D, E, F, G, A, B is the octave below Middle C (MIDI 48..59)
        // c, d, e, f, g, a, b is the octave of Middle C and above (MIDI 60..71)
        // c' is MIDI 72, c'' is MIDI 84, C, is MIDI 36, C,, is MIDI 24
        let semitone = ((pitch % 12) + 12) % 12
        let octave = (pitch / 12) - 1 // Middle C (60) is octave 4

        if octave >= 5 {
            let base = PitchMapping.abcLowerNames[semitone]
            let apostrophes = String(repeating: "'", count: octave - 5)
            return "\(base)\(apostrophes)"
        } else if octave == 4 {
            return PitchMapping.abcLowerNames[semitone]
        } else if octave == 3 {
            return PitchMapping.abcUpperNames[semitone]
        } else {
            let base = PitchMapping.abcUpperNames[semitone]
            let commas = String(repeating: ",", count: 3 - octave)
            return "\(base)\(commas)"
        }
    }

    private static func abcKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "C" }
        var pitch = String(first).uppercased()
        if trimmed.contains("'") || trimmed.contains("#") {
            pitch += "#"
        } else if trimmed.contains(",") || trimmed.contains("b") {
            pitch += "b"
        }
        return pitch
    }

}
