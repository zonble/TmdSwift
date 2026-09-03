public struct Beat: Equatable {
    public var count: Int = 4
    public var node: Int = 4

    public init(count: Int = 4, node: Int = 4) {
        self.count = count
        self.node = node
    }
}

public enum SharpFalls: Equatable {
    case normal
    case sharp
    case falls
}

public struct Node: Equatable {
    public var sharpFalls: SharpFalls = .normal
    public var name: Int = 0
    public var octave: Int = 0

    public init(sharpFalls: SharpFalls = .normal, name: Int = 0, octave: Int = 0) {
        self.sharpFalls = sharpFalls
        self.name = name
        self.octave = octave
    }
}

public enum Unit: Equatable {
    case node(Node)
    case chord(String)
    case copy
}

public struct UnitGroup: Equatable {
    public var units: [Unit] = []
    public var length: Int = 1

    public init(units: [Unit] = [], length: Int = 1) {
        self.units = units
        self.length = length
    }
}

public struct Section: Equatable {
    public var nodeLength: Int = 4
    public var unitGroups: [UnitGroup] = []

    public init(nodeLength: Int = 4, unitGroups: [UnitGroup] = []) {
        self.nodeLength = nodeLength
        self.unitGroups = unitGroups
    }
}

/// name:instrument@|start|{ ... }
public struct Paragraph: Equatable {
    public var name: String = ""
    public var instrument: String = ""
    public var start: Int = 0
    public var sections: [Section] = []

    public init(name: String = "", instrument: String = "", start: Int = 0, sections: [Section] = []) {
        self.name = name
        self.instrument = instrument
        self.start = start
        self.sections = sections
    }
}

public enum Order: Equatable {
    case name(String)
    case relative(String)
    case absolute(String)
}

public struct Sheet: Equatable {
    public var name: String = ""
    public var speed: Double = 0.0
    public var keySignature: String = "C"
    public var beat: Beat = Beat()
    public var paragraphs: [Paragraph] = []
    public var orders: [Order] = []

    public init(
        name: String = "",
        speed: Double = 0.0,
        keySignature: String = "C",
        beat: Beat = Beat(),
        paragraphs: [Paragraph] = [],
        orders: [Order] = []
    ) {
        self.name = name
        self.speed = speed
        self.keySignature = keySignature
        self.beat = beat
        self.paragraphs = paragraphs
        self.orders = orders
    }
}
