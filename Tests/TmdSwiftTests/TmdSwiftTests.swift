import Testing
import Foundation
@testable import TmdSwift
import TmdMIDI
import TmdMusicXML
import TmdLilyPond
import TmdUtils
import TmdAudio
import TmdABC

@Test func testParseTMDScore() throws {
    let tmd = """
    ::SCORE::
    /* Comment block */
    ** Test Song **
    != 120.0
    ?= C
    <4/4>

    intro:Piano@|0|{
        <4*>
        1 2 3 4
        (1' 2, 3^ 4_)%(--)
        [Cmaj7] -
    }

    -> intro -> {?relative_part} -> {?=absolute_part} ->#
    """

    let sheet = TmdParser.parse(string: tmd)
    #expect(sheet != nil)
    guard let sheet = sheet else { return }

    #expect(sheet.name == "Test Song")
    #expect(sheet.speed == 120.0)
    #expect(sheet.keySignature == KeySignature(tonic: .c))
    #expect(sheet.beat.count == 4)
    #expect(sheet.beat.noteValue == 4)

    #expect(sheet.paragraphs.count == 1)
    let paragraph = sheet.paragraphs[0]
    #expect(paragraph.name == "intro")
    #expect(paragraph.instrument == "Piano")
    #expect(paragraph.start == 0)
    #expect(paragraph.sections.count == 1)

    let section = paragraph.sections[0]
    #expect(section.noteLength == 4)
    #expect(section.unitGroups.count == 7)

    // 1 2 3 4
    #expect(section.unitGroups[0].units[0] == .note(Note(accidental: .natural, degree: 1, octave: 0)))
    #expect(section.unitGroups[1].units[0] == .note(Note(accidental: .natural, degree: 2, octave: 0)))
    #expect(section.unitGroups[2].units[0] == .note(Note(accidental: .natural, degree: 3, octave: 0)))
    #expect(section.unitGroups[3].units[0] == .note(Note(accidental: .natural, degree: 4, octave: 0)))

    // (1' 2, 3^ 4_)%(--)
    let group5 = section.unitGroups[4]
    #expect(group5.length == 2)
    #expect(group5.units.count == 4)
    #expect(group5.units[0] == .note(Note(accidental: .sharp, degree: 1, octave: 0)))
    #expect(group5.units[1] == .note(Note(accidental: .flat, degree: 2, octave: 0)))
    #expect(group5.units[2] == .note(Note(accidental: .natural, degree: 3, octave: 1)))
    #expect(group5.units[3] == .note(Note(accidental: .natural, degree: 4, octave: -1)))

    // [Cmaj7]
    let group6 = section.unitGroups[5]
    #expect(group6.units[0] == .chord("Cmaj7"))

    // -
    let group7 = section.unitGroups[6]
    #expect(group7.units[0] == .tie)

    // Orders
    #expect(sheet.orders.count == 3)
    #expect(sheet.orders[0] == .name("intro"))
    #expect(sheet.orders[1] == .relative("relative_part"))
    #expect(sheet.orders[2] == .absolute("absolute_part"))
}

@Test func testParseData() throws {
    let tmd = "::SCORE::\n** Song **\n!=90\n?=G\n<3/4>\n->#"
    let data = Data(tmd.utf8)
    let sheet = TmdParser.parse(data: data)
    #expect(sheet != nil)
    #expect(sheet?.name == "Song")
    #expect(sheet?.speed == 90.0)
    #expect(sheet?.keySignature == KeySignature(tonic: .g))
    #expect(sheet?.beat.count == 3)
    #expect(sheet?.beat.noteValue == 4)
}

@Test func testTokenize() throws {
    let text = "::SCORE:: ** Title ** != 120 ?= C <4/4> ->#"
    let tokens = Lexer(string: text).tokenize()
    #expect(tokens == [
        .scoreHeader,
        .doubleAsterisk,
        .identifier("Title"),
        .doubleAsterisk,
        .speedPrefix,
        .number(120),
        .keySignaturePrefix,
        .identifier("C"),
        .openAngle,
        .note(Note(accidental: .natural, degree: 4, octave: 0)),
        .slash,
        .note(Note(accidental: .natural, degree: 4, octave: 0)),
        .closeAngle,
        .arrowEnd,
        .eof
    ])
}

