import XCTest

@testable import TetrisCore

final class GameSessionTests: XCTestCase {
  func testSoloHasOneBoardAndIgnoresOtherPlayer() {
    var game = GameSession(mode: .solo, seed: 42)
    XCTAssertEqual(game.boards.count, 1)
    let original = game.boards[0].active
    game.act(.hardDrop, player: 1)
    XCTAssertEqual(game.boards[0].active, original)
    game.act(.hardDrop, player: 0)
    XCTAssertEqual(game.boards[0].grid.flatMap { $0 }.filter { $0 != 0 }.count, 4)
  }

  func testSoloClearsWithoutGarbage() {
    var game = GameSession(mode: .solo, seed: 42)
    prepareTetris(&game.boards[0])
    game.act(.hardDrop, player: 0)
    XCTAssertEqual(game.boards[0].lines, 4)
    XCTAssertEqual(game.boards[0].score, 2800)
    XCTAssertEqual(game.boards[0].pendingGarbage, 0)
    game.tick(1)
    XCTAssertFalse(game.isOver)
  }

  func testVersusStillRoutesAttacks() {
    var game = GameSession(mode: .versus, seed: 42)
    XCTAssertEqual(game.boards.count, 2)
    XCTAssertEqual(game.boards[0].active, game.boards[1].active)
    prepareTetris(&game.boards[0])
    game.act(.hardDrop, player: 0)
    XCTAssertEqual(game.boards[1].pendingGarbage, 14)
    XCTAssertEqual(game.boards[0].pendingGarbage, 0)
  }

  func testSoloTopOutStopsAdvancement() {
    var game = GameSession(mode: .solo, seed: 42)
    game.boards[0].grid = Array(repeating: Array(repeating: 8, count: 10), count: 20)
    game.act(.hardDrop, player: 0)
    XCTAssertTrue(game.isOver)
    let score = game.boards[0].score
    game.act(.hardDrop, player: 0)
    game.tick(1)
    XCTAssertEqual(game.boards[0].score, score)
    XCTAssertFalse(GameSession(mode: .solo, seed: 42).isOver)
  }

  func testStatisticsCountFourLineClearsBeyondEffectHistory() {
    var game = GameSession(mode: .versus, seed: 42)
    for _ in 0..<10 {
      prepareTetris(&game.boards[0])
      game.act(.hardDrop, player: 0)
    }
    XCTAssertEqual(game.boards[0].fourLineClears, 10)
    XCTAssertEqual(game.boards[0].lines, 40)
    XCTAssertEqual(game.boards[0].clearEvents.count, 8)
    XCTAssertEqual(game.sentAttacks[0], game.boards[1].pendingGarbage)
    XCTAssertEqual(game.sentAttacks[1], 0)
  }

  func testAttackStatisticsExcludeCancellationAndIncludeTimedLocks() {
    var game = GameSession(mode: .versus, seed: 42)
    prepareTetris(&game.boards[0])
    game.boards[0].receiveGarbage(3)
    game.act(.hardDrop, player: 0)
    XCTAssertEqual(game.sentAttacks, [11, 0])
    XCTAssertEqual(game.boards[1].pendingGarbage, 11)
    prepareTetris(&game.boards[0])
    let before = game.sentAttacks[0]
    game.tick(0.5)
    XCTAssertGreaterThan(game.sentAttacks[0], before)
    XCTAssertEqual(game.sentAttacks[0], game.boards[1].pendingGarbage)
    XCTAssertEqual(game.boards[0].fourLineClears, 2)
    var solo = GameSession(mode: .solo, seed: 42)
    prepareTetris(&solo.boards[0])
    solo.act(.hardDrop, player: 0)
    XCTAssertEqual(solo.sentAttacks, [0])
  }

  private func prepareTetris(_ board: inout Board) {
    for y in 16..<20 {
      board.grid[y] = Array(repeating: 8, count: 10)
      board.grid[y][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.x = 3
    piece.y = 16
    board.active = piece
  }
}
