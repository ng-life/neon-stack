public enum GameMode: String, CaseIterable, Codable, Sendable {
  case solo
  case versus

  public var playerCount: Int { self == .solo ? 1 : 2 }
}

/// Owns mode-specific advancement and attack routing independently of UI and input devices.
public struct GameSession: Sendable {
  public let mode: GameMode
  public internal(set) var boards: [Board]
  public private(set) var sentAttacks: [Int]

  public init(mode: GameMode, seed: UInt64) {
    self.mode = mode
    sentAttacks = Array(repeating: 0, count: mode.playerCount)
    boards = (0..<mode.playerCount).map { _ in Board(seed: seed) }
  }

  public var isOver: Bool { boards.contains(where: \.lost) }

  public mutating func act(_ action: GameAction, player: Int) {
    guard !isOver, boards.indices.contains(player) else { return }
    let attack = boards[player].act(action)
    if mode == .versus {
      sentAttacks[player] += attack
      boards[1 - player].receiveGarbage(attack)
    }
  }

  public mutating func tick(_ delta: Double) {
    guard !isOver else { return }
    // Resolve both boards before delivering attacks; solo never receives garbage.
    let attacks = boards.indices.map { boards[$0].tick(delta) }
    if mode == .versus {
      for player in boards.indices { sentAttacks[player] += attacks[player] }
      boards[1].receiveGarbage(attacks[0])
      boards[0].receiveGarbage(attacks[1])
    }
  }
}