@Test func testTokenRanges() throws {
    let tokens = Lexer(string: "::SCORE::\n** Song **").tokenizeWithRanges()
    #expect(tokens[0].text == "::SCORE::")
    #expect(tokens[0].range.start.line == 1)
    #expect(tokens[0].range.start.column == 1)
    #expect(tokens[1].text == "**")
    #expect(tokens[1].range.start.line == 2)
    #expect(tokens[1].range.start.column == 1)
}

@Test func testThrowingParserReportsOffendingToken() throws {
    do {
        _ = try TmdParser.parseThrowing(string: "not-a-score")
        Issue.record("Expected a parse error")
    } catch let error as TMDParseError {
        #expect(error.text == "not-a-score")
        #expect(error.range.start.line == 1)
        #expect(error.range.start.column == 1)
        #expect(error.description.contains("not-a-score"))
    }
}

@Test func testThrowingParserRejectsMalformedParagraph() throws {
    do {
        _ = try TmdParser.parseThrowing(string: "::SCORE::\nintro")
        Issue.record("Expected a parse error")
    } catch let error as TMDParseError {
        #expect(error.text == "intro")
        #expect(error.range.start.line == 2)
    }
}

@Test func testParseSampleFile() throws {
    let sampleURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("sample/三天三夜.tmd")
    let data = try Data(contentsOf: sampleURL)
    let sheet = TmdParser.parse(data: data)
    #expect(sheet != nil)
    #expect(sheet?.name == "三天三夜")
    #expect(sheet?.speed == 133.0)
    #expect(sheet?.beat.count == 4)
    #expect(sheet?.beat.noteValue == 4)
    #expect(sheet?.paragraphs.count == 10)
    #expect(sheet?.orders.count == 13)

    // Verify summary()
    let summaryText = sheet?.summary() ?? ""
    #expect(summaryText.contains("三天三夜"))
    #expect(summaryText.contains("133.0 BPM"))

    // Verify format() roundtrip parsing
    let formattedTMD = sheet?.format() ?? ""
    let reparsed = TmdParser.parse(string: formattedTMD)
    #expect(reparsed != nil)
    #expect(reparsed?.name == sheet?.name)
    #expect(reparsed?.speed == sheet?.speed)
    #expect(reparsed?.paragraphs.count == sheet?.paragraphs.count)
    #expect(reparsed?.orders.count == sheet?.orders.count)

    // Verify MIDI generation
    if let validSheet = sheet {
        let midi = TMDMIDIGenerator.generateMIDI(from: validSheet)
        #expect(!midi.isEmpty)
        #expect(midi.starts(with: [0x4D, 0x54, 0x68, 0x64])) // "MThd"

        // Verify MusicXML generation
        let xml = TMDMusicXMLGenerator.generateMusicXML(from: validSheet)
        #expect(xml.contains("score-partwise"))
        #expect(xml.contains("三天三夜"))
        #expect(xml.contains("<part-list>"))
        #expect(xml.contains("</score-partwise>"))

        // Verify LilyPond generation
        let ly = TMDLilyPondGenerator.generateLilyPond(from: validSheet)
        #expect(ly.contains("\\version"))
        #expect(ly.contains("三天三夜"))
        #expect(ly.contains("\\score"))
        #expect(ly.contains("\\new Staff"))
    }
}

@Test func testFileURLAndEncoding() throws {
    let sampleURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("sample/三天三夜.tmd")

    // Test URL parsing
    let sheetFromURL = try TmdParser.parse(url: sampleURL)
    #expect(sheetFromURL != nil)
    #expect(sheetFromURL?.name == "三天三夜")

    // Test file:// string parsing with percent-encoding
    let fileURLString = sampleURL.absoluteString
    #expect(FilePathNormalizer.isFileURL(fileURLString))
    let sheetFromFileURL = try TmdParser.parse(filePathOrURL: fileURLString)
    #expect(sheetFromFileURL != nil)
    #expect(sheetFromFileURL?.name == "三天三夜")

    // Test Big5 encoded data detection
    let tmdBig5 = """
    ::SCORE::
    ** 測試Big5 **
    != 120
    ?= C
    <4/4>
    intro:鋼琴@|0|{
    <4*>
    1 2 3 4
    }
    -> intro ->#
    """
    if let big5Data = tmdBig5.data(using: .big5) {
        let sheetBig5 = TmdParser.parse(data: big5Data)
        #expect(sheetBig5 != nil)
        #expect(sheetBig5?.name == "測試Big5")
        #expect(sheetBig5?.paragraphs.first?.instrument == "鋼琴")
    }
}

