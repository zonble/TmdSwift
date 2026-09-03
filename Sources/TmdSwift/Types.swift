/// Time signature of the piece (e.g. `<4/4>` or `<3/4>`).
///
/// > Note: Originally named `Beat` in Aguai's C++ code, where the denominator
/// > was named `node`.
public struct Beat: Equatable {
    /// Number of beats per measure (numerator), e.g. `4` in `4/4`.
    ///
    /// > Note: Originally named `count` in Aguai's C++ code.
    public var count: Int = 4

    /// Unit note value representing one beat (denominator / beat unit), e.g.
    /// `4` for a quarter note.
    ///
    /// > Note: Originally named `node` in Aguai's C++ code (likely a typo for
    /// > `note`).
    public var noteValue: Int = 4

    public init(count: Int = 4, noteValue: Int = 4) {
        self.count = count
        self.noteValue = noteValue
    }
}

/// Accidental symbol modifying the pitch (natural, sharp, or flat).
///
/// > Note: Originally named `SharpFalls` in Aguai's C++ code, where flat was
/// > named `Falls`.
public enum Accidental: Equatable {
    /// Natural pitch (unaltered).
    ///
    /// > Note: Originally named `SharpFalls::Normal` in Aguai's C++ code.
    case natural

    /// Sharp accidental (syntax denoted by `'`).
    ///
    /// > Note: Originally named `SharpFalls::Sharp` in Aguai's C++ code.
    case sharp

    /// Flat accidental (syntax denoted by `,`).
    ///
    /// > Note: Originally named `SharpFalls::Falls` in Aguai's C++ code.
    case flat
}

/// A musical note containing scale degree (1~7), accidental, and octave displacement.
///
/// > Note: Originally named `Node` in Aguai's C++ code (likely a typo for `Note`).
public struct Note: Equatable {
    /// Accidental of the note.
    ///
    /// > Note: Originally named `sharpFalls` in Aguai's C++ code.
    public var accidental: Accidental = .natural

    /// Numbered musical notation scale degree (`1` to `7` representing Do
    /// through Ti).
    ///
    /// > Note: Originally named `name` (as `int`) in Aguai's C++ code.
    public var degree: Int = 0

    /// Octave displacement. Positive numbers shift octaves higher (syntax `^`),
    /// negative lower (syntax `_`).
    ///
    /// > Note: Originally named `octave` in Aguai's C++ code.
    public var octave: Int = 0

    public init(accidental: Accidental = .natural, degree: Int = 0, octave: Int = 0) {
        self.accidental = accidental
        self.degree = degree
        self.octave = octave
    }
}

/// The atomic musical unit, which can be a single note, a chord, or a tie/dash.
///
/// > Note: Originally implemented as `Unit` struct with `UnitType` enum in
/// > Aguai's C++ code.
public enum Unit: Equatable {
    /// A single note.
    ///
    /// > Note: Originally represented as `UnitType::Node` in Aguai's C++ code.
    case note(Note)

    /// A chord symbol enclosed in square brackets (e.g. `[Cmaj7]`, `[1]`,
    /// `[6m]`).
    ///
    /// > Note: Originally represented as `UnitType::Chord` in Aguai's C++ code.
    case chord(String)

    /// A tie or duration extension dash (syntax `-`).
    ///
    /// > Note: Originally represented as `UnitType::Copy` in Aguai's C++ code.
    case tie

    /// A rest. The source syntax is `0`; repeated dashes may extend it.
    case rest

    /// A percussion pattern using the original TMD character vocabulary.
    case percussion(String)
}

/// A rhythmic unit group or tuplet grouping.
///
/// Represents either a standalone unit or multiple units compressed into a
/// defined beat duration (e.g. `(7, 1)%(--)`).
///
/// > Note: Originally named `UnitGroup` in Aguai's C++ code.
public struct UnitGroup: Equatable {
    /// List of musical units (notes, chords, ties) in this group.
    ///
    /// > Note: Originally named `units` in Aguai's C++ code.
    public var units: [Unit] = []

    /// Duration in section base beats that this group spans (e.g. `%(--)` spans
    /// 2 base beats).
    ///
    /// > Note: Originally named `length` in Aguai's C++ code.
    public var length: Int = 1

    public init(units: [Unit] = [], length: Int = 1) {
        self.units = units
        self.length = length
    }
}

/// A local change in tempo, key, or meter occurring inside a section.
public enum SectionDirectiveKind: Equatable {
    case tempo(Double)
    case relativeTempo(Double)
    case absoluteKey(String)
    case relativeKey(Int)
    case timeSignature(Beat)
}

public struct SectionDirective: Equatable {
    /// Position measured in section base units, before the directive.
    public var position: Int
    public var kind: SectionDirectiveKind

    public init(position: Int, kind: SectionDirectiveKind) {
        self.position = position
        self.kind = kind
    }
}

