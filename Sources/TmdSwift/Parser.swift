import Foundation

enum ParserError: Error, CustomStringConvertible {
    case parseError(row: Int, column: Int, message: String)

    var description: String {
        switch self {
        case .parseError(let row, let column, let message):
            return "row: \(row), column: \(column) message: \(message)"
        }
    }
}

final class CharReader {
    private let scalars: [UnicodeScalar]
    private var index: Int = 0

    var c: UnicodeScalar = " "
    var row: Int = 1
    var column: Int = 0

    init(string: String) {
        self.scalars = Array(string.unicodeScalars)
    }

    @discardableResult
    func getChar() -> Bool {
        if index >= scalars.count {
            return false
        }
        c = scalars[index]
        index += 1
        if c == "\n" {
            row += 1
            column = 0
        } else {
            column += 1
        }
        return true
    }

    @discardableResult
    func get(ignores: Set<UnicodeScalar>? = Set("\r\n\t ".unicodeScalars)) -> Bool {
        if let ignores = ignores {
            while getChar() {
                if !ignores.contains(c) {
                    if c == "/" {
                        if !getChar() {
                            unexpectedFileEnding()
                        }
                        if c != "*" {
                            error("Wrong comment format.")
                        }

                        var waitingCommentEnd = false
                        while getChar() {
                            if c == "*" {
                                waitingCommentEnd = true
                            } else if c == "/" {
                                if waitingCommentEnd {
                                    break
                                }
                            } else {
                                waitingCommentEnd = false
                            }
                        }
                        continue
                    }
                    return true
                }
            }
            return false
        } else {
            return getChar()
        }
    }

    func ensureGet(ignores: Set<UnicodeScalar>? = Set("\r\n\t ".unicodeScalars)) {
        if !get(ignores: ignores) {
            unexpectedFileEnding()
        }
    }

    private func ltrim(_ string: String, ignores: Set<UnicodeScalar>) -> String {
        guard let first = string.unicodeScalars.firstIndex(where: { !ignores.contains($0) }) else {
            return ""
        }
        return String(string.unicodeScalars[first...])
    }

    private func rtrim(_ string: String, ignores: Set<UnicodeScalar>) -> String {
        let reversedScalars = string.unicodeScalars.reversed()
        guard let first = reversedScalars.firstIndex(where: { !ignores.contains($0) }) else {
            return ""
        }
        let distance = reversedScalars.distance(from: reversedScalars.startIndex, to: first)
        let endIndex = string.unicodeScalars.index(string.unicodeScalars.endIndex, offsetBy: -distance)
        return String(string.unicodeScalars[..<endIndex])
    }

    func readNullable(skip: Bool = false, until: UnicodeScalar? = nil, ignores: Set<UnicodeScalar> = Set("\r\n\t ".unicodeScalars)) -> String {
        if skip {
            get(ignores: ignores)
        }

        var resultScalars: [UnicodeScalar] = []
        while true {
            if let until = until {
                if c == until {
                    let str = String(String.UnicodeScalarView(resultScalars))
                    return ltrim(rtrim(str, ignores: ignores), ignores: ignores)
                }
            } else {
                if ignores.contains(c) {
                    return String(String.UnicodeScalarView(resultScalars))
                }
            }
            resultScalars.append(c)
            if !getChar() {
                unexpectedFileEnding()
            }
        }
    }

    func read(skip: Bool = false, until: UnicodeScalar? = nil, ignores: Set<UnicodeScalar> = Set("\r\n\t ".unicodeScalars)) -> String {
        let s = readNullable(skip: skip, until: until, ignores: ignores)
        if s.isEmpty {
            error("Unexpected empty string.")
        }
        return s
    }

    func ensure(_ text: String, ignores: Set<UnicodeScalar> = Set("\r\n\t ".unicodeScalars)) {
        for expectedChar in text.unicodeScalars {
            while true {
                ensureGet()
                if !ignores.contains(c) {
                    break
                }
            }
            if c != expectedChar {
                error("Expect \"\(text)\" here.")
            }
        }
    }

    func error(_ message: String) -> Never {
        #if DEBUG
        print("row: \(row), column: \(column) message: \(message)")
        #endif
        preconditionFailure("row: \(row), column: \(column) message: \(message)")
    }

    func unexpectedFileEnding() -> Never {
        error("Unexpected file ending.")
    }

    func unexpectedChar(_ ch: UnicodeScalar? = nil) -> Never {
        let charToReport = ch ?? c
        error("Unexpected char: \(charToReport).")
    }
}

struct TmdParser {
    static let whitespaceAndPipes = Set("\r\n\t |".unicodeScalars)

