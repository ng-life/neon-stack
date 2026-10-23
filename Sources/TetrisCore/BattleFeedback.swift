public enum DangerLevel: Int, Sendable { case safe, elevated, critical }

/// A resolved placement snapshot. Attack amounts use the same cancellation as the rules.
public struct CombatEvent: Sendable, Equatable {
  public let serial: Int
  public let sent: Int
  public let cancelled: Int
  public let received: Int
}

public enum ClearEffectTier: Int, Sendable { case normal, tetris, combo, perfectClear }
extension ClearEvent {
  public var effectTitle: String {
    if reward.perfectClear { return "全清" }
    var title =
      reward.spin != .none
      ? (reward.spin == .mini ? "T-SPIN MINI" : "T-SPIN")
      : (rows.count == 4 ? "TETRIS" : "\(rows.count) 行消除")
    if reward.backToBack { title = "B2B " + title }
    if combo > 0 { title += "\nCOMBO \(combo)" }
    return title
  }

  public var effectTier: ClearEffectTier {
    if reward.perfectClear { return .perfectClear }
    if combo > 0 { return .combo }
    return rows.count == 4 ? .tetris : .normal
  }
}
