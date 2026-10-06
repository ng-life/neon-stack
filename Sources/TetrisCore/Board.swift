public enum GameAction: Sendable {
  case left, right, softDrop, hardDrop, clockwise, counterclockwise, hold
}

public struct Board: Sendable {
  public static let width = 10
  public static let height = 20
  public internal(set) var grid: [[Int]] = Array(
    repeating: Array(repeating: 0, count: 10), count: 20)
  public internal(set) var active: Piece
  public private(set) var held: PieceKind?
  public private(set) var queue: [PieceKind] = []
  public private(set) var score = 0
  public private(set) var lines = 0
  public private(set) var lost = false
  public private(set) var pendingGarbage = 0
  public private(set) var clearSerial = 0
  public private(set) var clearEvents: [ClearEvent] = []
  private var stream: PieceStream
  private var heldThisTurn = false
  private var gravityTime = 0.0
  private var lockTime = 0.0
  private var lockResets = 0
  private var combo = -1
  private var backToBack = false
  private var garbageCursor = 0

  public init(seed: UInt64) {
    var source = PieceStream(seed: seed)
    active = Piece(kind: source.next())
    queue = (0..<5).map { _ in source.next() }
    stream = source
  }

  public var ghost: Piece {
    var result = active
    while fits(shifted(result, dx: 0, dy: 1)) { result.y += 1 }
    return result
  }

  public func fits(_ piece: Piece) -> Bool {
    piece.cells.allSatisfy { cell in
      cell.x >= 0 && cell.x < 10 && cell.y < 20 && cell.y >= -4
        && (cell.y < 0 || grid[cell.y][cell.x] == 0)
    }
  }

  public mutating func receiveGarbage(_ amount: Int) { pendingGarbage += amount }

  /// Returns outgoing attack after cancelling queued garbage.
  public mutating func act(_ action: GameAction) -> Int {
    guard !lost else { return 0 }
    switch action {
    case .left: move(dx: -1, dy: 0)
    case .right: move(dx: 1, dy: 0)
    case .softDrop:
      if move(dx: 0, dy: 1) { score += 1 }
    case .hardDrop:
      let landing = ghost
      score += (landing.y - active.y) * 2
      active = landing
      return lock()
    case .clockwise: rotate(clockwise: true)
    case .counterclockwise: rotate(clockwise: false)
    case .hold:
      guard !heldThisTurn else { return 0 }
      let old = active.kind
      if let held { active = Piece(kind: held) } else { spawn() }
      held = old
      heldThisTurn = true
      resetTimers()
      if !fits(active) { lost = true }
    }
    return 0
  }

  public mutating func tick(_ delta: Double) -> Int {
    guard !lost else { return 0 }
    gravityTime += delta
    let interval = max(0.08, 0.8 * powSpeed(lines / 10))
    if gravityTime >= interval {
      gravityTime = 0
      _ = move(dx: 0, dy: 1)
    }
    if !fits(shifted(active, dx: 0, dy: 1)) {
      lockTime += delta
      if lockTime >= 0.5 { return lock() }
    } else {
      lockTime = 0
    }
    return 0
  }

  private func powSpeed(_ level: Int) -> Double {
    (0..<level).reduce(1.0) { value, _ in value * 0.8 }
  }
  private func shifted(_ piece: Piece, dx: Int, dy: Int) -> Piece {
    var next = piece
    next.x += dx
    next.y += dy
    return next
  }
  @discardableResult
  private mutating func move(dx: Int, dy: Int) -> Bool {
    let candidate = shifted(active, dx: dx, dy: dy)
    guard fits(candidate) else { return false }
    active = candidate
    if dx != 0 && lockResets < 15 {
      lockTime = 0
      lockResets += 1
    }
    return true
  }

  private mutating func rotate(clockwise: Bool) {
    guard active.kind != .o else { return }
    let from = active.rotation
    let to = (from + (clockwise ? 1 : 3)) % 4
    var candidate = active
    candidate.rotation = to
    // SRS coordinates are expressed with upward-positive y; board y grows downward.
    for offset in Self.kicks(from: from, to: to, isI: active.kind == .i) {
      let kicked = shifted(candidate, dx: offset.x, dy: -offset.y)
      if fits(kicked) {
        active = kicked
        if lockResets < 15 {
          lockTime = 0
          lockResets += 1
        }
        return
      }
    }
  }

  static func kicks(from: Int, to: Int, isI: Bool) -> [Cell] {
    let key = from * 4 + to
    let values: [(Int, Int)]
    if isI {
      switch key {
      case 1, 14: values = [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]
      case 4, 11: values = [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]
      case 6, 3: values = [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)]
      default: values = [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]
      }
    } else {
      switch key {
      case 1, 9: values = [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)]
      case 4, 6: values = [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)]
      case 11, 3: values = [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)]
      default: values = [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)]
      }
    }
    return values.map { Cell($0.0, $0.1) }
  }

  private mutating func lock() -> Int {
    guard active.cells.allSatisfy({ $0.y >= 0 }) else {
      lost = true
      return 0
    }
    for cell in active.cells { grid[cell.y][cell.x] = active.kind.rawValue }
    let clearedRows = grid.indices.filter { !grid[$0].contains(0) }
    let clearedColors = clearedRows.map { grid[$0] }
    let remaining = grid.filter { $0.contains(0) }
    let cleared = 20 - remaining.count
    grid = Array(repeating: Array(repeating: 0, count: 10), count: cleared) + remaining
    var attack = 0
    if cleared > 0 {
      clearSerial += 1
      combo += 1
      clearEvents.append(
        ClearEvent(serial: clearSerial, rows: clearedRows, colors: clearedColors, combo: combo))
      if clearEvents.count > 8 { clearEvents.removeFirst() }
      score += [0, 100, 300, 500, 800][cleared] * (lines / 10 + 1)
      lines += cleared
      attack = [0, 0, 1, 2, 4][cleared] + min(4, combo / 2)
      if cleared == 4 {
        if backToBack { attack += 1 }
        backToBack = true
      } else {
        backToBack = false
      }
      let cancelled = min(attack, pendingGarbage)
      attack -= cancelled
      pendingGarbage -= cancelled
    } else {
      combo = -1
      // Apply queued garbage at a no-clear lock, capped per placement.
      let amount = min(8, pendingGarbage)
      pendingGarbage -= amount
      for _ in 0..<amount {
        if grid.removeFirst().contains(where: { $0 != 0 }) { lost = true }
        var row = Array(repeating: 8, count: 10)
        row[garbageCursor % 10] = 0
        garbageCursor += 3
        grid.append(row)
      }
    }
    heldThisTurn = false
    spawn()
    return attack
  }

  private mutating func spawn() {
    active = Piece(kind: queue.removeFirst())
    queue.append(stream.next())
    resetTimers()
    if !fits(active) { lost = true }
  }
  private mutating func resetTimers() {
    gravityTime = 0
    lockTime = 0
    lockResets = 0
  }
}
