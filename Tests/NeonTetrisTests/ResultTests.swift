import TetrisCore
import XCTest

@testable import NeonTetris

@MainActor final class ResultTests: XCTestCase {
  func testRatesLegacyDecodeAndDetailedStatisticsPersistence() throws {
    let legacy = try JSONDecoder().decode(
      PlayerScore.self, from: Data(#"{"score":100,"lines":20}"#.utf8))
    XCTAssertNil(legacy.fourLineClears)
    XCTAssertNil(legacy.attackSent)
    XCTAssertNil(legacy.roundWins)
    XCTAssertEqual(legacy.linesPerMinute(elapsed: 120), 10)
    XCTAssertEqual(legacy.linesPerMinute(elapsed: 0), 0)
    XCTAssertEqual(legacy.linesPerMinute(elapsed: .infinity), 0)
    let domain = "ResultTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let stats = PlayerScore(score: 500, lines: 20, fourLineClears: 3, attackSent: 12, roundWins: 2)
    let record = ScoreRecord(
      id: UUID(), mode: .versus, date: Date(), elapsed: 120, players: [stats, stats],
      winnerPlayer: 0)
    ScoreStore(defaults: defaults).save(record)
    XCTAssertEqual(ScoreStore(defaults: defaults).records(.versus).first, record)
  }

  func testVersusWinsAccumulateAcrossRestartAndResetOnEnd() {
    let domain = "ResultRoundTests.\(UUID())"
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
    match.selectMode(.versus)
    for round in 1...2 {
      match.start(seed: UInt64(round))
      match.advanceCountdown(3)
      for _ in 0..<40 { match.perform(.drop, player: 0) }
      XCTAssertEqual(match.screen, .results)
      XCTAssertEqual(match.roundWins, [0, round])
      XCTAssertEqual(scores.records(.versus).first?.players[1].roundWins, round)
      XCTAssertEqual(match.resultPlayers[0].fourLineClears, 0)
      XCTAssertEqual(match.resultPlayers[0].attackSent, 0)
      match.perform(.drop, player: 0)
      XCTAssertEqual(match.roundWins, [0, round])
    }
    XCTAssertEqual(scores.records(.versus).count, 2)
    match.returnToLobby()
    XCTAssertEqual(match.roundWins, [0, 0])
  }
}
