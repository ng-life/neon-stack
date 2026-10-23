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
  let warnings: DangerSoundPlayer
  let operations: OperationSoundPlayer
  let scores: ScoreStore
  var newRecordPlayers: Set<Int> = []
  private(set) var roundWins = [0, 0]
  var resultPlayers: [PlayerScore] {
    boards.indices.map { player in
      PlayerScore(
        score: boards[player].score, lines: boards[player].lines,
        fourLineClears: boards[player].fourLineClears, attackSent: session.sentAttacks[player],
        roundWins: mode == .versus ? roundWins[player] : nil)
    }
  }
  private var countdown = StartCountdown()
  var countdownNumber: Int? { countdown.number }
  let input: InputSettings
  let controllerHub = ControllerHub()
  enum Screen { case main, modes, playing, pause, results, settings }
  var screen: Screen = .main
  private var settingsReturn: Screen = .main
  var settingsWindowVisible = false
  let menuSettings: GameMenuSettings
  let backgrounds: BackgroundSettings
  var selectedMenuAction: MenuAction = .start
  private var navigation = [ControllerNavigation(), ControllerNavigation()]
  private var waitForPadRelease = [false, false]
  var menuActions: [MenuAction] {
    switch screen {
    case .main: [.start, .settings]
    case .modes: [.solo, .versus, .back]
    case .pause: [.resume, .lobby, .settings]
    case .results: [.restart, .lobby, .settings]
    case .playing, .settings: []
    }
  }
  var hasController: Bool { controllerHub.availableCount > 0 }
  var confirmHint: String { hasController ? "A" : "Enter" }
  var backHint: String { hasController ? "B" : "Esc" }
  var menuHint: String { hasController ? "方向键 / 左摇杆选择 · A 确认" : "↑ ↓ 选择 · Enter 确认" }
  var settingsHint: String {
    hasController
      ? "LB / RB 切换页签 · ↑ ↓ 选择 · ← → 调整 · A 确认 · B 返回"
      : "PgUp / PgDn 切换页签 · ↑ ↓ 选择 · ← → 调整 · Enter 确认 · Esc 返回"
  }
  var reducedEffects: Bool {
    get { menuSettings.reducedEffects }
    set { menuSettings.reducedEffects = newValue }
  }
  var roundID = UUID()
  var running = false
  var started = false
  var winner: String?
  var controllerNames = ["键盘 · A / D", "键盘 · ← / →"]
  var elapsed = 0.0
  var pauseReason = "准备好挑战自己"
  private var timer: Timer?
  private var keyMonitor: Any?
  private var focusObserver: NSObjectProtocol?
  private var heldKeys: Set<UInt16> = []
  private var repeaters = [InputRepeater(), InputRepeater()]
  private var inputRevision = 0
  private var lastTime = ProcessInfo.processInfo.systemUptime

  init(
    settings: AudioSettings = AudioSettings(), input: InputSettings = InputSettings(),
    scores: ScoreStore = ScoreStore(), backgrounds: BackgroundSettings = BackgroundSettings(),
    startRuntime: Bool = true
  ) {
    self.backgrounds = backgrounds
    menuSettings = GameMenuSettings(
      audio: settings, input: input, scores: scores, backgrounds: backgrounds)
    self.scores = scores
    self.input = input
    warnings = DangerSoundPlayer(settings: settings)
    music = MusicPlayer(settings: settings)
    sounds = ClearSoundPlayer(settings: settings)
    operations = OperationSoundPlayer(settings: settings)
    sounds.onClearPlayed = { [weak music] in music?.duckForClear() }
    guard startRuntime else { return }
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
      [weak self] event in
      let consumed = MainActor.assumeIsolated {
        guard let self else { return false }
        if self.backgrounds.choosingImage { return false }
        if event.modifierFlags.contains(.command) { return false }
        if self.screen == .settings, self.menuSettings.bindingCommand != nil, event.type == .keyDown
        {
          self.menuSettings.captureKey(event.keyCode)
          return true
        }
        guard event.window?.title == "Neon Stack" || self.settingsWindowVisible else {
          return false
        }
        if self.screen != .playing {
          let menuKeys: Set<UInt16> = [123, 124, 125, 126, 36, 49, 53, 116, 121]
          guard menuKeys.contains(event.keyCode) else { return false }
          if event.type == .keyDown
            && (!event.isARepeat || [123, 124, 125, 126].contains(event.keyCode))
          {
            self.handleMenuKey(event.keyCode)
          }
          return true
        }
        guard event.window?.title == "Neon Stack" else { return false }
        let recognized = Set(self.input.configuration.keyboard.flatMap { $0.values })
        guard recognized.contains(event.keyCode) else { return false }
        if event.type == .keyUp {
          self.heldKeys.remove(event.keyCode)
        } else if !event.isARepeat {
          self.heldKeys.insert(event.keyCode)
          self.handleKeyPress(event.keyCode)
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
        self.screen = .pause
        self.selectedMenuAction = .resume
        self.pauseReason = "窗口失去焦点，游戏已暂停"
        DiagnosticLog.shared.record("focus_pause")
        self.heldKeys.removeAll()
      }
    }
    timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.frame() }
    }
    if let timer { RunLoop.main.add(timer, forMode: .common) }
  }

  func selectMode(_ mode: GameMode) {
    selectedMenuAction = .start
    guard mode != self.mode else { return }
    roundWins = [0, 0]
    DiagnosticLog.shared.record("mode_selected", fields: ["mode": mode.rawValue])
    music.stop()
    warnings.reset()
    sounds.reset()
    operations.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: 1)
    running = false
    selectedMenuAction = .start
    screen = .main
    started = false
    winner = nil
    newRecordPlayers = []
    countdown.reset()
    elapsed = 0
    pauseReason = mode == .solo ? "准备好挑战自己" : "准备好迎接对决"
    heldKeys.removeAll()
    for index in repeaters.indices { repeaters[index].clearRepeats() }
    repeaters = [InputRepeater(), InputRepeater()]
  }

  func returnToLobby() {
    roundWins = [0, 0]
    DiagnosticLog.shared.record("return_lobby")
    music.stop()
    warnings.reset()
    sounds.reset()
    operations.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: 1)
    running = false
    selectedMenuAction = .start
    screen = .main
    started = false
    winner = nil
    newRecordPlayers = []
    countdown.reset()
    elapsed = 0
    pauseReason = mode == .solo ? "准备好挑战自己" : "准备好迎接对决"
    heldKeys.removeAll()
    for index in repeaters.indices { repeaters[index].clearRepeats() }
  }

  func start(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
    music.stop()
    warnings.reset()
    sounds.reset()
    operations.reset()
    roundID = UUID()
    session = GameSession(mode: mode, seed: seed)
    elapsed = 0
    winner = nil
    newRecordPlayers = []
    countdown.reset()
    countdown.start()
    DiagnosticLog.shared.record(
      "match_start",
      fields: ["round": roundID.uuidString, "mode": mode.rawValue, "seed": String(seed)])
    selectedMenuAction = .resume
    waitForPadRelease = [true, true]
    screen = .playing
    started = true
    running = true
    for index in repeaters.indices { repeaters[index].clearRepeats() }
    // Preserve button edges so a held Menu button cannot immediately pause a new match.
    heldKeys.removeAll()
    lastTime = ProcessInfo.processInfo.systemUptime
  }

  func pauseForSettings() {
    guard running else { return }
    running = false
    screen = .pause
    selectedMenuAction = .resume
    pauseReason = "设置已打开，游戏已暂停"
    DiagnosticLog.shared.record("settings_pause")
    heldKeys.removeAll()
    for index in repeaters.indices { repeaters[index].clearRepeats() }
    music.update(level: boards.map { $0.lines / 10 + 1 }.max() ?? 1, running: false, delta: 0)
    warnings.stop()
    sounds.stop()
    operations.stop()
  }

  func togglePause() {
    guard started, winner == nil else { return }
    running.toggle()
    screen = running ? .playing : .pause
    selectedMenuAction = .resume
    waitForPadRelease = [true, true]
    DiagnosticLog.shared.record("pause_changed", fields: ["running": String(running)])
    pauseReason = mode == .solo ? "游戏已暂停" : "比赛已暂停"
    heldKeys.removeAll()
    for index in repeaters.indices { repeaters[index].clearRepeats() }
  }

  /// Keyboard menu shortcuts mirror controller navigation without changing board mappings.
  func handleMenuKey(_ code: UInt16) {
    guard screen != .playing else { return }
    if screen == .settings {
      switch code {
      case 116: menuSettings.switchTab(-1)
      case 121: menuSettings.switchTab(1)
      case 126: menuSettings.move(-1)
      case 125: menuSettings.move(1)
      case 123: menuSettings.adjust(-1)
      case 124: menuSettings.adjust(1)
      case 36, 49: confirmSetting()
      case 53:
        if menuSettings.bindingCommand != nil {
          menuSettings.bindingCommand = nil
        } else {
          closeSettings()
        }
      default: break
      }
      return
    }
    if [123, 124, 125, 126].contains(code),
      let index = menuActions.firstIndex(of: selectedMenuAction)
    {
      let direction = code == 123 || code == 126 ? -1 : 1
      selectedMenuAction = menuActions[(index + direction + menuActions.count) % menuActions.count]
    } else if code == 36 || code == 49 {
      activateMenu(selectedMenuAction)
    } else if code == 53 {
      if screen == .modes { activateMenu(.back) } else if screen == .pause { activateMenu(.resume) }
    }
  }

  // Handle quick taps immediately, before their key-up can arrive between frames.
  private func handleKeyPress(_ code: UInt16) {
    for player in 0..<2 {
      guard
        let command = InputCommand.allCases.first(where: {
          $0 != .unassigned && input.key(player: player, command: $0) == code
        })
      else { continue }
      let target = mode == .solo ? 0 : player
      let now = ProcessInfo.processInfo.systemUptime
      repeaters[target].immediate(command, now: now, configuration: input.configuration)
      if command == .pause {
        if screen == .settings {
          closeSettings()
        } else if screen == .modes {
          screen = .main
          selectedMenuAction = .start
        } else {
          togglePause()
        }
        break
      }
      perform(command, player: target)
    }
  }

  private func refreshControllers() {
    let disconnected = controllerHub.refresh(deadZone: input.deadZone)
    for player in disconnected {
      DiagnosticLog.shared.record("controller_disconnected", fields: ["player": String(player + 1)])
      repeaters[player].releaseAll()
      if running && player < mode.playerCount {
        running = false
        screen = .pause
        selectedMenuAction = .resume
        pauseReason = "玩家 \(player + 1) 手柄已断开"
        heldKeys.removeAll()
        for index in repeaters.indices { repeaters[index].clearRepeats() }
      }
    }
    let names = controllerHub.readings.enumerated().map { index, reading in
      reading.connected
        ? reading.name
        : "键盘 · \(KeyChoice.title(input.key(player: index, command: .left))) / \(KeyChoice.title(input.key(player: index, command: .right)))"
    }
    if names != controllerNames { controllerNames = names }
  }

  private func frame() {
    let now = ProcessInfo.processInfo.systemUptime
    let rawDelta = max(0, now - lastTime)
    let delta = min(0.05, rawDelta)
    lastTime = now
    refreshControllers()
    if inputRevision != input.revision {
      inputRevision = input.revision
      heldKeys.removeAll()
      repeaters = [InputRepeater(), InputRepeater()]
    }
    readControllerNavigation(now: now)
    for player in 0..<mode.playerCount { readInput(player: player, now: now) }
    let level = (boards.map { $0.lines / 10 + 1 }.max() ?? 1)
    music.update(level: level, running: running && countdownNumber == nil, delta: delta)
    warnings.process(
      boards, active: running && countdownNumber == nil, now: ProcessInfo.processInfo.systemUptime)
    sounds.process(boards)
    operations.process(boards, now: ProcessInfo.processInfo.systemUptime)
    guard running else { return }
    if countdownNumber != nil {
      advanceCountdown(rawDelta)
      return
    }
    elapsed += rawDelta
    session.tick(delta)
    checkWinner()
  }

  private func readInput(player: Int, now: Double) {
    guard NSApp.isActive, NSApp.keyWindow?.title == "Neon Stack" else {
      repeaters[player].releaseAll()
      return
    }
    var pressed: Set<InputCommand> = []
    let keyboardPlayers = mode == .solo ? [0, 1] : [player]
    for source in keyboardPlayers {
      for command in InputCommand.allCases where command != .unassigned {
        if heldKeys.contains(input.key(player: source, command: command)) {
          pressed.insert(command)
        }
      }
    }
    if running && !waitForPadRelease[player] {
      pressed.formUnion(
        input.commands(
          player: player, controls: controllerHub.readings[player].controls.subtracting([.menu])))
    }
    let commands = repeaters[player].poll(pressed, now: now, configuration: input.configuration)
    if commands.contains(.pause) {
      if !started || winner != nil { start() } else { togglePause() }
      return
    }
    for command in commands {
      perform(command, player: player)
      if !running { break }
    }
  }

  func activateMenu(_ action: MenuAction) {
    guard menuActions.contains(action) else { return }
    DiagnosticLog.shared.record("controller_menu_action", fields: ["action": action.rawValue])
    waitForPadRelease = [true, true]
    switch action {
    case .start:
      screen = .modes
      selectedMenuAction = .solo
    case .restart: start()
    case .resume: if !running { togglePause() }
    case .lobby: returnToLobby()
    case .solo:
      selectMode(.solo)
      start()
    case .versus:
      selectMode(.versus)
      start()
    case .settings: openSettings()
    case .back:
      screen = .main
      selectedMenuAction = .start
    }
  }

  func openSettings() {
    guard screen != .settings else { return }
    pauseForSettings()
    settingsReturn = started ? (winner == nil ? .pause : .results) : screen
    screen = .settings
    menuSettings.selected = 0
    menuSettings.pendingClear = false
    menuSettings.bindingCommand = nil
    waitForPadRelease = [true, true]
  }

  func closeSettings() {
    guard screen == .settings else { return }
    screen = settingsReturn
    selectedMenuAction = screen == .pause ? .resume : (screen == .results ? .restart : .start)
    menuSettings.pendingClear = false
    menuSettings.bindingCommand = nil
    waitForPadRelease = [true, true]
  }

  func confirmSetting() {
    let settings = menuSettings
    if settings.tab == .background && settings.selected == 2 {
      guard !backgrounds.choosingImage && !backgrounds.importing else { return }
      backgrounds.choosingImage = true
      backgrounds.importerRequest += 1
    } else if settings.tab == .audio && settings.selected == 6 {
      sounds.play(rows: 4)
    } else if settings.tab == .audio && settings.selected == 7 {
      operations.play(.hardDrop)
    } else if settings.tab == .input && settings.selected == settings.titles.count - 1 {
      input.reset()
    } else if settings.tab == .scores && settings.selected > 0 {
      if settings.pendingClear {
        scores.clear(settings.selected == 1 ? settings.scoreMode : nil)
        settings.pendingClear = false
      } else {
        settings.pendingClear = true
      }
    } else if settings.tab == .logs {
      DiagnosticLog.shared.record("logs_opened")
      NSWorkspace.shared.open(DiagnosticLog.shared.directory)
    } else if settings.tab == .input, let command = settings.keyboardCommand(settings.selected) {
      settings.bindingCommand = command
      settings.notice = ""
    } else {
      settings.adjust(1)
    }
  }

  private func readControllerNavigation(now: Double) {
    guard !backgrounds.choosingImage, NSApp.isActive,
      NSApp.keyWindow?.title == "Neon Stack" || settingsWindowVisible
    else {
      // Consume edges while another window is focused; returning must not replay them.
      for player in 0..<2 {
        _ = navigation[player].poll(controllerHub.readings[player].controls, now: now)
      }
      waitForPadRelease = [true, true]
      return
    }
    let controls = controllerHub.readings.map(\.controls)
    processControllerNavigation(controls, now: now)
  }

  /// Shared by live polling and deterministic navigation tests.
  func processControllerNavigation(_ controls: [Set<PadControl>], now: Double) {
    let wasRunning = running
    var handled = false
    for player in 0..<2 {
      let pressed = controls.indices.contains(player) ? controls[player] : []
      let event = navigation[player].poll(pressed, now: now)
      if pressed.isEmpty { waitForPadRelease[player] = false }
      guard !handled else { continue }
      if wasRunning {
        guard player < mode.playerCount else { continue }
        if event.menu {
          togglePause()
          handled = true
        }
        continue
      }
      guard !waitForPadRelease[player] else { continue }
      if screen == .settings {
        if event.back || event.menu {
          if menuSettings.bindingCommand != nil {
            menuSettings.bindingCommand = nil
          } else {
            closeSettings()
          }
          handled = true
        } else if event.tab != 0 {
          menuSettings.switchTab(event.tab)
          handled = true
        } else {
          if event.vertical != 0 { menuSettings.move(event.vertical) }
          if event.horizontal != 0 { menuSettings.adjust(event.horizontal) }
          if event.confirm {
            confirmSetting()
            handled = true
          }
        }
        continue
      }
      if !menuActions.contains(selectedMenuAction) { selectedMenuAction = menuActions[0] }
      if event.move != 0, let index = menuActions.firstIndex(of: selectedMenuAction) {
        selectedMenuAction =
          menuActions[(index + event.move + menuActions.count) % menuActions.count]
      }
      if event.confirm {
        activateMenu(selectedMenuAction)
        handled = true
      } else if event.back, screen == .modes {
        activateMenu(.back)
        handled = true
      } else if event.menu {
        activateMenu(selectedMenuAction)
        handled = true
      }
    }
  }

  func advanceCountdown(_ delta: Double) {
    guard running else { return }
    if countdown.advance(delta) {
      heldKeys.removeAll()
      for index in repeaters.indices { repeaters[index].clearRepeats() }
      DiagnosticLog.shared.record("countdown_finished", fields: ["round": roundID.uuidString])
    }
  }

  func perform(_ command: InputCommand, player: Int) {
    guard running, countdownNumber == nil, boards.indices.contains(player),
      let action = command.gameAction
    else { return }
    let fields = [
      "round": roundID.uuidString, "mode": mode.rawValue, "player": String(player + 1),
      "command": command.rawValue, "score": String(boards[player].score),
      "lines": String(boards[player].lines), "piece": String(describing: boards[player].active),
    ]
    DiagnosticLog.shared.record("action_begin", fields: fields)
    session.act(action, player: player)
    DiagnosticLog.shared.record(
      "action_completed",
      fields: [
        "round": roundID.uuidString, "player": String(player + 1),
        "score": String(boards[player].score), "lines": String(boards[player].lines),
        "piece": String(describing: boards[player].active),
      ])
    checkWinner()
  }

  private func checkWinner() {
    warnings.process(
      boards, active: running && countdownNumber == nil, now: ProcessInfo.processInfo.systemUptime)
    sounds.process(boards)
    operations.process(boards, now: ProcessInfo.processInfo.systemUptime)
    guard winner == nil, boards.contains(where: \.lost) else { return }
    running = false
    let winnerPlayer = mode == .solo || boards.allSatisfy(\.lost) ? nil : (boards[0].lost ? 1 : 0)
    if let winnerPlayer { roundWins[winnerPlayer] += 1 }
    newRecordPlayers = scores.save(
      ScoreRecord(
        id: roundID, mode: mode, date: Date(), elapsed: elapsed,
        players: resultPlayers,
        winnerPlayer: winnerPlayer))
    DiagnosticLog.shared.record("match_finished", fields: ["round": roundID.uuidString])
    screen = .results
    selectedMenuAction = .restart
    waitForPadRelease = [true, true]
    winner =
      mode == .solo
      ? "游戏结束"
      : (boards.allSatisfy(\.lost) ? "平局" : "玩家 \(boards[0].lost ? 2 : 1) 获胜")
  }
}