#if os(macOS)
@Test func testAudioRendering() throws {
    let tmd = """
    ::SCORE::
    ** Audio Test **
    != 140
    ?= C
    <4/4>
    intro:Piano@|0|{
    <4*>
    1 2 3 4
    }
    -> intro ->#
    """
    guard let sheet = TmdParser.parse(string: tmd) else {
        Issue.record("Failed to parse audio test score")
        return
    }

    let wavData = try TMDWAVRenderer.renderWAV(from: sheet)
    #expect(!wavData.isEmpty)
    #expect(wavData.starts(with: [0x52, 0x49, 0x46, 0x46])) // "RIFF"
}
#endif

@Test func testABCGeneration() throws {
    let tmd = """
    ::SCORE::
    ** ABC Test **
    != 120
    ?= C
    <4/4>
    intro:Piano@|0|{
    <4*>
    1 2 3 4
    }
    -> intro ->#
    """
    guard let sheet = TmdParser.parse(string: tmd) else {
        Issue.record("Failed to parse ABC test score")
        return
    }

    let abc = TMDABCGenerator.generateABC(from: sheet)
    #expect(abc.contains("X:1"))
    #expect(abc.contains("T:ABC Test"))
    #expect(abc.contains("M:4/4"))
    #expect(abc.contains("K:C"))
    #expect(abc.contains("V:V1 name=\"Piano\""))
}

@Test func testExtendedTMDSyntax() throws {
    let tmd = """
    ::SCORE::
    ** Extended **
    != 120
    ?= C
    <4/4>
    ~ "詞：阿怪"
    =~:__ARR__= "編曲者"

    A:Vocal@|-1|{
        <16*>
        0--- 1 2 3
        {!= 140}
        {!+10}
        {?+2}
        {<3/4>}
    }
    A:Drums@|0|{
        <16*>
        XsTt x--
    }
    -> A ->#
    """

    let sheet = TmdParser.parse(string: tmd)
    #expect(sheet != nil)
    guard let sheet else { return }

    #expect(sheet.metadata["lyrics"] == "詞：阿怪")
    #expect(TmdParser.parse(string: "::SCORE::\n~ \"曲：作曲者\"\n->#")?.metadata["composer"] == "曲：作曲者")
    #expect(TmdParser.parse(string: "::SCORE::\n~ \"編：編曲者\"\n->#")?.metadata["arranger"] == "編：編曲者")
    #expect(sheet.metadata["ARR"] == "編曲者")
    #expect(sheet.paragraphs[0].start == -1)
    #expect(sheet.paragraphs[0].sections[0].unitGroups[0].units[0] == .rest)
    #expect(sheet.paragraphs[1].sections[0].unitGroups[0].units[0] == .percussion("XsTt"))
    #expect(sheet.paragraphs[0].sections[0].directives == [
        SectionDirective(position: 7, kind: .tempo(140)),
        SectionDirective(position: 7, kind: .relativeTempo(10)),
        SectionDirective(position: 7, kind: .relativeKey(2)),
        SectionDirective(position: 7, kind: .timeSignature(Beat(count: 3, noteValue: 4)))
    ])

    let reparsed = TmdParser.parse(string: sheet.format())
    #expect(reparsed?.metadata == sheet.metadata)
    #expect(reparsed?.paragraphs[0].start == -1)
    #expect(reparsed?.paragraphs[0].sections[0].directives == sheet.paragraphs[0].sections[0].directives)

    let midi = TMDMIDIGenerator.generateMIDI(from: sheet)
    #expect(midi.contains(0x99))
    #expect(midi.contains(0x51)) // tempo meta event
    #expect(midi.contains(0x58)) // time-signature meta event
    #expect(midi.range(of: Data([0xFF, 0x51, 0x03, 0x06, 0x1A, 0x80])) != nil) // 150 BPM
    let musicXML = TMDMusicXMLGenerator.generateMusicXML(from: sheet)
    #expect(musicXML.contains("<per-minute>140</per-minute>"))
    #expect(musicXML.contains("<beats>3</beats>"))
    #expect(musicXML.contains("<unpitched>"))
    let lilyPond = TMDLilyPondGenerator.generateLilyPond(from: sheet)
    #expect(lilyPond.contains("\\tempo 4 = 140"))
    #expect(lilyPond.contains("\\tempo 4 = 150"))
    #expect(lilyPond.contains("\\time 3/4"))
    #expect(lilyPond.contains("\\new DrumStaff"))
    let abc = TMDABCGenerator.generateABC(from: sheet)
    #expect(abc.contains("Q:1/4=140"))
    #expect(abc.contains("Q:1/4=150"))
    #expect(abc.contains("M:3/4"))
    #expect(abc.contains("%%MIDI channel 10"))
}

