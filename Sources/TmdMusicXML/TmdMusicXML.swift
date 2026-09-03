import Foundation
import TmdSwift

/// MusicXML generator for TMD Sheets.
///
/// Exports the Sheet AST into W3C MusicXML (Partwise) format for use with notation software
/// such as MuseScore, Finale, Sibelius, Dorico, or web renderers like OpenSheetMusicDisplay.
public struct TMDMusicXMLGenerator {

    /// Generates MusicXML UTF-8 string from a Sheet.
    public static func generateMusicXML(from sheet: Sheet) -> String {
        let metadataCreators = sheet.metadata.sorted { $0.key < $1.key }.map { key, value in
            let type = key.lowercased() == "lyrics" ? "lyricist" : (key.lowercased() == "arranger" ? "arranger" : "composer")
            return "    <creator type=\"\(type)\">\(escapeXML(value))</creator>"
        }.joined(separator: "\n")
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work>
            <work-title>\(escapeXML(sheet.name.isEmpty ? "Untitled Score" : sheet.name))</work-title>
          </work>
          <identification>
            <creator type="composer">TMD</creator>
        \(metadataCreators)
            <encoding>
              <software>TmdSwift MusicXML Exporter</software>
            </encoding>
          </identification>

        """

        let distinctInstruments = Array(Set(sheet.paragraphs.map { $0.instrument })).sorted()
        let instruments = distinctInstruments.isEmpty ? ["Piano"] : distinctInstruments

        // Part List
        xml += "  <part-list>\n"
        for (idx, inst) in instruments.enumerated() {
            let partID = "P\(idx + 1)"
            xml += """
                <score-part id="\(partID)">
                  <part-name>\(escapeXML(inst))</part-name>
                </score-part>

            """
        }
        xml += "  </part-list>\n"

        // Order flow
        let orders: [Order]
        if sheet.orders.isEmpty {
            let uniqueNames = Set(sheet.paragraphs.map { $0.name })
            orders = sheet.paragraphs.map { $0.name }.filter { uniqueNames.contains($0) }.map { Order.name($0) }
        } else {
            orders = sheet.orders
        }

        let divisions = 16 // 16 divisions per quarter note gives high subdivision precision

        // Generate <part> for each instrument
        for (idx, inst) in instruments.enumerated() {
            let partID = "P\(idx + 1)"
            xml += "  <part id=\"\(partID)\">\n"
            xml += generatePartMeasures(
                instrument: inst,
                sheet: sheet,
                orders: orders,
                divisions: divisions
            )
            xml += "  </part>\n"
        }

        xml += "</score-partwise>\n"
        return xml
    }

    private static func generatePartMeasures(
        instrument: String,
        sheet: Sheet,
        orders: [Order],
        divisions: Int
    ) -> String {
        var xml = ""
        var measureNumber = 1
        let rootOffset = sheet.keySignature.semitoneOffset
        var currentModulation = 0

        // Divisions per beat (quarter note) = divisions
        // Duration of one quarter note = divisions
        let beatsPerMeasure = sheet.beat.count
        let noteValue = sheet.beat.noteValue > 0 ? sheet.beat.noteValue : 4
        let measureDivisions = (divisions * 4 * beatsPerMeasure) / noteValue

        for order in orders {
            switch order {
            case .relative(let rel):
                if let delta = Int(rel.replacingOccurrences(of: "+", with: "")) {
                    currentModulation += delta
                }
            case .absolute(let abs):
                currentModulation = KeySignature(string: abs).semitoneOffset - rootOffset
            case .name(let paragraphName):
                let matchingParagraph = sheet.paragraphs.first(where: { $0.name == paragraphName && $0.instrument == instrument })

                guard let paragraph = matchingParagraph else {
                    // Empty measure for this instrument
                    xml += generateEmptyMeasure(
                        measureNumber: measureNumber,
                        measureDivisions: measureDivisions,
                        sheet: sheet,
                        divisions: divisions,
                        isFirstMeasure: measureNumber == 1
                    )
                    measureNumber += 1
                    continue
                }

                let totalKeyOffset = rootOffset + currentModulation

                for (sIdx, section) in paragraph.sections.enumerated() {
                    let isFirstOverall = (measureNumber == 1 && sIdx == 0)
                    xml += generateSectionMeasure(
                        section: section,
                        measureNumber: measureNumber,
                        measureDivisions: measureDivisions,
                        keyOffset: totalKeyOffset,
                        sheet: sheet,
                        divisions: divisions,
                        isFirstMeasure: isFirstOverall
                    )
                    measureNumber += 1
                }
            }
        }

        if measureNumber == 1 {
            // Ensure at least one measure exists
            xml += generateEmptyMeasure(
                measureNumber: 1,
                measureDivisions: measureDivisions,
                sheet: sheet,
                divisions: divisions,
                isFirstMeasure: true
            )
        }

        return xml
    }

    private static func generateEmptyMeasure(
        measureNumber: Int,
        measureDivisions: Int,
        sheet: Sheet,
        divisions: Int,
        isFirstMeasure: Bool
    ) -> String {
        var m = "    <measure number=\"\(measureNumber)\">\n"
        if isFirstMeasure {
            m += generateAttributesXML(sheet: sheet, divisions: divisions)
        }
        m += """
                <note>
                  <rest measure="yes"/>
                  <duration>\(measureDivisions)</duration>
                </note>
            </measure>

        """
        return m
    }

    private static func generateSectionMeasure(
        section: Section,
        measureNumber: Int,
        measureDivisions: Int,
        keyOffset: Int,
        sheet: Sheet,
        divisions: Int,
        isFirstMeasure: Bool
    ) -> String {
        var m = "    <measure number=\"\(measureNumber)\">\n"
        if isFirstMeasure {
            m += generateAttributesXML(sheet: sheet, divisions: divisions)
        }
        m += generateDirectivesXML(section.directives)

        let baseNoteDivisions = (divisions * 4) / max(1, section.noteLength)

        if section.unitGroups.isEmpty {
            m += """
                    <note>
                      <rest measure="yes"/>
                      <duration>\(measureDivisions)</duration>
                    </note>

            """
        } else {
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
                let groupDivisions = unitGroup.length * baseNoteDivisions
                let activeUnits = unitGroup.units.filter { $0 != .tie }

                if activeUnits.isEmpty {
                    // Rest
                    m += """
                            <note>
                              <rest/>
                              <duration>\(groupDivisions)</duration>
                            </note>

                    """
                } else {
                    let subDuration = max(1, groupDivisions / activeUnits.count)
                    for unit in activeUnits {
                        switch unit {
                        case .note(let note):
                            m += generateNoteXML(note: note, duration: subDuration, keyOffset: localKeyOffset)
                        case .chord(let chordName):
                            m += generateChordXML(chordName: chordName.description, duration: subDuration, keyOffset: localKeyOffset)
                        case .tie:
                            break
                        case .rest:
                            m += """
                                    <note>
                                      <rest/>
                                      <duration>\(subDuration)</duration>
                                    </note>

                            """
                        case .percussion(let pattern):
                            m += generatePercussionXML(pattern: pattern, duration: subDuration)
                        }
                    }
                }
                sectionPosition += unitGroup.length
            }
        }

        m += "    </measure>\n"
        return m
    }

    private static func generateDirectivesXML(_ directives: [SectionDirective]) -> String {
        var result = ""
        for directive in directives {
            switch directive.kind {
            case .tempo(let value), .relativeTempo(let value):
                result += """
                        <direction placement="above">
                          <direction-type>
                            <metronome>
                              <beat-unit>quarter</beat-unit>
                              <per-minute>\(Int(value.rounded()))</per-minute>
                            </metronome>
                          </direction-type>
                          <sound tempo="\(value)"/>
                        </direction>

                """
            case .timeSignature(let beat):
                result += """
                        <attributes>
                          <time>
                            <beats>\(beat.count)</beats>
                            <beat-type>\(beat.noteValue)</beat-type>
                          </time>
                        </attributes>

                """
            case .absoluteKey(let key):
                result += "        <attributes><key><fifths>\(keySignatureToFifths(key))</fifths></key></attributes>\n"
            case .relativeKey:
                result += "        <!-- TMD relative key modulation -->\n"
            }
        }
        return result
    }

    private static func generatePercussionXML(pattern: String, duration: Int) -> String {
        let notes = pattern.compactMap { character -> (String, Int)? in
            switch character {
            case "X", "x": return ("F", 5) // closed hi-hat, MIDI 42
            case "T", "t": return ("A", 4) // low tom, MIDI 45
            case "S", "s": return ("D", 5) // snare, MIDI 38
            default: return nil
            }
        }
        let noteDuration = max(1, duration / max(1, notes.count))
        return notes.map { step, octave in
            """
                    <note>
                      <unpitched>
                        <display-step>\(step)</display-step>
                        <display-octave>\(octave)</display-octave>
                      </unpitched>
                      <duration>\(noteDuration)</duration>
                    </note>

            """
        }.joined()
    }

    private static func generateAttributesXML(sheet: Sheet, divisions: Int) -> String {
        return """
              <attributes>
                <divisions>\(divisions)</divisions>
                <key>
                  <fifths>\(keySignatureToFifths(sheet.keySignature.description))</fifths>
                </key>
                <time>
                  <beats>\(sheet.beat.count)</beats>
                  <beat-type>\(sheet.beat.noteValue)</beat-type>
                </time>
                <clef>
                  <sign>G</sign>
                  <line>2</line>
                </clef>
              </attributes>
              <direction placement="above">
                <direction-type>
                  <metronome>
                    <beat-unit>quarter</beat-unit>
                    <per-minute>\(Int(sheet.speed > 0 ? sheet.speed : 120))</per-minute>
                  </metronome>
                </direction-type>
                <sound tempo="\(Int(sheet.speed > 0 ? sheet.speed : 120))"/>
              </direction>

        """
    }

    private static func generateNoteXML(note: Note, duration: Int, keyOffset: Int) -> String {
        let (step, alter, octave) = pitchToStepAlterOctave(note: note, keyOffset: keyOffset)
        var xml = """
                <note>
                  <pitch>
                    <step>\(step)</step>

        """
        if alter != 0 {
            xml += "            <alter>\(alter)</alter>\n"
        }
        xml += """
                    <octave>\(octave)</octave>
                  </pitch>
                  <duration>\(duration)</duration>
                </note>

        """
        return xml
    }

    private static func generateChordXML(chordName: String, duration: Int, keyOffset: Int) -> String {
        // Output chord harmony symbol & note representation
        let xml = """
              <harmony>
                <root>
                  <root-step>\(escapeXML(chordName))</root-step>
                </root>
                <kind text="\(escapeXML(chordName))">other</kind>
              </harmony>
              <note>
                <rest/>
                <duration>\(duration)</duration>
              </note>

        """
        return xml
    }

    // MARK: - Musical Conversion Helpers

    private static func pitchToStepAlterOctave(note: Note, keyOffset: Int) -> (step: String, alter: Int, octave: Int) {
        let degree = note.degree.rawValue
        guard (1...7).contains(degree) else { return ("C", 0, 4) }
        var midiPitch = 60 + keyOffset + note.degree.semitoneOffset
        switch note.accidental {
        case .sharp: midiPitch += 1
        case .flat: midiPitch -= 1
        case .natural: break
        }
        midiPitch += note.octave * 12

        // Convert MIDI pitch to Step + Alter + Octave
        let semitone = ((midiPitch % 12) + 12) % 12
        let step = PitchMapping.musicXMLSteps[semitone]
        let alter = PitchMapping.musicXMLAlters[semitone]
        let octave = (midiPitch / 12) - 1

        return (step, alter, octave)
    }

    private static func keySignatureToFifths(_ key: String) -> Int {
        let trimmed = key.trimmingCharacters(in: .whitespaces).uppercased()
        switch trimmed {
        case "C": return 0
        case "G": return 1
        case "D": return 2
        case "A": return 3
        case "E": return 4
        case "B": return 5
        case "F#", "F'": return 6
        case "F": return -1
        case "BB", "B,": return -2
        case "EB", "E,": return -3
        case "AB", "A,", "A'": return 3 // A major = 3 sharps
        case "DB", "D,": return -5
        case "GB", "G,": return -6
        default: return 0
        }
    }

    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
