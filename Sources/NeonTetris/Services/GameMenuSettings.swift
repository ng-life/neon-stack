import AppKit
import Observation
import TetrisCore

@MainActor @Observable final class GameMenuSettings {
  enum Tab: String, CaseIterable {
    case audio = "声音与动效"
    case input = "操作"
    case background = "背景"
    case scores = "成绩"
    case controllers = "手柄诊断"
    case logs = "日志"
  }
  private let defaults: UserDefaults
  var reducedEffects: Bool {
    didSet { defaults.set(reducedEffects, forKey: "visual.reducedEffects") }
  }
  let backgrounds: BackgroundSettings
  let audio: AudioSettings
  let input: InputSettings
  let scores: ScoreStore
  var tab: Tab = .audio
  var selected = 0 {
    didSet {
      if selected != oldValue {
        pendingClear = false
        bindingCommand = nil
      }
    }
  }
  var player = 0
  var scoreMode: GameMode = .solo
  var pendingClear = false
  var bindingCommand: InputCommand?
  var notice = ""
  init(
    audio: AudioSettings, input: InputSettings, scores: ScoreStore, backgrounds: BackgroundSettings,
    defaults: UserDefaults = .standard
  ) {
    self.defaults = defaults
    reducedEffects = defaults.bool(forKey: "visual.reducedEffects")
    self.backgrounds = backgrounds
    self.audio = audio
    self.input = input
    self.scores = scores
  }
  var titles: [String] {
    switch tab {
    case .audio:
      [
        "背景音乐", "背景音乐音量", "消行音效", "消行音效音量", "操作音效", "操作音效音量", "试听消行", "试听硬降", "危险提示音", "危险提示音量",
        "减少动效",
      ]
    case .input:
      ["玩家", "连移延迟", "移动间隔", "摇杆死区"] + PadControl.allCases.map { "手柄 · " + $0.title }
        + InputCommand.allCases.filter { $0 != .unassigned }.map { "键盘 · " + $0.title } + [
          "恢复默认映射与手感"
        ]
    case .background: ["应用界面", "背景图片", "选择本机图片"]
    case .scores: ["成绩模式", "清理当前模式", "清理全部成绩"]
    case .controllers: []
    case .logs: ["打开日志文件夹"]
    }
  }
  func switchTab(_ direction: Int) {
    let tabs = Tab.allCases
    tab = tabs[(tabs.firstIndex(of: tab)! + direction + tabs.count) % tabs.count]
    selected = 0
    pendingClear = false
    bindingCommand = nil
    notice = ""
  }
  func move(_ direction: Int) {
    guard !titles.isEmpty else { return }
    selected = (selected + direction + titles.count) % titles.count
    pendingClear = false
    bindingCommand = nil
    notice = ""
  }
  func keyboardCommand(_ index: Int) -> InputCommand? {
    let offset = index - 4 - PadControl.allCases.count
    let keys = InputCommand.allCases.filter { $0 != .unassigned }
    return tab == .input && keys.indices.contains(offset) ? keys[offset] : nil
  }

  func captureKey(_ code: UInt16) {
    guard let command = bindingCommand else { return }
    if code == 53 {
      bindingCommand = nil
      notice = "已取消绑定"
      return
    }
    guard KeyChoice.all.contains(where: { $0.code == code }) else {
      notice = "此按键不支持绑定，请换一个按键"
      return
    }
    if input.setKey(player: player, command: command, code: code) {
      bindingCommand = nil
      notice = "绑定已保存"
    } else {
      notice = "按键已被其他操作占用，请换一个按键"
    }
  }

