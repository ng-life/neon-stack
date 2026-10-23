import Foundation
import Observation
import TetrisCore

enum InputCommand: String, CaseIterable, Codable, Identifiable {
  case left, right, down, clockwise, counterclockwise, hold, drop, pause, unassigned
  var id: String { rawValue }
  var title: String {
    switch self {
    case .left: "左移"
    case .right: "右移"
    case .down: "软降"
    case .clockwise: "顺时针旋转"
    case .counterclockwise: "逆时针旋转"
    case .hold: "暂存"
    case .drop: "硬降"
    case .pause: "暂停 / 继续"
    case .unassigned: "不绑定"
    }
  }
  var gameAction: GameAction? {
    switch self {
    case .left: .left
    case .right: .right
    case .down: .softDrop
    case .clockwise: .clockwise
    case .counterclockwise: .counterclockwise
    case .hold: .hold
    case .drop: .hardDrop
    default: nil
    }
  }
  var repeats: Bool { self == .left || self == .right || self == .down }
}

enum PadControl: String, CaseIterable, Codable, Identifiable {
  case left, right, down, up, a, b, x, y, lb, rb, lt, rt, menu
  var id: String { rawValue }
  var title: String {
    switch self {
    case .left: "方向键 / 摇杆左"
    case .right: "方向键 / 摇杆右"
    case .down: "方向键 / 摇杆下"
    case .up: "方向键 / 摇杆上"
    case .menu: "Menu"
    default: rawValue.uppercased()
    }
  }
}

struct KeyChoice: Identifiable {
  let code: UInt16
  let title: String
  var id: UInt16 { code }
  static let all: [KeyChoice] = [
    (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"), (4, "H"),
    (34, "I"), (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"), (31, "O"), (35, "P"),
    (12, "Q"), (15, "R"), (1, "S"), (17, "T"), (32, "U"), (9, "V"), (13, "W"), (7, "X"),
    (16, "Y"), (6, "Z"), (18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"),
    (22, "6"), (26, "7"), (28, "8"), (25, "9"), (29, "0"), (123, "←"), (124, "→"),
    (125, "↓"), (126, "↑"), (43, ","), (47, "."), (49, "空格"), (36, "Enter"), (53, "Esc"),
  ].map { KeyChoice(code: $0.0, title: $0.1) }
  static func title(_ code: UInt16) -> String { all.first { $0.code == code }?.title ?? "?" }
}

struct InputConfiguration: Codable, Equatable {
  var delay = 0.17
  var interval = 0.045
  var deadZone: Float = 0.5
  var keyboard: [[String: UInt16]] = [
    [
      "left": 0, "right": 2, "down": 1, "clockwise": 13, "counterclockwise": 12, "hold": 14,
      "drop": 49, "pause": 53,
    ],
    [
      "left": 123, "right": 124, "down": 125, "clockwise": 126, "counterclockwise": 43, "hold": 47,
      "drop": 36, "pause": 53,
    ],
  ]
  var gamepad: [[String: InputCommand]] = Array(
    repeating: [
      "left": .left, "right": .right, "down": .down, "up": .drop, "a": .drop,
      "b": .hold, "x": .clockwise, "y": .counterclockwise, "lb": .hold, "rb": .drop, "menu": .pause,
    ], count: 2)

  var isValid: Bool {
    guard delay.isFinite, (0.05...0.5).contains(delay), interval.isFinite,
      (0.016...0.15).contains(interval), deadZone.isFinite, (0.1...0.9).contains(deadZone),
      keyboard.count == 2, gamepad.count == 2
    else { return false }
    var used: [UInt16: InputCommand] = [:]
    for bindings in keyboard {
      for command in InputCommand.allCases where command != .unassigned {
        guard let code = bindings[command.rawValue],
          KeyChoice.all.contains(where: { $0.code == code })
        else { return false }
        if let prior = used[code], !(prior == .pause && command == .pause) { return false }
        used[code] = command
      }
    }
    return gamepad.allSatisfy { bindings in
      bindings.keys.allSatisfy { PadControl(rawValue: $0) != nil }
        && bindings.values.contains(.pause)
    }
  }
}

@MainActor @Observable final class InputSettings {
  private let defaults: UserDefaults
  private(set) var configuration: InputConfiguration
  private(set) var revision = 0
  var delay: Double {
    get { configuration.delay }
    set {
      var next = configuration
      next.delay = min(0.5, max(0.05, newValue))
      save(next)
    }
  }
  var interval: Double {
    get { configuration.interval }
    set {
      var next = configuration
      next.interval = min(0.15, max(0.016, newValue))
      save(next)
    }
  }
  var deadZone: Float {
    get { configuration.deadZone }
    set {
      var next = configuration
      next.deadZone = min(0.9, max(0.1, newValue))
      save(next)
    }
  }
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: "input.configuration"),
      let decoded = try? JSONDecoder().decode(InputConfiguration.self, from: data), decoded.isValid
    {
      var migrated = decoded
      let version = defaults.integer(forKey: "input.gamepadDefaultsVersion")
      var oldDefault = InputConfiguration().gamepad[0]
      oldDefault["a"] = .clockwise
      oldDefault["b"] = .counterclockwise
      oldDefault["x"] = version == 0 ? .hold : .drop
      oldDefault["y"] = version == 0 ? .drop : .hold
      // Migrate only the default layout from the saved version, never a custom layout.
      if version < 2 {
        for player in 0..<2 where migrated.gamepad[player] == oldDefault {
          migrated.gamepad[player] = InputConfiguration().gamepad[player]
        }
      }
      configuration = migrated
      if migrated != decoded, let data = try? JSONEncoder().encode(migrated) {
        defaults.set(data, forKey: "input.configuration")
      }
    } else {
      configuration = InputConfiguration()
    }
    defaults.set(2, forKey: "input.gamepadDefaultsVersion")
  }
  func key(player: Int, command: InputCommand) -> UInt16 {
    configuration.keyboard[player][command.rawValue]!
  }
  /// Reject conflicts across both players; a shared pause key is safe.
  func setKey(player: Int, command: InputCommand, code: UInt16) -> Bool {
    var next = configuration
    next.keyboard[player][command.rawValue] = code
    guard next.isValid else { return false }
    save(next)
    return true
  }
  func mapping(player: Int, control: PadControl) -> InputCommand {
    configuration.gamepad[player][control.rawValue] ?? .unassigned
  }
  func setMapping(player: Int, control: PadControl, command: InputCommand) -> Bool {
    var next = configuration
    next.gamepad[player][control.rawValue] = command
    guard next.isValid else { return false }
    save(next)
    return true
  }
  func commands(player: Int, controls: Set<PadControl>) -> Set<InputCommand> {
    Set(controls.map { mapping(player: player, control: $0) }.filter { $0 != .unassigned })
  }
  func reset() { save(InputConfiguration()) }
  private func save(_ next: InputConfiguration) {
    guard next.isValid, let data = try? JSONEncoder().encode(next) else { return }
    configuration = next
    defaults.set(data, forKey: "input.configuration")
    revision += 1
  }
  func keyboardSummary(player: Int) -> String {
    [InputCommand.left, .right, .down, .clockwise, .counterclockwise, .hold, .drop, .pause].map {
      "\(KeyChoice.title(key(player: player, command: $0))) \($0.title)"
    }.joined(separator: " · ")
  }
}
