import Testing
import Foundation
@testable import TmdSwift

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
    #expect(sheet.beat.node == 4)

    #expect(sheet.paragraphs.count == 1)
    let paragraph = sheet.paragraphs[0]
    #expect(paragraph.name == "intro")
    #expect(paragraph.instrument == "Piano")
    #expect(paragraph.start == 0)
    #expect(paragraph.sections.count == 1)

    let section = paragraph.sections[0]
    #expect(section.nodeLength == 4)
    #expect(section.unitGroups.count == 7)

    // 1 2 3 4
    #expect(section.unitGroups[0].units[0].type == .node)
    #expect(section.unitGroups[0].units[0].node.name == 1)
    #expect(section.unitGroups[1].units[0].node.name == 2)
    #expect(section.unitGroups[2].units[0].node.name == 3)
    #expect(section.unitGroups[3].units[0].node.name == 4)

    // (1' 2, 3^ 4_)%(--)
    let group5 = section.unitGroups[4]
    #expect(group5.length == 2)
    #expect(group5.units.count == 4)
    #expect(group5.units[0].node.name == 1 && group5.units[0].node.sharpFalls == .sharp)
    #expect(group5.units[1].node.name == 2 && group5.units[1].node.sharpFalls == .falls)
    #expect(group5.units[2].node.name == 3 && group5.units[2].node.octave == 1)
    #expect(group5.units[3].node.name == 4 && group5.units[3].node.octave == -1)

    // [Cmaj7]
    let group6 = section.unitGroups[5]
    #expect(group6.units[0].type == .chord)
    #expect(group6.units[0].chord == "Cmaj7")

    // -
    let group7 = section.unitGroups[6]
    #expect(group7.units[0].type == .copy)

    // Orders
    #expect(sheet.orders.count == 3)
    #expect(sheet.orders[0].type == .name)
    #expect(sheet.orders[0].name == "intro")
    #expect(sheet.orders[1].type == .relative)
    #expect(sheet.orders[1].name == "relative_part")
    #expect(sheet.orders[2].type == .absolute)
    #expect(sheet.orders[2].name == "absolute_part")
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
    #expect(sheet?.beat.node == 4)
}

