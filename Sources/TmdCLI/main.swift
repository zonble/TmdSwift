import Foundation
import ArgumentParser
import TmdSwift
import TmdMIDI

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

    func run() throws {
        let fileURL = URL(fileURLWithPath: inputPath)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            print("Error: Could not read file at \(inputPath): \(error.localizedDescription)")
            throw ExitCode.failure
        }

        guard let sheet = TmdParser.parse(data: data) else {
            print("Error: Failed to parse TMD file at \(inputPath)")
            throw ExitCode.failure
        }

        print("Successfully parsed TMD file: \(inputPath)")
        print("----------------------------------------")
        print(sheet.summary())
        print("----------------------------------------")

        if parseOnly {
            return
        }

        // Determine MIDI output path if specified or if user wants MIDI
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
    }
}

TmdCLICommand.main()
