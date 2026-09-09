import Testing
import Foundation
@testable import TmdSwift
import TmdLilyPond

@Suite("LilyPond Validation Tests")
struct LilyPondValidationTests {

    @Test func testLilyPondUniqueIdentifiers() throws {
        let sampleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sample/basic/三天三夜.tmd")
        let sheet = try TmdParser.parseThrowing(url: sampleURL)

        let ly = TMDLilyPondGenerator.generateLilyPond(from: sheet)

        let lines = ly.components(separatedBy: "\n")
        var definedVariables: [String] = []
        let regex = try NSRegularExpression(pattern: #"^([A-Za-z][A-Za-z0-9_]*)\s*=\s*(?:\\drummode\s*)?\{"#)

        for line in lines {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            if let match = matches.first {
                let varName = nsLine.substring(with: match.range(at: 1))
                if varName != "global" {
                    definedVariables.append(varName)
                }
            }
        }

        #expect(!definedVariables.isEmpty)
        let uniqueVariables = Set(definedVariables)
        #expect(
            uniqueVariables.count == definedVariables.count,
            "Found duplicate LilyPond variable identifiers: \(definedVariables)"
        )
    }

    @Test func testLilyPondValidDurationsOnly() throws {
        let sampleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sample/basic/三天三夜.tmd")
        let sheet = try TmdParser.parseThrowing(url: sampleURL)

        let ly = TMDLilyPondGenerator.generateLilyPond(from: sheet)

        let tokenRegex = try NSRegularExpression(pattern: #"(?:[a-g][a-z',]*|>|r|hh|sn|toml)(\d+)(\.*)"#)
        let nsLy = ly as NSString
        let matches = tokenRegex.matches(in: ly, range: NSRange(location: 0, length: nsLy.length))

        let validDurations: Set<Int> = [1, 2, 4, 8, 16, 32, 64, 128]
        var invalidMatches: [String] = []

        for match in matches {
            let durString = nsLy.substring(with: match.range(at: 1))
            if let dur = Int(durString), !validDurations.contains(dur) {
                invalidMatches.append(nsLy.substring(with: match.range))
            }
        }

        #expect(
            invalidMatches.isEmpty,
            "LilyPond generated invalid duration tokens (non-powers-of-2): \(invalidMatches.prefix(10))"
        )
    }

    @Test func testLilyPondMeasureBarlinesPresent() throws {
        let tmd = """
        ::SCORE::
        ** Barline Test **
        != 120
        ?= C
        <4/4>

        A:Piano@|0|{
            <4*>
            1 2 3 4
            5 6 7 1^
        }
        -> A ->#
        """
        let sheet = try TmdParser.parseThrowing(string: tmd)

        let ly = TMDLilyPondGenerator.generateLilyPond(from: sheet)
        let barlineCount = ly.components(separatedBy: "|").count - 1
        #expect(barlineCount >= 2, "Expected at least 2 barlines in multi-measure LilyPond score, got \(barlineCount)")
    }
}
