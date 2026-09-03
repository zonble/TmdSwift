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
            abc += generateTrackMusic(instrument: inst, sheet: sheet)
            abc += "\n\n"
        }

        return abc
    }

    private static func generateTrackMusic(
        instrument: String,
        sheet: Sheet
    ) -> String {
        let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: instrument)
        var result = ""
        var directiveIndex = 0
        for event in timeline.events {
            while directiveIndex < timeline.directives.count,
                  timeline.directives[directiveIndex].position <= event.position {
                result += formatDirective(timeline.directives[directiveIndex])
                directiveIndex += 1
            }
            result += formatPlaybackEvent(event)
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
        case .tempo, .relativeTempo: "Q:1/4=\(Int(directive.state.tempo.rounded())) "
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
