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
          \\key \(lilyPondKey(sheet.keySignature))
        }

        """

        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let instruments = distinctInstruments.isEmpty ? ["Piano"] : distinctInstruments

        let orders: [Order]
        if sheet.orders.isEmpty {
            let uniqueNames = Set(sheet.paragraphs.map { $0.name })
            orders = sheet.paragraphs.map { $0.name }.filter { uniqueNames.contains($0) }.map { Order.name($0) }
        } else {
            orders = sheet.orders
        }

        // Generate track music definitions for each instrument
        for (idx, inst) in instruments.enumerated() {
            let varName = sanitizeIdentifier(inst, index: idx)
            let isDrum = paragraphsContainPercussion(sheet.paragraphs, instrument: inst)
            ly += "\(varName) = \(isDrum ? "\\drummode " : ""){\n"
            ly += "  \\global\n"
            ly += generateTrackMusic(instrument: inst, sheet: sheet, orders: orders, percussion: isDrum)
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
        orders: [Order],
        percussion: Bool
    ) -> String {
        var result = ""
        let rootOffset = parseKeySignatureSemitones(sheet.keySignature)
        var currentModulation = 0

        for order in orders {
            switch order {
            case .relative(let rel):
                if let delta = Int(rel.replacingOccurrences(of: "+", with: "")) {
                    currentModulation += delta
                }
            case .absolute(let abs):
                currentModulation = parseKeySignatureSemitones(abs) - rootOffset
            case .name(let paragraphName):
                let matchingParagraph = sheet.paragraphs.first(where: { $0.name == paragraphName && $0.instrument == instrument })

                guard let paragraph = matchingParagraph else {
                    // Whole measure rest
                    result += "  R1*\(sheet.beat.count)/\(sheet.beat.noteValue) |\n"
                    continue
                }

                let totalKeyOffset = rootOffset + currentModulation
                result += "  % Section: \(paragraphName)\n"

                for section in paragraph.sections {
                    result += generateSectionMusic(
                        section: section,
                        keyOffset: totalKeyOffset,
                        percussion: percussion
                    )
                    result += " |\n"
                }
            }
        }
        return result
    }

    private static func generateSectionMusic(section: Section, keyOffset: Int, percussion: Bool = false) -> String {
        var tokens: [String] = []
        let baseDuration = section.noteLength // e.g. 16 for 16th note, 4 for quarter note

        for directive in section.directives {
            switch directive.kind {
            case .tempo(let value), .relativeTempo(let value):
                tokens.append("\\tempo 4 = \(Int(value.rounded()))")
            case .timeSignature(let beat):
                tokens.append("\\time \(beat.count)/\(beat.noteValue)")
            case .absoluteKey(let key):
                tokens.append("\\key \(lilyPondKey(key))")
            case .relativeKey:
                tokens.append("% TMD relative key modulation")
            }
        }

        if section.unitGroups.isEmpty {
            return "  r4"
        }

        var localKeyOffset = keyOffset
        var sectionPosition = 0
        var directiveIndex = 0
        let sortedDirectives = section.directives.sorted { $0.position < $1.position }
        for unitGroup in section.unitGroups {
            while directiveIndex < sortedDirectives.count && sortedDirectives[directiveIndex].position == sectionPosition {
                switch sortedDirectives[directiveIndex].kind {
                case .relativeKey(let delta): localKeyOffset += delta
                case .absoluteKey(let key): localKeyOffset = parseKeySignatureSemitones(key)
                default: break
                }
                directiveIndex += 1
            }
            let activeUnits = unitGroup.units.filter { $0 != .tie }

            if activeUnits.isEmpty {
                // Rest
                let dur = formatDuration(noteLength: baseDuration, spanCount: unitGroup.length)
                tokens.append("r\(dur)")
            } else if activeUnits.count == 1 && unitGroup.length == 1 {
                // Single note or chord
                let dur = "\(baseDuration)"
                tokens.append(formatUnit(activeUnits[0], duration: dur, keyOffset: localKeyOffset, percussion: percussion))
            } else {
                // Tuplet or multiple units over span
                let tupletActual = activeUnits.count
                let tupletNormal = unitGroup.length
                let dur = "\(baseDuration)"
                var groupTokens: [String] = []
                for u in activeUnits {
                    groupTokens.append(formatUnit(u, duration: dur, keyOffset: localKeyOffset, percussion: percussion))
                }

                if tupletActual != tupletNormal {
                    tokens.append("\\tuplet \(tupletActual)/\(tupletNormal) { \(groupTokens.joined(separator: " ")) }")
                } else {
                    tokens.append(contentsOf: groupTokens)
                }
            }
            sectionPosition += unitGroup.length
        }

        return "  " + tokens.joined(separator: " ")
    }

    private static func formatUnit(_ unit: TmdSwift.Unit, duration: String, keyOffset: Int, percussion: Bool = false) -> String {
        switch unit {
        case .note(let note):
            let pitchName = noteToLilyPondPitch(note, keyOffset: keyOffset)
            return "\(pitchName)\(duration)"
        case .chord(let chordName):
            // In LilyPond, we can output chord notes in angle brackets <c e g>
            let pitchNames = chordToLilyPondPitches(chordName, keyOffset: keyOffset)
            if pitchNames.isEmpty {
                return "r\(duration)"
            } else if pitchNames.count == 1 {
                return "\(pitchNames[0])\(duration)"
            } else {
                return "<\(pitchNames.joined(separator: " "))>\(duration)"
            }
        case .tie:
            return "r\(duration)"
        case .rest:
            return "r\(duration)"
        case .percussion(let pattern):
            let names = pattern.compactMap { character -> String? in
                switch character {
                case "X", "x": return "hh"
                case "T", "t": return "toml"
                case "S", "s": return "sn"
                default: return nil
                }
            }
            return names.map { "\($0)\(duration)" }.joined(separator: " ")
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

    // MARK: - Pitch & Duration Helpers

    private static func formatDuration(noteLength: Int, spanCount: Int) -> String {
        // Approximate standard durations: 1, 2, 4, 8, 16
        if spanCount == 1 {
            return "\(noteLength)"
        } else if spanCount == 2 && noteLength == 16 {
            return "8"
        } else if spanCount == 4 && noteLength == 16 {
            return "4"
        } else if spanCount == 2 && noteLength == 4 {
            return "2"
        } else if spanCount == 4 && noteLength == 4 {
            return "1"
        }
        return "\(noteLength)"
    }

    private static func noteToLilyPondPitch(_ note: Note, keyOffset: Int) -> String {
        guard note.degree >= 1 && note.degree <= 7 else { return "c'" }
        let scaleSteps = [0, 2, 4, 5, 7, 9, 11]
        var midiPitch = 60 + keyOffset + scaleSteps[note.degree - 1]

        switch note.accidental {
        case .sharp: midiPitch += 1
        case .flat: midiPitch -= 1
        case .natural: break
        }
        midiPitch += note.octave * 12

        return midiPitchToLilyPond(midiPitch)
    }

    private static func chordToLilyPondPitches(_ chordName: String, keyOffset: Int) -> [String] {
        let trimmed = chordName.trimmingCharacters(in: .whitespaces)

        if let firstChar = trimmed.first, firstChar >= "1" && firstChar <= "7" {
            let deg = Int(String(firstChar))!
            let rootPitch = 60 + keyOffset + [0, 2, 4, 5, 7, 9, 11][deg - 1]

            if trimmed.contains("m") && !trimmed.contains("maj") {
                return [midiPitchToLilyPond(rootPitch), midiPitchToLilyPond(rootPitch + 3), midiPitchToLilyPond(rootPitch + 7)]
            } else if trimmed.contains("7") {
                return [midiPitchToLilyPond(rootPitch), midiPitchToLilyPond(rootPitch + 4), midiPitchToLilyPond(rootPitch + 7), midiPitchToLilyPond(rootPitch + 10)]
            } else {
                return [midiPitchToLilyPond(rootPitch), midiPitchToLilyPond(rootPitch + 4), midiPitchToLilyPond(rootPitch + 7)]
            }
        }

        // Standard letter chord
        let letterMap: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        if let first = trimmed.first, let baseSemi = letterMap[Character(first.uppercased())] {
            var root = 48 + baseSemi
            if trimmed.contains("#") || trimmed.contains("'") {
                root += 1
            } else if trimmed.contains("b") || trimmed.contains(",") {
                root -= 1
            }

            if trimmed.contains("m") && !trimmed.contains("maj") {
                return [midiPitchToLilyPond(root), midiPitchToLilyPond(root + 3), midiPitchToLilyPond(root + 7)]
            } else if trimmed.contains("7") {
                return [midiPitchToLilyPond(root), midiPitchToLilyPond(root + 4), midiPitchToLilyPond(root + 7), midiPitchToLilyPond(root + 10)]
            } else {
                return [midiPitchToLilyPond(root), midiPitchToLilyPond(root + 4), midiPitchToLilyPond(root + 7)]
            }
        }

        return ["c'", "e'", "g'"]
    }

    private static func midiPitchToLilyPond(_ pitch: Int) -> String {
        // LilyPond base: c' is Middle C (MIDI 60)
        let noteNames = ["c", "cis", "d", "dis", "e", "f", "fis", "g", "gis", "a", "ais", "b"]
        let semitone = ((pitch % 12) + 12) % 12
        let octave = (pitch / 12) - 1 // Middle C is octave 4 in standard convention, octave 3 in LilyPond reference

        var name = noteNames[semitone]
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

    private static func parseKeySignatureSemitones(_ key: String) -> Int {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return 0 }
        let letterMap: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var semi = letterMap[Character(first.uppercased())] else { return 0 }

        if trimmed.contains("'") || trimmed.contains("#") {
            semi += 1
        } else if trimmed.contains(",") || trimmed.contains("b") {
            semi -= 1
        }
        return semi
    }

    private static func sanitizeIdentifier(_ string: String, index: Int) -> String {
        let filtered = string.filter { $0.isLetter }
        return filtered.isEmpty ? "track\(index + 1)" : filtered
    }

    private static func escapeLilyPond(_ string: String) -> String {
        return string.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
