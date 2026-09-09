import Testing
import Foundation
@testable import TmdSwift
import TmdMusicXML

@Suite("MusicXML Validation Tests")
struct MusicXMLValidationTests {

    @Test func testMusicXMLWellFormedXML() throws {
        let sampleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sample/basic/三天三夜.tmd")
        let data = try Data(contentsOf: sampleURL)
        let sheet = try TmdParser.parseThrowing(data: data)

        let xml = TMDMusicXMLGenerator.generateMusicXML(from: sheet)
        let xmlData = Data(xml.utf8)

        #if canImport(FoundationXML) || os(macOS)
        let doc = try XMLDocument(data: xmlData, options: [])
        #expect(doc.rootElement()?.name == "score-partwise")
        #endif
    }

    @Test func testMusicXMLMeasureDurationsConserved() throws {
        let tmd = """
        ::SCORE::
        ** Measure Invariant Test **
        != 120
        ?= C
        <4/4>

        A:Piano@|0|{
            <4*>
            1 2 3 -
            1 - - -
            1 2 3 4
        }
        -> A ->#
        """
        let sheet = try TmdParser.parseThrowing(string: tmd)

        let xml = TMDMusicXMLGenerator.generateMusicXML(from: sheet)
        let xmlData = Data(xml.utf8)

        #if canImport(FoundationXML) || os(macOS)
        let doc = try XMLDocument(data: xmlData, options: [])
        guard let root = doc.rootElement() else {
            Issue.record("No root element")
            return
        }

        let divisions = 16
        let expectedMeasureDuration = 4 * divisions // 4 beats * 16 = 64

        let parts = root.elements(forName: "part")
        #expect(!parts.isEmpty)
        for part in parts {
            let measures = part.elements(forName: "measure")
            #expect(!measures.isEmpty)
            for (idx, measure) in measures.enumerated() {
                var totalDuration = 0
                for child in measure.children ?? [] {
                    guard let el = child as? XMLElement, el.name == "note" else { continue }
                    if el.elements(forName: "chord").first != nil { continue }
                    if let durStr = el.elements(forName: "duration").first?.stringValue,
                       let dur = Int(durStr) {
                        totalDuration += dur
                    }
                }
                #expect(
                    totalDuration == expectedMeasureDuration,
                    "Measure \(idx + 1) in part \(part.attribute(forName: "id")?.stringValue ?? "") duration \(totalDuration) does not equal expected \(expectedMeasureDuration)"
                )
            }
        }
        #endif
    }

    @Test func testMusicXMLMuseScoreCLIImport() throws {
        let whichMScore = Process()
        whichMScore.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichMScore.arguments = ["mscore"]
        let pipe = Pipe()
        whichMScore.standardOutput = pipe
        try? whichMScore.run()
        whichMScore.waitUntilExit()

        var mscorePath: String?
        if whichMScore.terminationStatus == 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let output, !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) {
                mscorePath = output
            }
        }
        if mscorePath == nil && FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/mscore") {
            mscorePath = "/opt/homebrew/bin/mscore"
        }

        guard let executable = mscorePath else {
            return
        }

        let sampleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sample/basic/三天三夜.tmd")
        let sheet = try TmdParser.parseThrowing(url: sampleURL)

        let xml = TMDMusicXMLGenerator.generateMusicXML(from: sheet)
        let tempXMLURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mscore_test_\(UUID().uuidString).musicxml")
        let tempOutURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mscore_test_\(UUID().uuidString).pdf")

        defer {
            try? FileManager.default.removeItem(at: tempXMLURL)
            try? FileManager.default.removeItem(at: tempOutURL)
        }

        try xml.write(to: tempXMLURL, atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = ["-o", tempOutURL.path, tempXMLURL.path]
        try proc.run()
        proc.waitUntilExit()

        #expect(
            FileManager.default.fileExists(atPath: tempOutURL.path),
            "mscore failed to generate PDF output file"
        )
        let outputSize = (try? Data(contentsOf: tempOutURL).count) ?? 0
        #expect(outputSize > 100, "mscore output PDF is empty or invalid (size: \(outputSize) bytes)")
    }
}
