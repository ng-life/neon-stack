/// A rendering snapshot taken before cleared rows collapse. It never delays game rules.
public struct ClearEvent: Sendable, Equatable {
  public let serial: Int
  public let rows: [Int]
  public let colors: [[Int]]
  public let combo: Int
  public let reward: PlacementReward
}
