import Foundation

enum MenuAction: String, CaseIterable, Identifiable {
  case start, resume, restart, lobby, solo, versus, settings, back
  var id: String { rawValue }
  var title: String {
    switch self {
    case .start: "开始游戏"
    case .resume: "继续游戏"
    case .restart: "重新开始"
    case .lobby: "结束游戏"
    case .solo: "单人挑战"
    case .versus: "双人对战"
    case .settings: "设置"
    case .back: "返回"
    }
  }
}

/// Menu bindings are fixed and independent of configurable board bindings.
/// Preserve edges across screen changes so holding confirm cannot activate twice.
struct ControllerNavigation {
  private var previous: Set<PadControl> = []
  private var repeatAt = 0.0
  mutating func poll(_ controls: Set<PadControl>, now: Double) -> (
    move: Int, vertical: Int, horizontal: Int, tab: Int, confirm: Bool, back: Bool, menu: Bool
  ) {
    let fresh = controls.subtracting(previous)
    let direction =
      controls.contains(.left) || controls.contains(.up)
      ? -1 : (controls.contains(.right) || controls.contains(.down) ? 1 : 0)
    let freshDirection = !fresh.intersection([.left, .right, .up, .down]).isEmpty
    let move = direction != 0 && (freshDirection || now >= repeatAt) ? direction : 0
    if move != 0 { repeatAt = now + (freshDirection ? 0.3 : 0.12) }
    if direction == 0 { repeatAt = 0 }
    previous = controls
    let vertical = controls.contains(.up) ? -1 : (controls.contains(.down) ? 1 : 0)
    let horizontal = controls.contains(.left) ? -1 : (controls.contains(.right) ? 1 : 0)
    return (
      move, move == 0 ? 0 : vertical, move == 0 ? 0 : horizontal,
      fresh.contains(.lb) ? -1 : (fresh.contains(.rb) ? 1 : 0), fresh.contains(.a),
      fresh.contains(.b), fresh.contains(.menu)
    )
  }
}
