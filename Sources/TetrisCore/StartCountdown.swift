/// Countdown time is separate from gameplay time and freezes while paused.
public struct StartCountdown: Sendable {
  public private(set) var remaining: Double = 0
  public var number: Int? { remaining > 0 ? Int(remaining.rounded(.up)) : nil }
  public init() {}
  public mutating func start() { remaining = 3 }
  public mutating func reset() { remaining = 0 }
  @discardableResult public mutating func advance(_ delta: Double) -> Bool {
    guard remaining > 0, delta.isFinite, delta >= 0 else { return false }
    remaining = max(0, remaining - delta)
    return remaining == 0
  }
}
