import Foundation
import TmdUtils

// MARK: - Token Definitions

public enum Token: Equatable {
    case scoreHeader                 // ::SCORE::
    case doubleAsterisk              // **
    case speedPrefix                 // !=
    case keySignaturePrefix          // ?=
    case openAngle                   // <
    case slash                       // /
    case asterisk                    // *
    case closeAngle                  // >
    case colon                       // :
    case at                          // @
    case pipe                        // |
    case openBrace                   // {
    case closeBrace                  // }
    case openParen                   // (
    case closeParen                  // )
    case percentOpenParen            // %(
    case arrow                       // ->
    case arrowEnd                    // ->#
    case relativeOrderPrefix         // {?
    case absoluteOrderPrefix         // {?=

    case number(Int)                 // e.g. 120, 4, 16
    case double(Double)              // e.g. 120.0
    case note(Note)                  // e.g. 1, 1', 1,, 1^, 1_
    case chord(String)               // e.g. [Cmaj7], [1], [6m]
    case tie                         // -
    case identifier(String)          // e.g. Piano, intro, C, A'
    case eof
}

// MARK: - Lexer

public final class Lexer {
    private let scalars: [UnicodeScalar]
    private var index: Int = 0

    public init(string: String) {
        self.scalars = Array(string.unicodeScalars)
    }

    private var isAtEnd: Bool {
        index >= scalars.count
    }

    private func peek(offset: Int = 0) -> UnicodeScalar? {
        let target = index + offset
        guard target >= 0 && target < scalars.count else { return nil }
        return scalars[target]
    }

    @discardableResult
    private func advance() -> UnicodeScalar? {
        guard !isAtEnd else { return nil }
        let c = scalars[index]
        index += 1
        return c
    }

    private func skipWhitespace() {
        while !isAtEnd {
            guard let c = peek() else { break }
            if c == " " || c == "\t" || c == "\r" || c == "\n" {
                advance()
            } else if c == "/" && peek(offset: 1) == "*" {
                // Skip block comment /* ... */
                advance() // /
                advance() // *
                while !isAtEnd {
                    if peek() == "*" && peek(offset: 1) == "/" {
                        advance() // *
                        advance() // /
                        break
                    }
                    advance()
                }
            } else {
                break
            }
        }
    }

    public func tokenize() -> [Token] {
        var tokens: [Token] = []
        while true {
            let token = nextToken()
            tokens.append(token)
            if token == .eof {
                break
            }
        }
        return tokens
    }

