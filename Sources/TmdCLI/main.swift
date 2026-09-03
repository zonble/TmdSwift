import Foundation
import ArgumentParser
import TmdSwift
import TmdMIDI
import TmdMusicXML
import TmdLilyPond
import TmdAudio

struct TmdCLICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tmd",
        abstract: "A compiler and toolkit for the TMD music markup language."
    )

    @Argument(help: "Path to the .tmd file to process.")
    var inputPath: String

    @Flag(name: [.short, .long], help: "Only parse and display the score structure summary.")
    var parseOnly: Bool = false

    @Option(name: [.short, .long], help: "Export to MIDI file at the specified path.")
    var midiOutput: String?

    @Option(name: [.customShort("x"), .long], help: "Export to MusicXML file at the specified path.")
    var musicxmlOutput: String?

    @Option(name: [.customShort("l"), .long], help: "Export to LilyPond (.ly) file at the specified path.")
    var lilypondOutput: String?

    @Option(name: [.long], help: "Render PDF score using lilypond compiler.")
    var pdfOutput: String?

    @Option(name: [.customShort("w"), .long], help: "Render to WAV audio file at the specified path.")
    var wavOutput: String?

    @Option(name: [.long], help: "Optional SoundFont (.sf2) or DLS soundbank path for audio rendering.")
    var soundfont: String?

    func run() throws {
        let sheet: Sheet
        do {
            guard let parsed = try TmdParser.parse(filePathOrURL: inputPath) else {
                print("Error: Failed to parse TMD file at \(inputPath)")
                throw ExitCode.failure
            }
            sheet = parsed
        } catch {
            print("Error: Could not read or decode file at \(inputPath): \(error.localizedDescription)")
            throw ExitCode.failure
        }

        print("Successfully parsed TMD file: \(inputPath)")
        print("----------------------------------------")
        print(sheet.summary())
        print("----------------------------------------")

        if parseOnly {
            return
        }

        // Export to MIDI if requested
        if let outputPath = midiOutput {
            let midiData = TMDMIDIGenerator.generateMIDI(from: sheet)
            let outURL = URL(fileURLWithPath: outputPath)
            do {
                try midiData.write(to: outURL)
                print("MIDI exported successfully to \(outputPath) (\(midiData.count) bytes)")
            } catch {
                print("Error saving MIDI to \(outputPath): \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        // Export to MusicXML if requested
        if let xmlPath = musicxmlOutput {
            let xmlString = TMDMusicXMLGenerator.generateMusicXML(from: sheet)
            let outURL = URL(fileURLWithPath: xmlPath)
            do {
                try xmlString.write(to: outURL, atomically: true, encoding: .utf8)
                print("MusicXML exported successfully to \(xmlPath) (\(xmlString.utf8.count) bytes)")
            } catch {
                print("Error saving MusicXML to \(xmlPath): \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        // Export to LilyPond if requested
        if let lyPath = lilypondOutput {
            let lyString = TMDLilyPondGenerator.generateLilyPond(from: sheet)
            let outURL = URL(fileURLWithPath: lyPath)
            do {
                try lyString.write(to: outURL, atomically: true, encoding: .utf8)
                print("LilyPond exported successfully to \(lyPath) (\(lyString.utf8.count) bytes)")
            } catch {
                print("Error saving LilyPond file to \(lyPath): \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        // Render to PDF using lilypond command line if requested
        if let pdfPath = pdfOutput {
            let tempLyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".ly")
            let lyString = TMDLilyPondGenerator.generateLilyPond(from: sheet)
            try? lyString.write(to: tempLyURL, atomically: true, encoding: .utf8)

            let pdfBase = pdfPath.hasSuffix(".pdf") ? String(pdfPath.dropLast(4)) : pdfPath
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["lilypond", "--pdf", "-o", pdfBase, tempLyURL.path]

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    print("PDF rendered successfully via LilyPond to \(pdfPath)")
                } else {
                    print("Warning: lilypond exited with status \(process.terminationStatus). Make sure lilypond is installed (e.g. `brew install lilypond`).")
                }
            } catch {
                print("Could not invoke lilypond: \(error.localizedDescription). You can export the .ly file directly using `-l`.")
            }
            try? FileManager.default.removeItem(at: tempLyURL)
        }

        // Render to WAV audio if requested
        if let wavPath = wavOutput {
            let soundBankURL = soundfont != nil ? URL(fileURLWithPath: soundfont!) : nil
            do {
                let wavData = try TMDWAVRenderer.renderWAV(from: sheet, soundBankURL: soundBankURL)
                let outURL = URL(fileURLWithPath: wavPath)
                try wavData.write(to: outURL)
                print("WAV rendered successfully to \(wavPath) (\(wavData.count) bytes)")
            } catch {
                print("Error rendering WAV audio: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}

TmdCLICommand.main()
