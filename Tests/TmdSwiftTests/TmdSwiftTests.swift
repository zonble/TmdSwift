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
    #expect(sheet.keySignature == "C")
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
    #expect(sheet?.keySignature == "G")
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
    #expect(lilyPond.contains("\\time 3/4"))
    #expect(lilyPond.contains("\\new DrumStaff"))
    let abc = TMDABCGenerator.generateABC(from: sheet)
    #expect(abc.contains("Q:1/4=140"))
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
