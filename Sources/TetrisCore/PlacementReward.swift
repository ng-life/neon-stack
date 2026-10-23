public enum SpinKind: String, Sendable {
  case none, mini, full
}

/// Rewards use the level before this placement. Attack is before garbage cancellation.
public struct PlacementReward: Sendable, Equatable {
  public let rows: Int
  public let spin: SpinKind
  public let backToBack: Bool
  public let perfectClear: Bool
  public let points: Int
  public let attack: Int

  public var title: String {
    var labels: [String] = []
    if perfectClear { labels.append("全清") }
    if backToBack { labels.append("B2B") }
    if spin != .none { labels.append(spin == .mini ? "T-SPIN MINI" : "T-SPIN") }
    if rows == 4 { labels.append("TETRIS") } else if rows > 0 { labels.append("\(rows) 行消除") }
    return labels.joined(separator: " · ")
  }

  static func calculate(
    rows: Int, spin: SpinKind, chained: Bool, perfectClear: Bool,
    combo: Int, level: Int
  ) -> PlacementReward {
    let difficult = rows > 0 && (rows == 4 || spin != .none)
    let b2b = difficult && chained
    let base: Int
    let baseAttack: Int
    switch spin {
    case .none:
      base = [0, 100, 300, 500, 800][rows]
      baseAttack = [0, 0, 1, 2, 4][rows]
    case .mini:
      base = [100, 200, 400][min(rows, 2)]
      baseAttack = [0, 0, 1][min(rows, 2)]
    case .full:
      base = [400, 800, 1200, 1600][min(rows, 3)]
      baseAttack = [0, 2, 4, 6][min(rows, 3)]
    }
    let clearBonus = perfectClear ? [0, 800, 1200, 1800, b2b ? 3200 : 2000][rows] : 0
    let comboScore = rows > 0 ? 50 * max(0, combo) : 0
    let points = ((b2b ? base * 3 / 2 : base) + comboScore + clearBonus) * level
    let attack =
      baseAttack + (b2b ? 1 : 0)
      + (rows > 0 ? min(4, max(0, combo) / 2) : 0) + (perfectClear ? 10 : 0)
    return PlacementReward(
      rows: rows, spin: spin, backToBack: b2b,
      perfectClear: perfectClear, points: points, attack: attack)
  }
}