  func value(_ index: Int) -> String {
    switch tab {
    case .audio:
      return switch index {
      case 0: audio.musicEnabled ? "开启" : "关闭"
      case 1: "\(Int((audio.musicVolume * 100).rounded()))%"
      case 2: audio.effectsEnabled ? "开启" : "关闭"
      case 3: "\(Int((audio.effectsVolume * 100).rounded()))%"
      case 4: audio.operationsEnabled ? "开启" : "关闭"
      case 5: "\(Int((audio.operationsVolume * 100).rounded()))%"
      case 8: audio.warningEnabled ? "开启" : "关闭"
      case 9: "\(Int((audio.warningVolume * 100).rounded()))%"
      case 10: reducedEffects ? "开启" : "关闭"
      default: "A 试听"
      }
    case .input:
      if index == 0 { return "玩家 \(player + 1)" }
      if index == 1 { return String(format: "%.0f ms", input.delay * 1000) }
      if index == 2 { return String(format: "%.0f ms", input.interval * 1000) }
      if index == 3 { return "\(Int((input.deadZone * 100).rounded()))%" }
      let padIndex = index - 4
      if PadControl.allCases.indices.contains(padIndex) {
        return input.mapping(player: player, control: PadControl.allCases[padIndex]).title
      }
      let keys = InputCommand.allCases.filter { $0 != .unassigned }
      let keyIndex = padIndex - PadControl.allCases.count
      if keys.indices.contains(keyIndex) {
        return KeyChoice.title(input.key(player: player, command: keys[keyIndex]))
      }
      return "A 确认"
    case .scores:
      return index == 0
        ? (scoreMode == .solo ? "单人挑战" : "双人对战")
        : (pendingClear && index == selected ? "再次按 A 确认清理" : "A 清理")
    case .background:
      if index == 0 { return backgrounds.target.rawValue }
      if index == 1 {
        return BuiltInBackground.all.first { $0.id == backgrounds.selection(backgrounds.target) }?
          .title ?? "本机图片"
      }
      return "选择图片"
    case .controllers: return ""
    case .logs: return "A 打开"
    }
  }
  func adjust(_ direction: Int) {
    notice = ""
    switch tab {
    case .audio:
      switch selected {
      case 0: audio.musicEnabled.toggle()
      case 1: audio.musicVolume = min(1, max(0, audio.musicVolume + Float(direction) * 0.05))
      case 2: audio.effectsEnabled.toggle()
      case 3: audio.effectsVolume = min(1, max(0, audio.effectsVolume + Float(direction) * 0.05))
      case 8: audio.warningEnabled.toggle()
      case 9: audio.warningVolume = min(1, max(0, audio.warningVolume + Float(direction) * 0.05))
      case 10: reducedEffects.toggle()
      case 4: audio.operationsEnabled.toggle()
      case 5:
        audio.operationsVolume = min(1, max(0, audio.operationsVolume + Float(direction) * 0.05))
      default: break
      }
    case .input:
      if selected == 0 {
        player = 1 - player
      } else if selected == 1 {
        input.delay += Double(direction) * 0.01
      } else if selected == 2 {
        input.interval += Double(direction) * 0.005
      } else if selected == 3 {
        input.deadZone += Float(direction) * 0.05
      } else {
        let padIndex = selected - 4
        if PadControl.allCases.indices.contains(padIndex) {
          let control = PadControl.allCases[padIndex]
          let choices = InputCommand.allCases
          let current = choices.firstIndex(of: input.mapping(player: player, control: control))!
          if !input.setMapping(
            player: player, control: control,
            command: choices[(current + direction + choices.count) % choices.count])
          {
            notice = "至少保留一个暂停按键"
          }
        } else {
          let keys = InputCommand.allCases.filter { $0 != .unassigned }
          let keyIndex = padIndex - PadControl.allCases.count
          guard keys.indices.contains(keyIndex) else { return }
          let command = keys[keyIndex]
          let choices = KeyChoice.all
          let current =
            choices.firstIndex { $0.code == input.key(player: player, command: command) } ?? 0
          // Skip occupied keys rather than introducing mapping conflicts.
          for offset in 1...choices.count {
            let index = (current + direction * offset + choices.count * 2) % choices.count
            if input.setKey(player: player, command: command, code: choices[index].code) { break }
          }
        }
      }
    case .background:
      if selected == 0 {
        backgrounds.target = backgrounds.target == .menu ? .game : .menu
      } else if selected == 1 {
        backgrounds.cycle(direction)
      }
    case .scores:
      if selected == 0 { scoreMode = scoreMode == .solo ? .versus : .solo }
      pendingClear = false
    default: break
    }
    DiagnosticLog.shared.record(
      "settings_adjusted", fields: ["tab": tab.rawValue, "row": String(selected)])
  }
}
