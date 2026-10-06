public struct Cell: Equatable, Sendable {
  public var x: Int
  public var y: Int
  public init(_ x: Int, _ y: Int) {
    self.x = x
    self.y = y
  }
}

public enum PieceKind: Int, CaseIterable, Sendable {
  case i = 1
  case o, t, s, z, j, l

  var initialCells: [Cell] {
    switch self {
    case .i: [Cell(0, 1), Cell(1, 1), Cell(2, 1), Cell(3, 1)]
    case .o: [Cell(1, 0), Cell(2, 0), Cell(1, 1), Cell(2, 1)]
    case .t: [Cell(1, 0), Cell(0, 1), Cell(1, 1), Cell(2, 1)]
    case .s: [Cell(1, 0), Cell(2, 0), Cell(0, 1), Cell(1, 1)]
    case .z: [Cell(0, 0), Cell(1, 0), Cell(1, 1), Cell(2, 1)]
    case .j: [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(2, 1)]
    case .l: [Cell(2, 0), Cell(0, 1), Cell(1, 1), Cell(2, 1)]
    }
  }
}

public struct Piece: Equatable, Sendable {
  public var kind: PieceKind
  public var rotation = 0
  public var x = 3
  public var y = -2
  public init(kind: PieceKind) { self.kind = kind }

  public var cells: [Cell] {
    var cells = kind.initialCells
    if kind != .o {
      let size = kind == .i ? 4 : 3
      for _ in 0..<rotation {
        cells = cells.map { Cell(size - 1 - $0.y, $0.x) }
      }
    }
    return cells.map { Cell($0.x + x, $0.y + y) }
  }
}

/// Deterministic seven-bag stream. Each player owns a cursor into the same seed.
public struct PieceStream: Sendable {
  private var state: UInt64
  private var bag: [PieceKind] = []
  public init(seed: UInt64) { state = seed == 0 ? 1 : seed }
  public mutating func next() -> PieceKind {
    if bag.isEmpty {
      bag = PieceKind.allCases
      for index in stride(from: bag.count - 1, through: 1, by: -1) {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        bag.swapAt(index, Int(state % UInt64(index + 1)))
      }
    }
    return bag.removeLast()
  }
}
