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
    print("Name:         \(sheet.name)")
    print("Speed:        \(sheet.speed) BPM")
    print("KeySignature: \(sheet.keySignature)")
    print("Beat:         \(sheet.beat.count)/\(sheet.beat.noteValue)")
    print("Paragraphs:   \(sheet.paragraphs.count)")
    for (idx, p) in sheet.paragraphs.enumerated() {
        let secCount = p.sections.count
        let totalUnits = p.sections.reduce(0) { $0 + $1.unitGroups.count }
        print("  [\(idx + 1)] \(p.name) (Instrument: \(p.instrument), Start: \(p.start), Sections: \(secCount), UnitGroups: \(totalUnits))")
    }
    print("Orders:       \(sheet.orders.count)")
    for (idx, order) in sheet.orders.enumerated() {
        switch order {
        case .name(let name):
            print("  [\(idx + 1)] -> \(name)")
        case .relative(let rel):
            print("  [\(idx + 1)] -> {?\(rel)}")
        case .absolute(let abs):
            print("  [\(idx + 1)] -> {?=\(abs)}")
        }
    }
    print("----------------------------------------")
} catch {
    print("Error reading file: \(error.localizedDescription)")
    exit(1)
}