@Test func testLegacySectionMarkerSyntax() throws {
    let tmd = """
    ::SCORE:: ** Legacy ** != 120 ?= C <4/4>
    A:Piano@{ <*1> 1 2 3 4 }
    -> A ->#
    """

    let sheet = TmdParser.parse(string: tmd)
    #expect(sheet != nil)
    #expect(sheet?.paragraphs.first?.sections.first?.noteLength == 1)
}

@Test func testShowProgramBlock() throws {
    let tmd = #"""
    ::SCORE::
    ** Show **
    show:Lighting@intro{
    """
    cue black
    wait 4
    """
    }
    -> show ->#
    """#

    let sheet = TmdParser.parse(string: tmd)
    #expect(sheet?.paragraphs.first?.executionTime == "intro")
    #expect(sheet?.paragraphs.first?.instrument == "Lighting")
    #expect(sheet?.paragraphs.first?.showProgram?.contains("cue black") == true)
    #expect(sheet?.format().contains("\"\"\"") == true)
    #expect(sheet?.format().contains("cue black") == true)
}

@Test func testScaleDegreeEnum() throws {
    #expect(ScaleDegree.c.rawValue == 1)
    #expect(ScaleDegree.d.rawValue == 2)
    #expect(ScaleDegree.e.rawValue == 3)
    #expect(ScaleDegree.f.rawValue == 4)
    #expect(ScaleDegree.g.rawValue == 5)
    #expect(ScaleDegree.a.rawValue == 6)
    #expect(ScaleDegree.b.rawValue == 7)
    #expect(ScaleDegree(rawValue: 0) == nil)
    #expect(ScaleDegree(rawValue: 8) == nil)
    #expect(Note().degree == .c)
    #expect(Note(degree: 5).degree == .g)
    #expect(Note(degree: .a).format() == "6")

    let sharp = KeySignature(string: "A'")
    #expect(sharp.tonic == .a)
    #expect(sharp.accidental == .sharp)
    #expect(sharp.description == "A'")
    let flat = KeySignature(string: "E,")
    #expect(flat.tonic == .e)
    #expect(flat.accidental == .flat)
    #expect(flat.description == "E,")
    #expect(KeySignature(string: "not-a-key") == KeySignature(tonic: .c))
}

@Test func testTypedChordSymbol() throws {
    let majorSeventh: ChordSymbol = "Cmaj7"
    #expect(majorSeventh.root == ChordRoot(degree: .c))
    #expect(majorSeventh.quality == .major7)
    #expect(majorSeventh.description == "Cmaj7")

    let movableMinor: ChordSymbol = "6m"
    #expect(movableMinor.root == ChordRoot(degree: .a, isScaleDegree: true))
    #expect(movableMinor.quality == .minor)
    #expect(movableMinor.description == "6m")

    let extended = ChordSymbol(string: "C7#9")
    #expect(extended.quality == .custom("7#9"))
    #expect(extended.description == "C7#9")
}

@Test func testSharedPitchMappings() throws {
    #expect(ScaleDegree.c.semitoneOffset == 0)
    #expect(ScaleDegree.f.semitoneOffset == 5)
    #expect(PitchMapping.musicXMLSteps[10] == "A")
    #expect(PitchMapping.musicXMLAlters[10] == 1)
    #expect(PitchMapping.lilyPondNames[11] == "b")
    #expect(PitchMapping.abcLowerNames[1] == "^c")
}

@Test func testPlaybackTimeline() throws {
    let section = Section(
        noteLength: 4,
        unitGroups: [
            UnitGroup(units: [.note(Note(degree: .c))], length: 1),
            UnitGroup(units: [.rest], length: 2)
        ],
        directives: [
            SectionDirective(position: 1, kind: .relativeTempo(10)),
            SectionDirective(position: 1, kind: .relativeKey(2))
        ]
    )
    let sheet = Sheet(
        speed: 100,
        paragraphs: [Paragraph(name: "intro", instrument: "Piano", start: 1, sections: [section])],
        orders: [.name("intro")]
    )

    let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: "Piano")
    #expect(timeline.events.count == 2)
    #expect(timeline.events[0].position == 4)
    #expect(timeline.events[1].position == 5)
    #expect(timeline.events[1].duration == 2)
    #expect(timeline.events[1].state == PlaybackState(tempo: 110, keyOffset: 2, timeSignature: Beat()))
    #expect(timeline.directives.map(\.position) == [5, 5])
}

@Test func testFilePathNormalizerVariants() throws {
    #expect(FilePathNormalizer.isFileURL(" file:///tmp/a%20b "))
    #expect(FilePathNormalizer.isFileURL("<file://localhost/tmp/a>"))
    #expect(!FilePathNormalizer.isFileURL("/tmp/a"))
    #expect(FilePathNormalizer.fileURLToPath("file:///tmp/a%20b") == "/tmp/a b")
    #expect(FilePathNormalizer.fileURLToPath("file://localhost/tmp/a") == "/tmp/a")
    #expect(FilePathNormalizer.fileURLToPath("file:C:/Users/test") == "C:/Users/test")
    #expect(FilePathNormalizer.fileURLToPath("/tmp/plain") == "/tmp/plain")

    let anchor = FilePathNormalizer.parseLocation(from: "score.tmd#L42C10")
    #expect(anchor.filePath == "score.tmd")
    #expect(anchor.line == 42)
    #expect(anchor.column == 10)

    let colonAnchor = FilePathNormalizer.parseLocation(from: "score.tmd:42:10")
    #expect(colonAnchor.filePath == "score.tmd")
    #expect(colonAnchor.line == 42)
    #expect(colonAnchor.column == 10)

    let urlAnchor = FilePathNormalizer.parseLocation(from: "file:///tmp/score.tmd#L7")
    #expect(urlAnchor.filePath == "/tmp/score.tmd")
    #expect(urlAnchor.line == 7)
    #expect(urlAnchor.column == nil)

    let windows = FilePathNormalizer.parseLocation(from: "C:/score.tmd:12:4")
    #expect(windows.filePath == "C:/score.tmd")
    #expect(windows.line == 12)
    #expect(windows.column == 4)

    let empty = FilePathNormalizer.parseLocation(from: "   ")
    #expect(empty.filePath.isEmpty)
    #expect(empty.line == nil)
}

@Test func testTextEncodingDetectorVariants() throws {
    let empty = TextEncodingDetector.detectAndDecode(Data())
    #expect(empty?.content == "")
    #expect(TextEncodingDetector.displayName(for: .utf8) == "UTF-8")
    #expect(TextEncodingDetector.displayName(for: .big5) == "Big5")
    #expect(TextEncodingDetector.displayName(for: .gb18030) == "GB18030")
    #expect(TextEncodingDetector.displayName(for: .shiftJISCustom) == "Shift-JIS")
    #expect(TextEncodingDetector.displayName(for: .eucJPCustom) == "EUC-JP")

    let utf8BOM = Data([0xEF, 0xBB, 0xBF]) + Data("測試".utf8)
    #expect(TextEncodingDetector.detectAndDecode(utf8BOM)?.content == "測試")

    let utf16LE = Data([0xFF, 0xFE]) + ("測試".data(using: .utf16LittleEndian) ?? Data())
    #expect(TextEncodingDetector.detectAndDecode(utf16LE)?.content == "測試")
    let utf16BE = Data([0xFE, 0xFF]) + ("測試".data(using: .utf16BigEndian) ?? Data())
    #expect(TextEncodingDetector.detectAndDecode(utf16BE)?.content == "測試")

    let utf32LE = Data([0xFF, 0xFE, 0x00, 0x00]) + ("TMD".data(using: .utf32LittleEndian) ?? Data())
    #expect(TextEncodingDetector.detectAndDecode(utf32LE)?.content == "TMD")
}

@Test func testExporterFallbackBranches() throws {
    let sheet = Sheet(
        name: "Fallback",
        speed: 0,
        keySignature: "?",
        beat: Beat(count: 0, noteValue: 0),
        paragraphs: [Paragraph(name: "A", instrument: "Unknown", sections: [
            Section(noteLength: 8, unitGroups: [
                UnitGroup(units: [.note(Note(degree: .c)), .chord("???")], length: 2),
                UnitGroup(units: [], length: 1)
            ])
        ])],
        orders: [.name("A"), .name("Missing")]
    )

    #expect(!TMDMIDIGenerator.generateMIDI(from: sheet).isEmpty)
    #expect(TMDMIDIGenerator.noteToMIDIPitch(Note(degree: .c), keyOffset: 0) == 60)
    #expect(!TMDMIDIGenerator.chordToMIDIPitches("???", keyOffset: 0).isEmpty)
    #expect(TMDMIDIGenerator.generalMidiProgram(for: "Unknown") == 0)
    #expect(MIDIInstrument.resolve("Unknown") == .unknown)
    #expect(MIDIInstrument.resolve("Unknown").program == 0)
    #expect(MIDIInstrument.resolve("Chorus-1") == .choir)
    #expect(MIDIInstrument.resolve("Groove").isPercussion)
    #expect(TMDMusicXMLGenerator.generateMusicXML(from: sheet).contains("score-partwise"))
    #expect(TMDLilyPondGenerator.generateLilyPond(from: sheet).contains("\\score"))
    #expect(TMDABCGenerator.generateABC(from: sheet).contains("T:Fallback"))
}

@Test func testNegativeParagraphStartOffset() throws {
    let tmd = """
    ::SCORE::
    ** Negative Offset Test **
    != 120
    ?= C
    <4/4>

    intro:Piano@|0|{
        <4*>
        1 2 3 4
    }

    v1:Piano@|-1|{
        <4*>
        5 6 7 1^
    }

    -> intro -> v1 ->#
    """

    let sheet = try TmdParser.parseThrowing(string: tmd)
    #expect(sheet.paragraphs.count == 2)
    #expect(sheet.paragraphs[0].start == 0)
    #expect(sheet.paragraphs[1].start == -1)

    let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: "Piano")
    #expect(!timeline.events.isEmpty)

    // intro starts at measure 0 (4 quarter notes: 0.0, 1.0, 2.0, 3.0).
    // v1 is ordered after intro, but with start = -1 (one measure = 4 beats earlier),
    // so v1 starts at 4.0 - 4.0 = 0.0 (overlapping with intro!).
    let v1Notes = timeline.events.filter { event in
        if case .note(let n) = event.content { return n.degree == .g }
        return false
    }
    #expect(!v1Notes.isEmpty)
    #expect(v1Notes[0].position == 0.0)

    // Also verify MIDI generator doesn't crash or overflow
    let midi = TMDMIDIGenerator.generateMIDI(from: sheet)
    #expect(!midi.isEmpty)
}

@Test func testTieExtendsNoteDuration() throws {
    let tmd = """
    ::SCORE::
    ** Tie Half Note Test **
    != 120
    ?= C
    <4/4>

    intro:Piano@|0|{
        <4*>
        3 - 1 - - -
    }

    -> intro ->#
    """

    let sheet = try TmdParser.parseThrowing(string: tmd)
    let timeline = TMDPlaybackRenderer.render(sheet: sheet, instrument: "Piano")

    // In <4*>, 3 - should be a half note (duration = 2.0 quarter notes).
    // 1 - - - should be a whole note (duration = 4.0 quarter notes).
    let noteEvents = timeline.events.filter {
        if case .note = $0.content { return true }
        return false
    }
    #expect(noteEvents.count == 2)
    #expect(noteEvents[0].duration == 2.0)
    #expect(noteEvents[1].duration == 4.0)
}


