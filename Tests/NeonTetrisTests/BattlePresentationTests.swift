import AppKit
import RealityKit
import XCTest

@testable import NeonTetris
@testable import TetrisCore

@MainActor final class BattlePresentationTests: XCTestCase {
  func testDangerSoundIsTransitionBasedMutedAndRateLimited() {
    let domain = "DangerTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let audio = AudioSettings(defaults: defaults)
    audio.warningVolume = 0.01
    let sounds = DangerSoundPlayer(settings: audio)
    defer { sounds.stop() }
    var board = Board(seed: 42)
    board.grid[6][0] = 1
    sounds.process([board], active: true, now: 1)
    XCTAssertEqual(sounds.playedCount, 1)
    board.grid[3][0] = 1
    sounds.process([board], active: true, now: 2)
    XCTAssertEqual(sounds.playedCount, 1, "Alert transitions are rate limited")
    board.grid[3][0] = 0
    sounds.process([board], active: true, now: 3)
    sounds.process([board], active: true, now: 9)
    XCTAssertEqual(sounds.playedCount, 1)
    board.grid[3][0] = 1
    sounds.process([board], active: true, now: 10)
    XCTAssertEqual(sounds.playedCount, 2)
    audio.warningEnabled = false
    board.grid[3][0] = 0
    sounds.process([board], active: true, now: 20)
    audio.warningEnabled = true
    sounds.process([board], active: true, now: 21)
    XCTAssertEqual(sounds.playedCount, 2, "Muted transitions must not be replayed")
    board.grid[3][0] = 1
    sounds.process([board], active: false, now: 30)
    sounds.process([board], active: true, now: 31)
    XCTAssertEqual(sounds.playedCount, 2, "Resume must not replay the alert")
    XCTAssertTrue(AudioSettings(defaults: defaults).warningEnabled)
    XCTAssertEqual(AudioSettings(defaults: defaults).warningVolume, 0.01, accuracy: 0.001)
  }
  func testReducedEffectsPersistAndRendererUsesOpenGhostOutline() {
    let domain = "VisualTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    func settings() -> GameMenuSettings {
      GameMenuSettings(
        audio: AudioSettings(defaults: defaults), input: InputSettings(defaults: defaults),
        scores: ScoreStore(defaults: defaults), backgrounds: BackgroundSettings(defaults: defaults),
        defaults: defaults)
    }
    let preferences = settings()
    preferences.reducedEffects = true
    XCTAssertTrue(settings().reducedEffects)
    let renderer = ArenaView.Renderer()
    let view = ARView(frame: .zero)
    renderer.setup(view, playerCount: 1)
    var board = Board(seed: 42)
    renderer.update([board], reducedEffects: false)
    XCTAssertEqual(renderer.ghostOutlines[0].count, 4)
    XCTAssertEqual(renderer.ghostOutlines[0][0].children.count, 4)
    XCTAssertTrue(renderer.ghostOutlines[0].contains { $0.isEnabled })
    board.grid[3][0] = 1
    renderer.update([board], reducedEffects: true)
    XCTAssertTrue(renderer.dangerEdges[0].allSatisfy(\.isEnabled))
    board.grid[3][0] = 0
    renderer.update([board], reducedEffects: false)
    XCTAssertTrue(renderer.dangerEdges[0].allSatisfy { !$0.isEnabled })
  }
  func testTierEffectsStayAboveBoardAndAreBounded() {
    let root = Entity()
    let effects = ClearEffects(root: root)
    let palette = Array(repeating: NSColor.cyan, count: 9)
    for combo in 0..<10 {
      let reward = PlacementReward.calculate(
        rows: 4, spin: .none, chained: combo > 0, perfectClear: true, combo: combo, level: 1)
      effects.emit(
        ClearEvent(
          serial: combo, rows: [16, 17, 18, 19],
          colors: Array(repeating: Array(repeating: 1, count: 10), count: 4), combo: combo,
          reward: reward), center: 0, palette: palette, reduced: false)
      XCTAssertLessThanOrEqual(root.children.count, 600)
    }
    effects.removeAll()
    XCTAssertTrue(root.children.isEmpty)
    var counts: [Int] = []
    for (rows, combo, perfect) in [(1, 0, false), (4, 0, false), (2, 2, false), (4, 0, true)] {
      let reward = PlacementReward.calculate(
        rows: rows, spin: .none, chained: false, perfectClear: perfect, combo: combo, level: 1)
      let event = ClearEvent(
        serial: 1, rows: Array((20 - rows)..<20),
        colors: Array(repeating: Array(repeating: 1, count: 10), count: rows), combo: combo,
        reward: reward)
      effects.emit(event, center: 0, palette: palette, reduced: false)
      counts.append(root.children.count)
      XCTAssertGreaterThan(
        Array(root.children).last!.position.y, 10, "Reward text must stay above the board")
      XCTAssertLessThanOrEqual(
        Array(root.children).last!.visualBounds(relativeTo: nil).extents.x, 9.01)
      effects.removeAll()
      effects.emit(event, center: 0, palette: palette, reduced: true)
      XCTAssertEqual(root.children.count, rows, "Reduced motion retains only thin row beams")
      effects.removeAll()
    }
    XCTAssertEqual(Set(counts).count, 4, "Each reward tier has its own visual intensity")
    XCTAssertGreaterThan(counts[3], counts[1])
  }
}
