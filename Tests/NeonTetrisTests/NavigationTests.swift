import XCTest

@testable import NeonTetris

@MainActor final class NavigationTests: XCTestCase {
  private func withMatch(_ body: (MatchStore) -> Void) {
    let domain = "NavigationTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let audio = AudioSettings(defaults: defaults)
    audio.musicEnabled = false
    audio.effectsEnabled = false
    audio.operationsEnabled = false
    body(
      MatchStore(
        settings: audio, input: InputSettings(defaults: defaults),
        scores: ScoreStore(defaults: defaults), startRuntime: false))
  }
  private func press(_ controls: Set<PadControl>, match: MatchStore, player: Int = 0, now: Double) {
    match.processControllerNavigation([[], []], now: now)
    var players: [Set<PadControl>] = [[], []]
    players[player] = controls
    match.processControllerNavigation(players, now: now + 0.01)
  }
  func testMainModeSelectionCountdownPauseContinueAndEnd() {
    withMatch { match in
      XCTAssertEqual(match.menuActions, [.start, .settings])
      press([.a], match: match, player: 1, now: 0)
      XCTAssertEqual(match.screen, .modes)
      XCTAssertFalse(match.started)
      press([.down], match: match, now: 1)
      XCTAssertEqual(match.selectedMenuAction, .versus)
      press([.a], match: match, player: 1, now: 2)
      XCTAssertEqual(match.screen, .playing)
      XCTAssertEqual(match.mode, .versus)
      XCTAssertEqual(match.countdownNumber, 3)
      match.processControllerNavigation([[], [.a]], now: 3)
      XCTAssertEqual(match.boards[1].score, 0)
      press([.menu], match: match, now: 4)
      XCTAssertEqual(match.menuActions, [.resume, .lobby, .settings])
      XCTAssertFalse(match.running)
      let id = match.roundID
      press([.a], match: match, now: 5)
      XCTAssertEqual(match.roundID, id)
      XCTAssertTrue(match.running)
      press([.menu], match: match, now: 6)
      press([.down], match: match, now: 7)
      press([.a], match: match, now: 8)
      XCTAssertEqual(match.screen, .main)
      XCTAssertFalse(match.started)
      XCTAssertTrue(match.scores.records(.versus).isEmpty)
    }
  }
  func testModeSelectionBackAndHeldConfirmDoesNotSkipSelection() {
    withMatch { match in
      press([.a], match: match, now: 0)
      match.processControllerNavigation([[.a], []], now: 5)
      XCTAssertFalse(match.started)
      XCTAssertEqual(match.screen, .modes)
      press([.b], match: match, now: 6)
      XCTAssertEqual(match.screen, .main)
    }
  }
  func testSettingsTabNavigationAdjustmentPersistenceAndReturn() {
    withMatch { match in
      match.openSettings()
      XCTAssertEqual(match.screen, .settings)
      press([.a], match: match, now: 0)
      XCTAssertTrue(match.menuSettings.audio.musicEnabled)
      press([.down], match: match, now: 1)
      let oldVolume = match.menuSettings.audio.musicVolume
      press([.right], match: match, now: 2)
      XCTAssertEqual(match.menuSettings.audio.musicVolume, oldVolume + 0.05, accuracy: 0.001)
      press([.rb], match: match, now: 3)
      XCTAssertEqual(match.menuSettings.tab, .input)
      match.processControllerNavigation([[.rb], []], now: 4)
      XCTAssertEqual(match.menuSettings.tab, .input, "Held shoulder cannot repeatedly switch tabs")
      press([.down], match: match, now: 5)
      let oldDelay = match.input.delay
      press([.right], match: match, now: 6)
      XCTAssertEqual(match.input.delay, oldDelay + 0.01, accuracy: 0.001)
      press([.lb], match: match, now: 7)
      XCTAssertEqual(match.menuSettings.tab, .audio)
      press([.b], match: match, now: 8)
      XCTAssertEqual(match.screen, .main)
      match.start(seed: 42)
      match.advanceCountdown(1)
      match.openSettings()
      XCTAssertFalse(match.running)
      match.advanceCountdown(10)
      XCTAssertEqual(match.countdownNumber, 2)
      press([.b], match: match, now: 9)
      XCTAssertEqual(match.screen, .pause)
      XCTAssertFalse(match.running)
    }
  }
  func testSettingsMappingAndClearRequiresSecondConfirmation() {
    withMatch { match in
      match.openSettings()
      match.menuSettings.tab = .input
      match.menuSettings.selected = 4
      let before = match.input.mapping(player: 0, control: .left)
      match.menuSettings.adjust(1)
      XCTAssertNotEqual(match.input.mapping(player: 0, control: .left), before)
      XCTAssertTrue(match.input.configuration.isValid)
      match.menuSettings.tab = .scores
      match.menuSettings.selected = 1
      match.confirmSetting()
      XCTAssertTrue(match.menuSettings.pendingClear)
      match.menuSettings.move(1)
      XCTAssertFalse(match.menuSettings.pendingClear)
    }
  }
  func testKeyboardMenuAndSettingsShortcuts() {
    withMatch { match in
      XCTAssertEqual(match.confirmHint, "Enter")
      XCTAssertTrue(match.settingsHint.contains("PgUp / PgDn"))
      match.handleMenuKey(36)
      XCTAssertEqual(match.screen, .modes)
      match.handleMenuKey(53)
      XCTAssertEqual(match.screen, .main)
      match.handleMenuKey(125)
      XCTAssertEqual(match.selectedMenuAction, .settings)
      match.handleMenuKey(36)
      XCTAssertEqual(match.screen, .settings)
      match.handleMenuKey(121)
      XCTAssertEqual(match.menuSettings.tab, .input)
      match.handleMenuKey(125)
      let delay = match.input.delay
      match.handleMenuKey(124)
      XCTAssertEqual(match.input.delay, delay + 0.01, accuracy: 0.001)
      match.handleMenuKey(116)
      XCTAssertEqual(match.menuSettings.tab, .audio)
      match.handleMenuKey(53)
      XCTAssertEqual(match.screen, .main)
    }
  }

  func testKeyboardBindingCaptureRejectsConflictsAndCancels() {
    withMatch { match in
      match.openSettings()
      let settings = match.menuSettings
      settings.tab = .input
      settings.selected = 4 + PadControl.allCases.count
      match.handleMenuKey(36)
      XCTAssertEqual(settings.bindingCommand, .left)
      settings.captureKey(2)
      XCTAssertEqual(settings.bindingCommand, .left)
      XCTAssertEqual(match.input.key(player: 0, command: .left), 0)
      settings.captureKey(3)
      XCTAssertNil(settings.bindingCommand)
      XCTAssertEqual(match.input.key(player: 0, command: .left), 3)
      settings.bindingCommand = .right
      settings.captureKey(53)
      XCTAssertNil(settings.bindingCommand)
      XCTAssertEqual(match.input.key(player: 0, command: .right), 2)
    }
  }

  func testRepeatTimingAndSoloSecondControllerIsolation() {
    var navigation = ControllerNavigation()
    XCTAssertEqual(navigation.poll([.down], now: 0).vertical, 1)
    XCTAssertEqual(navigation.poll([.down], now: 0.2).vertical, 0)
    XCTAssertEqual(navigation.poll([.down], now: 0.3).vertical, 1)
    withMatch { match in
      match.start(seed: 42)
      press([.menu], match: match, player: 1, now: 0)
      XCTAssertTrue(match.running)
    }
  }
}