    private static func readUnitLookedAhead(_ cr: CharReader) -> Unit {
        switch cr.c {
        case "-":
            let unit = Unit(type: .copy)
            cr.ensureGet(ignores: whitespaceAndPipes)
            return unit
        case "[":
            let chordName = cr.read(skip: true, until: "]")
            let unit = Unit(type: .chord, chord: chordName)
            cr.ensureGet(ignores: whitespaceAndPipes)
            return unit
        default:
            var node = Node()
            guard cr.c >= "1" && cr.c <= "7" else {
                cr.unexpectedChar()
            }
            node.name = Int(cr.c.value - UnicodeScalar("0").value)

            while true {
                cr.ensureGet(ignores: whitespaceAndPipes)
                if cr.c == "'" {
                    node.sharpFalls = .sharp
                } else if cr.c == "," {
                    node.sharpFalls = .falls
                } else if cr.c == "^" {
                    node.octave += 1
                } else if cr.c == "_" {
                    node.octave -= 1
                } else {
                    return Unit(type: .node, node: node)
                }
            }
        }
    }

    static func parse(string: String) -> Sheet? {
        let cr = CharReader(string: string)
        return parse(reader: cr)
    }

    static func parse(data: Data) -> Sheet? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parse(string: string)
    }

    private static func parse(reader cr: CharReader) -> Sheet? {
        var sheet = Sheet()
        cr.ensure("::SCORE::")

        while cr.get() {
            switch cr.c {
            case "*":
                cr.ensure("*")
                sheet.name = cr.read(skip: true, until: "*")
                cr.ensure("*")
            case "!":
                cr.ensure("=")
                let speedStr = cr.read(skip: true)
                sheet.speed = Double(speedStr) ?? 0.0
            case "?":
                cr.ensure("=")
                sheet.keySignature = cr.read(skip: true)
            case "<":
                let countStr = cr.read(skip: true, until: "/")
                let nodeStr = cr.read(skip: true, until: ">")
                sheet.beat.count = Int(countStr) ?? sheet.beat.count
                sheet.beat.node = Int(nodeStr) ?? sheet.beat.node
            case "-":
                orderLoop: while true {
                    cr.ensure(">")
                    cr.ensureGet()
                    switch cr.c {
                    case "#":
                        break orderLoop
                    case "{":
                        cr.ensure("?")
                        cr.ensureGet()
                        switch cr.c {
                        case "=":
                            let orderName = cr.read(skip: true, until: "}")
                            sheet.orders.append(Order(type: .absolute, name: orderName))
                        default:
                            let orderName = cr.read(skip: false, until: "}")
                            sheet.orders.append(Order(type: .relative, name: orderName))
                        }
                        cr.ensure("-")
                    default:
                        let orderName = cr.read(skip: false, until: "-")
                        sheet.orders.append(Order(type: .name, name: orderName))
                    }
                }
            default:
                var paragraph = Paragraph()
                paragraph.name = cr.readNullable(skip: false, until: ":")
                paragraph.instrument = cr.read(skip: true, until: "@")

                cr.ensureGet()
                if cr.c == "|" {
                    let startStr = cr.read(skip: true, until: "|")
                    paragraph.start = Int(startStr) ?? 0
                    cr.ensure("{")
                } else if cr.c != "{" {
                    cr.unexpectedChar()
                }

                cr.ensureGet()
                paragraphLoop: while true {
                    switch cr.c {
                    case "<":
                        var section = Section()
                        let nodeLengthStr = cr.read(skip: true, until: "*")
                        section.nodeLength = Int(nodeLengthStr) ?? section.nodeLength
                        cr.ensure(">")

                        cr.ensureGet(ignores: whitespaceAndPipes)
                        while true {
                            if cr.c == "<" || cr.c == "}" {
                                break
                            }

                            var unitGroup = UnitGroup()
                            if cr.c == "(" {
                                cr.ensureGet(ignores: whitespaceAndPipes)
                                while true {
                                    if cr.c == ")" {
                                        break
                                    }
                                    unitGroup.units.append(readUnitLookedAhead(cr))
                                }
                                cr.ensure("%(")
                                unitGroup.length = 0
                                while true {
                                    cr.ensureGet()
                                    if cr.c == ")" {
                                        break
                                    } else if cr.c == "-" {
                                        unitGroup.length += 1
                                    } else {
                                        cr.unexpectedChar()
                                    }
                                }
                                cr.ensureGet(ignores: whitespaceAndPipes)
                            } else {
                                unitGroup.units.append(readUnitLookedAhead(cr))
                            }
                            section.unitGroups.append(unitGroup)
                        }
                        paragraph.sections.append(section)
                    case "}":
                        break paragraphLoop
                    default:
                        cr.unexpectedChar()
                    }
                }
                sheet.paragraphs.append(paragraph)
            }
        }

        return sheet
    }
}
