public enum OperationSound: String, CaseIterable, Sendable {
  case rotate, lock, hardDrop
}

public struct OperationFeedback: Sendable, Equatable {
  public let serial: Int
  public let sound: OperationSound
}
