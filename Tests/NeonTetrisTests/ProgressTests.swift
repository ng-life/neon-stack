import TetrisCore
import XCTest

@testable import NeonTetris

@MainActor final class ProgressTests: XCTestCase {
  func testModeRecordsPersistenceTiesAndClearing() {
    let domain = "ProgressTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = ScoreStore(defaults: defaults)
    func record(_ mode: GameMode, _ score: Int) -> ScoreRecord {
      ScoreRecord(
        id: UUID(), mode: mode, date: Date(), elapsed: 12,
        players: (0..<mode.playerCount).map { PlayerScore(score: score - $0, lines: 4) },
        winnerPlayer: mode == .versus ? 0 : nil)
    }
    let first = record(.solo, 100)
    XCTAssertEqual(store.save(first), [0])
    XCTAssertTrue(store.save(first).isEmpty)
    XCTAssertTrue(store.save(record(.solo, 100)).isEmpty)
    XCTAssertEqual(store.save(record(.versus, 200)), [0])
    let restored = ScoreStore(defaults: defaults)
    XCTAssertEqual(restored.best(.solo), 100)
    XCTAssertEqual(restored.best(.versus), 200)
    XCTAssertEqual(restored.records(.solo).count, 2)
    for _ in 0..<105 { restored.save(record(.solo, 10)) }
    XCTAssertEqual(restored.records(.solo).count, 100)
    XCTAssertEqual(restored.best(.solo), 100)
    restored.clear(.solo)
    XCTAssertNil(ScoreStore(defaults: defaults).best(.solo))
    XCTAssertEqual(restored.best(.versus), 200)
    restored.clear()
    XCTAssertTrue(ScoreStore(defaults: defaults).records(.versus).isEmpty)
  }

  func testCountdownBlocksActionsAndSavesFinishedRoundOnce() {
    let domain = "CountdownTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let audio = AudioSettings(defaults: defaults)
    audio.musicEnabled = false
    audio.effectsEnabled = false
    audio.operationsEnabled = false
    let scores = ScoreStore(defaults: defaults)
    let match = MatchStore(
      settings: audio, input: InputSettings(defaults: defaults), scores: scores, startRuntime: false
    )
    match.start(seed: 42)
    let original = match.boards[0].active
    for command in InputCommand.allCases { match.perform(command, player: 0) }
    XCTAssertEqual(match.boards[0].active, original)
    XCTAssertEqual(match.boards[0].score, 0)
    match.advanceCountdown(1)
    XCTAssertEqual(match.countdownNumber, 2)
    match.togglePause()
    match.advanceCountdown(10)
    XCTAssertEqual(match.countdownNumber, 2)
    match.togglePause()
    match.advanceCountdown(1)
    XCTAssertEqual(match.countdownNumber, 1)
    match.advanceCountdown(1)
    XCTAssertNil(match.countdownNumber)
    for _ in 0..<40 { match.perform(.drop, player: 0) }
    XCTAssertNotNil(match.winner)
    XCTAssertEqual(scores.records(.solo).count, 1)
    XCTAssertEqual(match.newRecordPlayers, [0])
    match.perform(.drop, player: 0)
    XCTAssertEqual(scores.records(.solo).count, 1)
    match.start(seed: 43)
    XCTAssertEqual(match.countdownNumber, 3)
    match.returnToLobby()
    XCTAssertNil(match.countdownNumber)
    XCTAssertEqual(ScoreStore(defaults: defaults).records(.solo).count, 1)
  }

  func testBoundedLogRotationAndUncleanSessionDetection() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let log = DiagnosticLog(directory: directory, limit: 250, enabled: true)
    log.startSession()
    DiagnosticLog(directory: directory, limit: 250, enabled: true).startSession()
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    let text = try files.filter { $0.pathExtension == "jsonl" }.map {
      try String(contentsOf: $0, encoding: .utf8)
    }.joined()
    XCTAssertTrue(text.contains("previous_session_unclosed"))
    for index in 0..<40 { log.record("action", fields: ["index": String(index)]) }
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jsonl" }.count, 3)
    log.finishSession()
    let marker =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: directory.appendingPathComponent("session.json")))
      as! [String: String]
    XCTAssertEqual(marker["clean"], "true")
  }
}