/// A section or measure segment defining base note subdivision (e.g. `<16*>`)
/// and unit groups.
///
/// > Note: Originally named `Section` in Aguai's C++ code.
public struct Section: Equatable {
    /// Base subdivision note length (e.g. `4` for quarter-note grid, `16` for
    /// sixteenth-note grid `<16*>`).
    ///
    /// > Note: Originally named `nodeLength` in Aguai's C++ code (likely a typo
    /// > for `noteLength`).
    public var noteLength: Int = 4

    /// Unit groups contained in this section.
    ///
    /// > Note: Originally named `unitGroups` in Aguai's C++ code.
    public var unitGroups: [UnitGroup] = []

    public var directives: [SectionDirective] = []

    public init(noteLength: Int = 4, unitGroups: [UnitGroup] = [], directives: [SectionDirective] = []) {
        self.noteLength = noteLength
        self.unitGroups = unitGroups
        self.directives = directives
    }
}

/// A multi-track voice or instrument paragraph, formatted as
/// `name:instrument@|start|{ ... }`.
///
/// Represents an instrument track's musical score within a specific song
/// section and its entry measure offset.
///
/// > Note: Originally named `Paragraph` in Aguai's C++ code.
public struct Paragraph: Equatable {
    /// Paragraph/section name (e.g. `intro`, `A`, `bridge`).
    ///
    /// > Note: Originally named `name` in Aguai's C++ code.
    public var name: String = ""

    /// Instrument or track name (e.g. `Guitar`, `CHORD`, `Piano`).
    ///
    /// > Note: Originally named `instrument` in Aguai's C++ code.
    public var instrument: String = ""

    /// Measure start offset (e.g. `@|0|` starts at measure 0, `@|+4|` starts at
    /// measure 4).
    ///
    /// > Note: Originally named `start` in Aguai's C++ code.
    public var start: Int = 0

    /// Section list contained within this paragraph.
    ///
    /// > Note: Originally named `sections` in Aguai's C++ code.
    public var sections: [Section] = []

    /// Optional show-program time marker used by executable/non-musical blocks.
    public var executionTime: String?

    /// Raw body of a show-program block enclosed by triple quotes.
    public var showProgram: String?

    public init(name: String = "", instrument: String = "", start: Int = 0, sections: [Section] = [], executionTime: String? = nil, showProgram: String? = nil) {
        self.name = name
        self.instrument = instrument
        self.start = start
        self.sections = sections
        self.executionTime = executionTime
        self.showProgram = showProgram
    }
}

/// Playback order and modulation instructions directing song flow.
///
/// Example syntax: `-> intro -> A -> {?-3} -> C ->#`.
///
/// > Note: Originally named `Order` and `OrderType` in Aguai's C++ code (where
/// > relative was typoed as `releative`).
public enum Order: Equatable {
    /// Plays the paragraph matching the given name (e.g. `-> intro`, `-> A`).
    ///
    /// > Note: Originally named `OrderType::Name` in Aguai's C++ code.
    case name(String)

    /// Relative key modulation (e.g. `{?+3}` modulates up 3 semitones, `{?-3}`
    /// modulates down 3 semitones).
    ///
    /// > Note: Originally named `OrderType::Relative` in Aguai's C++ code
    /// > (previously typoed as `releative`).
    case relative(String)

    /// Absolute key modulation (e.g. `{?=C}`).
    ///
    /// > Note: Originally named `OrderType::Absolute` in Aguai's C++ code.
    case absolute(String)
}

/// The complete TMD score sheet.
///
/// Contains song title, tempo, key signature, time signature, instrument
/// paragraphs, and arrangement playback orders.
///
/// > Note: Originally named `Sheet` in Aguai's C++ code.
public struct Sheet: Equatable {
    /// Song title (syntax enclosed in `** Title **`).
    ///
    /// > Note: Originally named `name` in Aguai's C++ code.
    public var name: String = ""

    /// Playback tempo in BPM (syntax denoted by `!= 133`).
    ///
    /// > Note: Originally named `speed` in Aguai's C++ code.
    public var speed: Double = 0.0

    /// Initial key signature (syntax denoted by `?= A'`).
    ///
    /// > Note: Originally named `keySignature` in Aguai's C++ code.
    public var keySignature: String = "C"

    /// Time signature (syntax denoted by `<4/4>`).
    ///
    /// > Note: Originally named `beat` in Aguai's C++ code.
    public var beat: Beat = Beat()

    /// All instrument paragraphs defined across the sheet.
    ///
    /// > Note: Originally named `paragraphs` in Aguai's C++ code.
    public var paragraphs: [Paragraph] = []

    /// Song structure playback order sequence.
    ///
    /// > Note: Originally named `orders` in Aguai's C++ code.
    public var orders: [Order] = []

    /// Song-level metadata such as lyrics, composer, and arranger credits.
    public var metadata: [String: String] = [:]

    public init(
        name: String = "",
        speed: Double = 0.0,
        keySignature: String = "C",
        beat: Beat = Beat(),
        paragraphs: [Paragraph] = [],
        orders: [Order] = [],
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.speed = speed
        self.keySignature = keySignature
        self.beat = beat
        self.paragraphs = paragraphs
        self.orders = orders
        self.metadata = metadata
    }
}
