import AppKit
import RealityKit
import XCTest

@testable import NeonTetris
@testable import TetrisCore

@MainActor final class PresentationTests: XCTestCase {
  func testMusicSwitchPauseResumeMuteAndStop() async throws {
    let domain = "NeonTetrisTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let music = MusicPlayer(settings: AudioSettings(defaults: defaults))
    defer { music.stop() }
    music.update(level: 1, running: true, delta: 0.1)
    try await waitForTrack(music, level: 1)
    music.update(level: 1, running: true, delta: 1)
    XCTAssertTrue(music.isPlaying)
    music.update(level: 2, running: true, delta: 0.1)
    try await waitForTrack(music, level: 2)
    XCTAssertTrue(music.trackTitle.contains("LV 2"))
    music.update(level: 2, running: false, delta: 0.1)
    XCTAssertFalse(music.isPlaying)
    music.update(level: 2, running: true, delta: 1)
    XCTAssertTrue(music.isPlaying)
    music.enabled = false
    music.update(level: 2, running: true, delta: 0.1)
    XCTAssertFalse(music.isPlaying)
    music.enabled = true
    music.update(level: 2, running: true, delta: 0.1)
    XCTAssertTrue(music.isPlaying)
    music.stop()
    XCTAssertEqual(music.activeLevel, 0)
    XCTAssertFalse(music.isPlaying)
  }

  func testRealClearEffectsExpireAndRespectReducedMotion() {
    var board = Board(seed: 1)
    for row in 16..<20 {
      board.grid[row] = Array(repeating: 8, count: 10)
      board.grid[row][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.y = 16
    board.active = piece
    _ = board.act(.hardDrop)
    let event = board.clearEvents[0]
    let root = Entity()
    let effects = ClearEffects(root: root)
    let palette: [NSColor] = Array(repeating: .systemCyan, count: 9)
    effects.emit(event, center: 0, palette: palette, reduced: false)
    XCTAssertGreaterThan(root.children.count, 100)
    effects.advance(0.2)
    XCTAssertFalse(root.children.isEmpty)
    effects.advance(1)
    XCTAssertTrue(root.children.isEmpty)
    effects.emit(event, center: 0, palette: palette, reduced: true)
    XCTAssertEqual(root.children.count, 4)
    effects.advance(0.3)
    XCTAssertTrue(root.children.isEmpty)
  }

  func testAudioSettingsPersistAndClearEventsPlayOnce() {
    let domain = "NeonTetrisTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let settings = AudioSettings(defaults: defaults)
    settings.musicEnabled = false
    settings.musicVolume = 0.24
    settings.effectsVolume = 0.51
    let restored = AudioSettings(defaults: defaults)
    XCTAssertFalse(restored.musicEnabled)
    XCTAssertTrue(restored.effectsEnabled)
    XCTAssertEqual(restored.musicVolume, 0.24)
    XCTAssertEqual(restored.effectsVolume, 0.51)

    var board = Board(seed: 1)
    for row in 16..<20 {
      board.grid[row] = Array(repeating: 8, count: 10)
      board.grid[row][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.y = 16
    board.active = piece
    _ = board.act(.hardDrop)
    let sounds = ClearSoundPlayer(settings: settings)
    defer { sounds.stop() }
    sounds.process([board])
    XCTAssertEqual(sounds.playedEventCount, 1)
    XCTAssertGreaterThan(sounds.playingCount, 0)
    sounds.process([board])
    XCTAssertEqual(sounds.playedEventCount, 1)
    sounds.reset()
    settings.effectsEnabled = false
    sounds.process([board])
    XCTAssertEqual(sounds.playingCount, 0)
    settings.effectsEnabled = true
    sounds.process([board])
    XCTAssertEqual(sounds.playedEventCount, 0)
    XCTAssertFalse(settings.musicEnabled)
  }

  private func waitForTrack(_ music: MusicPlayer, level: Int) async throws {
    for _ in 0..<100 {
      if music.activeLevel == level { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("Track generation did not finish for level \(level)")
  }
}
