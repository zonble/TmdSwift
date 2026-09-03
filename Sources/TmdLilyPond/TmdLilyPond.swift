import Foundation
import TmdSwift

/// LilyPond score generator for TMD Sheets.
///
/// Exports the Sheet AST into LilyPond (`.ly`) source files, which can be compiled by the
/// `lilypond` tool into publication-quality engraving PDFs, SVGs, or PNGs.
public struct TMDLilyPondGenerator {

    /// Generates LilyPond `.ly` file content from a Sheet.
    public static func generateLilyPond(from sheet: Sheet) -> String {
        let composer = sheet.metadata["composer"] ?? "TMD"
        var ly = """
        \\version "2.24.0"

        \\header {
          title = "\(escapeLilyPond(sheet.name.isEmpty ? "Untitled" : sheet.name))"
          composer = "\(escapeLilyPond(composer))"
          tagline = "Engraved by TmdSwift LilyPond Exporter"
        }

        \\paper {
          indent = 1.5\\cm
          short-indent = 0.5\\cm
        }

        global = {
          \\time \(sheet.beat.count)/\(sheet.beat.noteValue)
          \\tempo 4 = \(Int(sheet.speed > 0 ? sheet.speed : 120))
          \\key \(lilyPondKey(sheet.keySignature.description))
        }

        """

        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let instruments = distinctInstruments.isEmpty ? ["Piano"] : distinctInstruments

        // Generate track music definitions for each instrument
        for (idx, inst) in instruments.enumerated() {
            let varName = sanitizeIdentifier(inst, index: idx)
            let isDrum = paragraphsContainPercussion(sheet.paragraphs, instrument: inst)
            ly += "\(varName) = \(isDrum ? "\\drummode " : ""){\n"
            ly += "  \\global\n"
            ly += generateTrackMusic(instrument: inst, sheet: sheet, percussion: isDrum)
            ly += "}\n\n"
        }

        // Score layout block
        ly += "\\score {\n"
        ly += "  <<\n"
        for (idx, inst) in instruments.enumerated() {
            let varName = sanitizeIdentifier(inst, index: idx)
            let isDrum = paragraphsContainPercussion(sheet.paragraphs, instrument: inst)
            let staffType = isDrum ? "DrumStaff" : "Staff"
            ly += """
                \\new \(staffType) = "\(escapeLilyPond(inst))" \\with {
                  instrumentName = "\(escapeLilyPond(inst))"
                  shortInstrumentName = "\(escapeLilyPond(inst.prefix(3).description))"
                } {
                  \\\(varName)
                }

            """
        }
        ly += "  >>\n"
        ly += "  \\layout { }\n"
        ly += "  \\midi { }\n"
        ly += "}\n"

        return ly
    }

    private static func generateTrackMusic(
        instrument: String,
        sheet: Sheet,
        percussion: Bool
    ) -> String {
        let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: instrument)
        var result = "  "
        var directiveIndex = 0
        for event in timeline.events {
            while directiveIndex < timeline.directives.count,
                  timeline.directives[directiveIndex].position <= event.position {
                result += formatDirective(timeline.directives[directiveIndex])
                directiveIndex += 1
            }
            result += formatPlaybackEvent(event, percussion: percussion)
            result += " "
        }
        while directiveIndex < timeline.directives.count {
            result += formatDirective(timeline.directives[directiveIndex])
            directiveIndex += 1
        }
        result += "|\n"
        return result
    }

    private static func formatDirective(_ directive: PlaybackDirectiveEvent) -> String {
        switch directive.kind {
        case .tempo, .relativeTempo: "\\tempo 4 = \(Int(directive.state.tempo.rounded())) "
        case .timeSignature(let beat): "\\time \(beat.count)/\(beat.noteValue) "
        case .absoluteKey(let key): "\\key \(lilyPondKey(key)) "
        case .relativeKey: "% TMD relative key modulation "
        }
    }

    private static func formatPlaybackEvent(_ event: PlaybackEvent, percussion: Bool) -> String {
        let duration = formatQuarterDuration(event.duration)
        switch event.content {
        case .note(let note):
            return "\(noteToLilyPondPitch(note, keyOffset: event.state.keyOffset))\(duration)"
        case .chord(let chord):
            let pitches = chordToLilyPondPitches(chord, keyOffset: event.state.keyOffset)
            return "<\(pitches.joined(separator: " "))>\(duration)"
        case .rest: return "r\(duration)"
        case .percussion(let pattern):
            let names = pattern.compactMap { ["X": "hh", "x": "hh", "T": "toml", "t": "toml", "S": "sn", "s": "sn"][$0] }
            return names.map { "\($0)\(duration)" }.joined(separator: " ")
        }
    }

    private static func formatQuarterDuration(_ quarterNotes: Double) -> String {
        let value = Int((4.0 / max(quarterNotes, 0.0001)).rounded())
        return "\(max(1, value))"
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

    // MARK: - Pitch & Duration Helpers

    private static func formatDuration(noteLength: Int, spanCount: Int) -> String {
        guard spanCount > 0, noteLength > 0, noteLength.isMultiple(of: spanCount) else {
            return "\(noteLength)"
        }
        return "\(noteLength / spanCount)"
    }

    private static func noteToLilyPondPitch(_ note: Note, keyOffset: Int) -> String {
        let degree = note.degree.rawValue
        guard (1...7).contains(degree) else { return "c'" }
        var midiPitch = 60 + keyOffset + note.degree.semitoneOffset

        switch note.accidental {
        case .sharp: midiPitch += 1
        case .flat: midiPitch -= 1
        case .natural: break
        }
        midiPitch += note.octave * 12

        return midiPitchToLilyPond(midiPitch)
    }

    private static func chordToLilyPondPitches(_ chord: ChordSymbol, keyOffset: Int) -> [String] {
        let root: Int
        if chord.root.isScaleDegree {
            root = 60 + keyOffset + chord.root.degree.semitoneOffset
                + chord.root.accidental.semitoneOffset
        } else {
            root = 48 + chord.root.semitoneOffset
        }
        return chord.quality.semitoneIntervals.map { midiPitchToLilyPond(root + $0) }
    }

    private static func midiPitchToLilyPond(_ pitch: Int) -> String {
        // LilyPond base: c' is Middle C (MIDI 60)
        let semitone = ((pitch % 12) + 12) % 12
        let octave = (pitch / 12) - 1 // Middle C is octave 4 in standard convention, octave 3 in LilyPond reference

        var name = PitchMapping.lilyPondNames[semitone]
        if octave > 3 {
            name += String(repeating: "'", count: octave - 3)
        } else if octave < 3 {
            name += String(repeating: ",", count: 3 - octave)
        }
        return name
    }

    private static func lilyPondKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "c \\major" }
        var pitch = String(first).lowercased()
        if trimmed.contains("'") || trimmed.contains("#") {
            pitch += "is"
        } else if trimmed.contains(",") || trimmed.contains("b") {
            pitch += "es"
        }
        return "\(pitch) \\major"
    }

    private static func sanitizeIdentifier(_ string: String, index: Int) -> String {
        let filtered = string.filter { $0.isLetter }
        return filtered.isEmpty ? "track\(index + 1)" : filtered
    }

    private static func escapeLilyPond(_ string: String) -> String {
        return string.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
