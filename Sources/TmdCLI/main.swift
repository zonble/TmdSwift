import Foundation
import TmdSwift

let arguments = CommandLine.arguments

guard arguments.count > 1 else {
    print("Usage: tmd <path-to-tmd-file>")
    exit(1)
}

let filePath = arguments[1]
let fileURL = URL(fileURLWithPath: filePath)

do {
    let data = try Data(contentsOf: fileURL)
    guard let sheet = TmdParser.parse(data: data) else {
        print("Error: Failed to parse TMD file at \(filePath)")
        exit(1)
    }

    print("Successfully parsed TMD file!")
    print("----------------------------------------")
    print(sheet.summary())
    print("----------------------------------------")
} catch {
    print("Error reading file: \(error.localizedDescription)")
    exit(1)
}