    private func nextToken() -> Token {
        skipWhitespace()
        guard let c = peek() else {
            return .eof
        }

        // ::SCORE::
        if c == ":" && peek(offset: 1) == ":" {
            var prefix = ""
            for i in 0..<9 {
                if let ch = peek(offset: i) {
                    prefix.append(Character(ch))
                }
            }
            if prefix == "::SCORE::" {
                for _ in 0..<9 { advance() }
                return .scoreHeader
            }
        }

        // -># or ->
        if c == "-" && peek(offset: 1) == ">" {
            if peek(offset: 2) == "#" {
                advance(); advance(); advance()
                return .arrowEnd
            } else {
                advance(); advance()
                return .arrow
            }
        }

        // {?= or {?
        if c == "{" && peek(offset: 1) == "?" {
            if peek(offset: 2) == "=" {
                advance(); advance(); advance()
                return .absoluteOrderPrefix
            } else {
                advance(); advance()
                return .relativeOrderPrefix
            }
        }

        // %(
        if c == "%" && peek(offset: 1) == "(" {
            advance(); advance()
            return .percentOpenParen
        }

        // != (optional whitespace handled by lexer)
        if c == "!" {
            var offset = 1
            while let sc = peek(offset: offset), sc == " " || sc == "\t" {
                offset += 1
            }
            if peek(offset: offset) == "=" {
                for _ in 0...offset { advance() }
                return .speedPrefix
            }
        }

        // ?= (optional whitespace handled by lexer)
        if c == "?" {
            var offset = 1
            while let sc = peek(offset: offset), sc == " " || sc == "\t" {
                offset += 1
            }
            if peek(offset: offset) == "=" {
                for _ in 0...offset { advance() }
                return .keySignaturePrefix
            }
        }

        // **
        if c == "*" && peek(offset: 1) == "*" {
            advance(); advance()
            return .doubleAsterisk
        }

        // Single character punctuation
        switch c {
        case ":":
            advance()
            return .colon
        case "@":
            advance()
            return .at
        case "|":
            advance()
            return .pipe
        case "{":
            advance()
            return .openBrace
        case "}":
            advance()
            return .closeBrace
        case "(":
            advance()
            return .openParen
        case ")":
            advance()
            return .closeParen
        case "<":
            advance()
            return .openAngle
        case ">":
            advance()
            return .closeAngle
        case "/":
            advance()
            return .slash
        case "*":
            advance()
            return .asterisk
        case "-":
            advance()
            return .tie
        case "[":
            // Chord: [Cmaj7]
            advance() // [
            var chordContent = ""
            while !isAtEnd && peek() != "]" {
                if let ch = advance() {
                    chordContent.append(Character(ch))
                }
            }
            if peek() == "]" {
                advance()
            }
            return .chord(chordContent.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            break
        }

        // Note (1~7 followed by optional ', ,, ^, _)
        if c >= "1" && c <= "7" {
            // Check if it is followed immediately by note modifiers (', ,, ^, _)
            // Or if it's a stand-alone digit not followed by more digits
            let next = peek(offset: 1)
            let isModifier = next == "'" || next == "," || next == "^" || next == "_"
            let isDigit = next.map { $0 >= "0" && $0 <= "9" } ?? false

            if isModifier || !isDigit {
                advance()
                var note = Note()
                note.degree = Int(c.value - UnicodeScalar("0").value)
                while !isAtEnd {
                    guard let mod = peek() else { break }
                    if mod == "'" {
                        note.accidental = .sharp
                        advance()
                    } else if mod == "," {
                        note.accidental = .flat
                        advance()
                    } else if mod == "^" {
                        note.octave += 1
                        advance()
                    } else if mod == "_" {
                        note.octave -= 1
                        advance()
                    } else {
                        break
                    }
                }
                return .note(note)
            }
        }

        // Number (integer or double) or identifier
        if (c >= "0" && c <= "9") || (c == "+" && (peek(offset: 1).map { $0 >= "0" && $0 <= "9" } ?? false)) {
            var numStr = ""
            if c == "+" {
                numStr.append(Character(advance()!))
            }
            var hasDot = false
            while !isAtEnd {
                guard let cur = peek() else { break }
                if cur >= "0" && cur <= "9" {
                    numStr.append(Character(advance()!))
                } else if cur == "." && !hasDot {
                    if let afterDot = peek(offset: 1), afterDot >= "0" && afterDot <= "9" {
                        hasDot = true
                        numStr.append(Character(advance()!))
                    } else {
                        break
                    }
                } else {
                    break
                }
            }

            if hasDot, let d = Double(numStr) {
                return .double(d)
            } else if let i = Int(numStr) {
                return .number(i)
            }
        }

        // Identifier or text token (allows hyphens internal to names like Chorus-1)
        var idStr = ""
        let stops = Set(" \t\r\n:!=?*<>/|{}()[]@#,".unicodeScalars)
        while !isAtEnd {
            guard let cur = peek() else { break }
            if stops.contains(cur) {
                break
            }
            if cur == "-" && (peek(offset: 1) == ">" || peek(offset: 1) == " ") {
                break
            }
            idStr.append(Character(advance()!))
        }

        if !idStr.isEmpty {
            return .identifier(idStr)
        }

        // Fallback: single character identifier
        advance()
        return .identifier(String(Character(c)))
    }
}

// MARK: - Parser

public struct TmdParser {
    /// Parses a TMD score from a text string.
    public static func parse(string: String) -> Sheet? {
        let lexer = Lexer(string: string)
        let tokens = lexer.tokenize()
        var parser = TokenParser(tokens: tokens)
        return parser.parseSheet()
    }

    /// Parses a TMD score from raw byte data, automatically detecting character encoding (UTF-8, Big5, GB18030, etc.).
    public static func parse(data: Data) -> Sheet? {
        guard let result = TextEncodingDetector.detectAndDecode(data) else {
            return nil
        }
        return parse(string: result.content)
    }

    /// Parses a TMD score from a file URL or remote URL.
    public static func parse(url: URL) throws -> Sheet? {
        let data = try Data(contentsOf: url)
        return parse(data: data)
    }

    /// Parses a TMD score from a path string or `file://` URL string, normalizing path and decoding encoding.
    public static func parse(filePathOrURL: String) throws -> Sheet? {
        let cleanPath = FilePathNormalizer.fileURLToPath(filePathOrURL)
        let url = URL(fileURLWithPath: cleanPath)
        return try parse(url: url)
    }
}

private struct TokenParser {
    private let tokens: [Token]
    private var pos: Int = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    private var current: Token {
        if pos < tokens.count {
            return tokens[pos]
        }
        return .eof
    }

    @discardableResult
    private mutating func advance() -> Token {
        let tok = current
        if pos < tokens.count {
            pos += 1
        }
        return tok
    }

    @discardableResult
    private mutating func match(_ expected: Token) -> Bool {
        if current == expected {
            pos += 1
            return true
        }
        return false
    }

    private mutating func skipPipes() {
        while current == .pipe {
            pos += 1
        }
    }

