import AppKit
import GameController
import Observation
import TetrisCore

@MainActor @Observable
final class MatchStore {
  private var session = GameSession(mode: .solo, seed: 1)
  var boards: [Board] { session.boards }
  var mode: GameMode { session.mode }
  let music: MusicPlayer
  let sounds: ClearSoundPlayer
  var reducedEffects = false
  var roundID = UUID()
  var running = false
  var started = false
  var winner: String?
  var controllerNames = ["键盘 · A / D", "键盘 · ← / →"]
  var elapsed = 0.0
  var pauseReason = "准备好挑战自己"
  private var controllers: [GCController?] = [nil, nil]
  private var timer: Timer?
  private var keyMonitor: Any?
  private var focusObserver: NSObjectProtocol?
  private var heldKeys: Set<UInt16> = []
  private var previousButtons: [Set<String>] = [[], []]
  private var repeats: [String: Double] = [:]
  private var lastTime = ProcessInfo.processInfo.systemUptime

  init(settings: AudioSettings = AudioSettings()) {
    music = MusicPlayer(settings: settings)
    sounds = ClearSoundPlayer(settings: settings)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
      [weak self] event in
      let consumed = MainActor.assumeIsolated {
        guard let self else { return false }
        if event.modifierFlags.contains(.command) { return false }
        // Settings controls must retain their own keyboard handling.
        guard event.window?.title == "Neon Stack" else { return false }
        let recognized: Set<UInt16> = [0, 2, 1, 13, 12, 14, 49, 123, 124, 125, 126, 43, 47, 36, 53]
        guard recognized.contains(event.keyCode) else { return false }
        if event.type == .keyUp {
          self.heldKeys.remove(event.keyCode)
        } else if !event.isARepeat {
          self.heldKeys.insert(event.keyCode)
          if event.keyCode == 53 { self.togglePause() } else { self.handleKeyPress(event.keyCode) }
        }
        return true
      }
      return consumed ? nil : event
    }
    focusObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.running else { return }
        self.running = false
        self.pauseReason = "窗口失去焦点，游戏已暂停"
        self.heldKeys.removeAll()
      }
    }
    timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.frame() }
    }
    if let timer { RunLoop.main.add(timer, forMode: .common) }
  }

  func selectMode(_ mode: GameMode) {
    guard mode != self.mode else { return }
    music.stop()
    sounds.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: 1)
    running = false
    started = false
    winner = nil
    elapsed = 0
    pauseReason = mode == .solo ? "准备好挑战自己" : "准备好迎接对决"
    heldKeys.removeAll()
    repeats.removeAll()
    previousButtons = [[], []]
  }

  func returnToLobby() {
    music.stop()
    sounds.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: 1)
    running = false
    started = false
    winner = nil
    elapsed = 0
    pauseReason = mode == .solo ? "准备好挑战自己" : "准备好迎接对决"
    heldKeys.removeAll()
    repeats.removeAll()
  }

  func start() {
    let seed = UInt64.random(in: 1...UInt64.max)
    music.stop()
    sounds.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: seed)
    elapsed = 0
    winner = nil
    started = true
    running = true
    repeats.removeAll()
    // Preserve button edges so a held Menu button cannot immediately pause a new match.
    heldKeys.removeAll()
    lastTime = ProcessInfo.processInfo.systemUptime
  }

  func pauseForSettings() {
    guard running else { return }
    running = false
    pauseReason = "设置已打开，游戏已暂停"
    heldKeys.removeAll()
    repeats.removeAll()
    music.update(level: boards.map { $0.lines / 10 + 1 }.max() ?? 1, running: false, delta: 0)
    sounds.stop()
  }

  func togglePause() {
    guard started, winner == nil else { return }
    running.toggle()
    pauseReason = mode == .solo ? "游戏已暂停" : "比赛已暂停"
    heldKeys.removeAll()
    repeats.removeAll()
  }

  // Handle keyboard edges immediately: a quick tap can begin and end between frames.
  private func handleKeyPress(_ code: UInt16) {
    guard running else { return }
    let bindings: [UInt16: (Int, String, GameAction)] = [
      0: (0, "left", .left), 2: (0, "right", .right), 1: (0, "down", .softDrop),
      13: (0, "cw", .clockwise), 12: (0, "ccw", .counterclockwise),
      14: (0, "hold", .hold), 49: (0, "drop", .hardDrop),
      123: (1, "left", .left), 124: (1, "right", .right), 125: (1, "down", .softDrop),
      126: (1, "cw", .clockwise), 43: (1, "ccw", .counterclockwise),
      47: (1, "hold", .hold), 36: (1, "drop", .hardDrop),
    ]
    guard let (player, name, action) = bindings[code] else { return }
    let target = mode == .solo ? 0 : player
    repeats["\(target)-\(name)"] =
      ProcessInfo.processInfo.systemUptime + (name == "down" ? 0.045 : 0.17)
    session.act(action, player: target)
    checkWinner()
  }

  private func refreshControllers() {
    let available = GCController.controllers().filter { $0.extendedGamepad != nil }
    for player in 0..<2 {
      if let old = controllers[player], !available.contains(where: { $0 === old }) {
        controllers[player] = nil
        if running && player < mode.playerCount {
          running = false
          pauseReason = "玩家 \(player + 1) 手柄已断开"
        }
      }
    }
    for device in available where !controllers.contains(where: { $0 === device }) {
      if let index = controllers.firstIndex(where: { $0 == nil }) {
        controllers[index] = device
        device.playerIndex = index == 0 ? .index1 : .index2
      }
    }
    for index in 0..<2 {
      controllerNames[index] =
        controllers[index]?.vendorName ?? (index == 0 ? "键盘 · A / D" : "键盘 · ← / →")
    }
  }

  private func frame() {
    let now = ProcessInfo.processInfo.systemUptime
    let delta = min(0.05, now - lastTime)
    lastTime = now
    refreshControllers()
    for player in 0..<mode.playerCount { readInput(player: player, now: now) }
    let level = (boards.map { $0.lines / 10 + 1 }.max() ?? 1)
    music.update(level: level, running: running, delta: delta)
    sounds.process(boards)
    guard running else { return }
    elapsed += delta
    session.tick(delta)
    checkWinner()
  }

  private func readInput(player: Int, now: Double) {
    var pressed: Set<String> = []
    let keys: [(UInt16, String)] =
      player == 0
      ? [
        (0, "left"), (2, "right"), (1, "down"), (13, "cw"), (12, "ccw"), (14, "hold"), (49, "drop"),
      ]
      : [
        (123, "left"), (124, "right"), (125, "down"), (126, "cw"), (43, "ccw"), (47, "hold"),
        (36, "drop"),
      ]
    var activeKeys = keys
    if mode == .solo {
      activeKeys += [
        (123, "left"), (124, "right"), (125, "down"), (126, "cw"),
        (43, "ccw"), (47, "hold"), (36, "drop"),
      ]
    }
    for (key, name) in activeKeys where heldKeys.contains(key) { pressed.insert(name) }
    if NSApp.keyWindow?.title != "Neon Stack" {
      previousButtons[player] = []
      return
    }
    if let pad = controllers[player]?.extendedGamepad {
      let x =
        abs(pad.dpad.xAxis.value) > 0.2 ? pad.dpad.xAxis.value : pad.leftThumbstick.xAxis.value
      let y =
        abs(pad.dpad.yAxis.value) > 0.2 ? pad.dpad.yAxis.value : pad.leftThumbstick.yAxis.value
      if x < -0.5 { pressed.insert("left") }
      if x > 0.5 { pressed.insert("right") }
      if y < -0.5 { pressed.insert("down") }
      if y > 0.5 { pressed.insert("drop") }
      if pad.buttonA.isPressed { pressed.insert("cw") }
      if pad.buttonB.isPressed { pressed.insert("ccw") }
      if pad.buttonX.isPressed || pad.leftShoulder.isPressed { pressed.insert("hold") }
      if pad.buttonY.isPressed || pad.rightShoulder.isPressed { pressed.insert("drop") }
      if pad.buttonMenu.isPressed { pressed.insert("pause") }
    }
    let previous = previousButtons[player]
    previousButtons[player] = pressed
    if pressed.contains("pause") && !previous.contains("pause") {
      if !started || winner != nil { start() } else { togglePause() }
    }
    guard running else { return }
    let actions: [(String, GameAction)] = [
      ("left", .left), ("right", .right), ("down", .softDrop),
      ("cw", .clockwise), ("ccw", .counterclockwise), ("hold", .hold), ("drop", .hardDrop),
    ]
    for (name, action) in actions {
      let key = "\(player)-\(name)"
      if !pressed.contains(name) {
        repeats.removeValue(forKey: key)
        continue
      }
      let fresh = !previous.contains(name)
      let repeating = ["left", "right", "down"].contains(name)
      if (fresh && repeats[key] == nil) || (repeating && now >= (repeats[key] ?? .infinity)) {
        repeats[key] = now + (fresh && name != "down" ? 0.17 : 0.045)
        session.act(action, player: player)
        checkWinner()
        if !running { break }
      }
    }
  }

  private func checkWinner() {
    sounds.process(boards)
    guard boards.contains(where: \.lost) else { return }
    running = false
    winner =
      mode == .solo
      ? "游戏结束"
      : (boards.allSatisfy(\.lost) ? "平局" : "玩家 \(boards[0].lost ? 2 : 1) 获胜")
  }
}
