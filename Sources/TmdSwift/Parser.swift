import Foundation

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
    case node(Node)                  // e.g. 1, 1', 1,, 1^, 1_
    case chord(String)               // e.g. [Cmaj7], [1], [6m]
    case copy                        // -
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
            return .copy
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

        // Node (1~7 followed by optional ', ^, _)
        if c >= "1" && c <= "7" {
            // Check if it is followed immediately by node modifiers (', ,, ^, _)
            // Or if it's a stand-alone digit not followed by more digits
            let next = peek(offset: 1)
            let isModifier = next == "'" || next == "," || next == "^" || next == "_"
            let isDigit = next.map { $0 >= "0" && $0 <= "9" } ?? false

            if isModifier || !isDigit {
                advance()
                var node = Node()
                node.name = Int(c.value - UnicodeScalar("0").value)
                while !isAtEnd {
                    guard let mod = peek() else { break }
                    if mod == "'" {
                        node.sharpFalls = .sharp
                        advance()
                    } else if mod == "," {
                        node.sharpFalls = .falls
                        advance()
                    } else if mod == "^" {
                        node.octave += 1
                        advance()
                    } else if mod == "_" {
                        node.octave -= 1
                        advance()
                    } else {
                        break
                    }
                }
                return .node(node)
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
    public static func parse(string: String) -> Sheet? {
        let lexer = Lexer(string: string)
        let tokens = lexer.tokenize()
        var parser = TokenParser(tokens: tokens)
        return parser.parseSheet()
    }

    public static func parse(data: Data) -> Sheet? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parse(string: string)
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
                    case .node(let node): nameParts.append(String(node.name))
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
                } else if case .node(let node) = current {
                    key = String(node.name)
                    advance()
                }
                sheet.keySignature = key

            case .openAngle:
                advance()
                if case .number(let c) = current {
                    sheet.beat.count = c
                    advance()
                } else if case .node(let node) = current {
                    sheet.beat.count = node.name
                    advance()
                }
                match(.slash)
                if case .number(let n) = current {
                    sheet.beat.node = n
                    advance()
                } else if case .node(let node) = current {
                    sheet.beat.node = node.name
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
                        case .copy: name += "-"
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
                        case .copy: name += "-"
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
            } else if case .node(let node) = current {
                start = node.name
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
                var nodeLength = 4
                if case .number(let n) = current {
                    nodeLength = n
                    advance()
                } else if case .node(let node) = current {
                    nodeLength = node.name
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
                            while current == .copy {
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
                sections.append(Section(nodeLength: nodeLength, unitGroups: unitGroups))
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
        case .node(let n):
            advance()
            return .node(n)
        case .chord(let ch):
            advance()
            return .chord(ch)
        case .copy:
            advance()
            return .copy
        default:
            return nil
        }
    }
}
