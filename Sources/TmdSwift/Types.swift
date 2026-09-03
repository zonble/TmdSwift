struct Beat: Equatable {
    var count: Int = 4
    var node: Int = 4
}

enum SharpFalls: Equatable {
    case normal
    case sharp
    case falls
}

struct Node: Equatable {
    var sharpFalls: SharpFalls = .normal
    var name: Int = 0
    var octave: Int = 0
}

enum UnitType: Equatable {
    case node
    case chord
    case copy
}

struct Unit: Equatable {
    var type: UnitType
    var node: Node = Node()
    var chord: String = ""
}

struct UnitGroup: Equatable {
    var units: [Unit] = []
    var length: Int = 1
}

struct Section: Equatable {
    var nodeLength: Int = 4
    var unitGroups: [UnitGroup] = []
}

/// name:instrument@|start|{ ... }
struct Paragraph: Equatable {
    var name: String = ""
    var instrument: String = ""
    var start: Int = 0
    var sections: [Section] = []
}

enum OrderType: Equatable {
    case name
    case relative
    case absolute
}

struct Order: Equatable {
    var type: OrderType
    var name: String
}

struct Sheet: Equatable {
    var name: String = ""
    var speed: Double = 0.0
    var keySignature: String = "C"
    var beat: Beat = Beat()
    var paragraphs: [Paragraph] = []
    var orders: [Order] = []
}
