import XCTest

@testable import NeonTetris
@testable import TetrisCore

@MainActor final class AudioLifetimeTests: XCTestCase {
  func testRapidPlaybackCompletionAndRestartDoesNotUseReleasedPlayers() async throws {
    let domain = "NeonAudioLifetimeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let settings = AudioSettings(defaults: defaults)
    settings.operationsVolume = 0.01
    settings.effectsVolume = 0.01
    let operations = OperationSoundPlayer(settings: settings)
    let clears = ClearSoundPlayer(settings: settings)
    defer {
      operations.stop()
      clears.stop()
    }
    for step in 0..<50 {
      autoreleasepool {
        XCTAssertTrue(operations.play(.rotate))
        if step % 7 == 0 { XCTAssertTrue(clears.play(rows: step % 4 + 1)) }
        // Finish on the audio thread while the main-runloop completion is still queued.
        Thread.sleep(forTimeInterval: 0.08)
        operations.process([], now: ProcessInfo.processInfo.systemUptime)
        clears.process([])
        if step % 11 == 0 {
          operations.reset()
          clears.reset()
        }
      }
      try await Task.sleep(for: .milliseconds(1))
    }
    operations.stop()
    clears.stop()
    // Drain pending main-runloop audio callbacks after stop and release.
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(operations.playingCount, 0)
    XCTAssertEqual(clears.playingCount, 0)
  }
  func testStoppedAndCompletedVoicesRemainRetainedForQueuedCallbacks() async throws {
    let domain = "NeonAudioLifetimeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let settings = AudioSettings(defaults: defaults)
    settings.operationsVolume = 0.01
    settings.effectsVolume = 0.01
    let operations = OperationSoundPlayer(settings: settings)
    let clears = ClearSoundPlayer(settings: settings)
    autoreleasepool {
      XCTAssertTrue(operations.play(.rotate))
      XCTAssertTrue(clears.play(rows: 1))
      // Keep the main thread busy until the short clip finishes on the audio thread.
      Thread.sleep(forTimeInterval: 0.1)
      operations.process([], now: ProcessInfo.processInfo.systemUptime)
      XCTAssertEqual(operations.retainedVoiceCount, 1)
      operations.reset()
      clears.reset()
      XCTAssertEqual(operations.retainedVoiceCount, 1)
      XCTAssertEqual(clears.retainedVoiceCount, 1)
    }
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(operations.playingCount, 0)
    XCTAssertEqual(clears.playingCount, 0)
  }

  func testOverlappingClipsReuseBoundedVoicesAcrossResets() async throws {
    let domain = "NeonAudioLifetimeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let settings = AudioSettings(defaults: defaults)
    settings.operationsVolume = 0.01
    settings.effectsVolume = 0.01
    let operations = OperationSoundPlayer(settings: settings)
    let clears = ClearSoundPlayer(settings: settings)
    for step in 0..<60 {
      for sound in OperationSound.allCases { XCTAssertTrue(operations.play(sound)) }
      for rows in 1...4 { XCTAssertTrue(clears.play(rows: rows)) }
      XCTAssertLessThanOrEqual(operations.playingCount, 4)
      XCTAssertLessThanOrEqual(clears.playingCount, 8)
      XCTAssertLessThanOrEqual(operations.retainedVoiceCount, 6)
      XCTAssertLessThanOrEqual(clears.retainedVoiceCount, 8)
      if step % 10 == 0 {
        let before = (operations.retainedVoiceCount, clears.retainedVoiceCount)
        operations.reset()
        clears.reset()
        XCTAssertEqual(operations.retainedVoiceCount, before.0)
        XCTAssertEqual(clears.retainedVoiceCount, before.1)
      }
      try await Task.sleep(for: .milliseconds(5))
    }
    operations.stop()
    clears.stop()
    try await Task.sleep(for: .milliseconds(100))
  }

}