    mutating func parseSheet() -> Sheet? {
        guard match(.scoreHeader) else {
            return nil
        }

        var sheet = Sheet()

        while current != .eof {
            switch current {
            case .doubleAsterisk:
                advance()
                // Name may consist of multiple tokens until next doubleAsterisk
                var nameParts: [String] = []
                while current != .doubleAsterisk && current != .eof {
                    switch advance() {
                    case .identifier(let s): nameParts.append(s)
                    case .number(let n): nameParts.append(String(n))
                    case .note(let note): nameParts.append(String(note.degree))
                    default: break
                    }
                }
                match(.doubleAsterisk)
                sheet.name = nameParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)

            case .speedPrefix:
                advance()
                if case .double(let d) = current {
                    sheet.speed = d
                    advance()
                } else if case .number(let n) = current {
                    sheet.speed = Double(n)
                    advance()
                }

            case .keySignaturePrefix:
                advance()
                var key = ""
                if case .identifier(let s) = current {
                    key = s
                    advance()
                } else if case .note(let note) = current {
                    key = String(note.degree)
                    advance()
                }
                sheet.keySignature = key

            case .openAngle:
                advance()
                if case .number(let c) = current {
                    sheet.beat.count = c
                    advance()
                } else if case .note(let note) = current {
                    sheet.beat.count = note.degree
                    advance()
                }
                match(.slash)
                if case .number(let n) = current {
                    sheet.beat.noteValue = n
                    advance()
                } else if case .note(let note) = current {
                    sheet.beat.noteValue = note.degree
                    advance()
                }
                match(.closeAngle)

            case .arrow:
                advance()
                switch current {
                case .arrowEnd:
                    advance()
                    return sheet
                case .relativeOrderPrefix:
                    advance()
                    var name = ""
                    while current != .closeBrace && current != .eof {
                        switch advance() {
                        case .identifier(let s): name += s
                        case .number(let n): name += String(n)
                        case .note(let note): name += String(note.degree)
                        case .tie: name += "-"
                        default: break
                        }
                    }
                    match(.closeBrace)
                    sheet.orders.append(.relative(name))
                case .absoluteOrderPrefix:
                    advance()
                    var name = ""
                    while current != .closeBrace && current != .eof {
                        switch advance() {
                        case .identifier(let s): name += s
                        case .number(let n): name += String(n)
                        case .note(let note): name += String(note.degree)
                        case .tie: name += "-"
                        default: break
                        }
                    }
                    match(.closeBrace)
                    sheet.orders.append(.absolute(name))
                case .identifier(let s):
                    advance()
                    sheet.orders.append(.name(s))
                default:
                    advance()
                }

            case .arrowEnd:
                advance()
                return sheet

            default:
                // Paragraph: name:instrument@|start|{ ... }
                if let paragraph = parseParagraph() {
                    sheet.paragraphs.append(paragraph)
                } else {
                    advance()
                }
            }
        }

        return sheet
    }

    private mutating func parseParagraph() -> Paragraph? {
        var name = ""
        if case .identifier(let s) = current {
            name = s
            advance()
        }

        guard match(.colon) else { return nil }

        var instrument = ""
        if case .identifier(let s) = current {
            instrument = s
            advance()
        }

        guard match(.at) else { return nil }

        var start = 0
        if match(.pipe) {
            if case .number(let n) = current {
                start = n
                advance()
            } else if case .note(let note) = current {
                start = note.degree
                advance()
            }
            match(.pipe)
        }

        guard match(.openBrace) else { return nil }

        var sections: [Section] = []
        while current != .closeBrace && current != .eof {
            skipPipes()
            if current == .openAngle {
                advance()
                var noteLength = 4
                if case .number(let n) = current {
                    noteLength = n
                    advance()
                } else if case .note(let note) = current {
                    noteLength = note.degree
                    advance()
                }
                match(.asterisk)
                match(.closeAngle)

                var unitGroups: [UnitGroup] = []
                while current != .openAngle && current != .closeBrace && current != .eof {
                    skipPipes()
                    if current == .openAngle || current == .closeBrace || current == .eof {
                        break
                    }

                    if match(.openParen) {
                        skipPipes()
                        var groupUnits: [Unit] = []
                        while current != .closeParen && current != .eof {
                            skipPipes()
                            if current == .closeParen { break }
                            if let unit = parseUnit() {
                                groupUnits.append(unit)
                            } else {
                                advance()
                            }
                        }
                        match(.closeParen)

                        var length = 1
                        if match(.percentOpenParen) {
                            length = 0
                            while current == .tie {
                                length += 1
                                advance()
                            }
                            match(.closeParen)
                        }
                        unitGroups.append(UnitGroup(units: groupUnits, length: length))
                    } else if let unit = parseUnit() {
                        unitGroups.append(UnitGroup(units: [unit], length: 1))
                    } else {
                        advance()
                    }
                }
                sections.append(Section(noteLength: noteLength, unitGroups: unitGroups))
            } else {
                advance()
            }
        }
        match(.closeBrace)

        return Paragraph(name: name, instrument: instrument, start: start, sections: sections)
    }

    private mutating func parseUnit() -> Unit? {
        skipPipes()
        switch current {
        case .note(let n):
            advance()
            return .note(n)
        case .chord(let ch):
            advance()
            return .chord(ch)
        case .tie:
            advance()
            return .tie
        default:
            return nil
        }
    }
}
