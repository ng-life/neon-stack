import XCTest

@testable import TetrisCore

final class BattleFeedbackTests: XCTestCase {
  func testCombatEventMatchesCancellationAndDelivery() throws {
    var board = Board(seed: 42)
    for row in 16..<20 {
      board.grid[row] = Array(repeating: 8, count: 10)
      board.grid[row][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.y = 16
    board.active = piece
    board.receiveGarbage(3)
    XCTAssertEqual(board.act(.hardDrop), 11)
    let event = try XCTUnwrap(board.lastCombatEvent)
    XCTAssertEqual(event.sent, 11)
    XCTAssertEqual(event.cancelled, 3)
    XCTAssertEqual(event.received, 0)
    board.receiveGarbage(12)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastCombatEvent?.received, 8)
    XCTAssertEqual(board.pendingGarbage, 4)
    XCTAssertGreaterThan(board.lastCombatEvent!.serial, event.serial)
  }
  func testDangerIgnoresFallingPieceAndAnticipatesGarbage() {
    var board = Board(seed: 42)
    XCTAssertEqual(board.dangerLevel, .safe)
    board.grid[9][0] = 1
    XCTAssertEqual(board.dangerLevel, .safe)
    board.receiveGarbage(3)
    XCTAssertEqual(board.dangerLevel, .elevated)
    board.receiveGarbage(2)
    XCTAssertEqual(board.dangerLevel, .critical)
    board.grid[9][0] = 0
    XCTAssertEqual(board.dangerLevel, .safe)
  }
  func testEffectTierPrecedence() {
    func event(rows: Int, combo: Int, perfect: Bool) -> ClearEvent {
      ClearEvent(
        serial: 1, rows: Array(0..<rows),
        colors: Array(repeating: Array(repeating: 1, count: 10), count: rows), combo: combo,
        reward: PlacementReward.calculate(
          rows: rows, spin: .none, chained: false, perfectClear: perfect, combo: combo, level: 1))
    }
    XCTAssertEqual(event(rows: 1, combo: 0, perfect: false).effectTier, .normal)
    XCTAssertEqual(event(rows: 4, combo: 2, perfect: true).effectTitle, "全清")
    XCTAssertTrue(event(rows: 2, combo: 2, perfect: false).effectTitle.contains("COMBO 2"))
    XCTAssertEqual(event(rows: 4, combo: 0, perfect: false).effectTier, .tetris)
    XCTAssertEqual(event(rows: 2, combo: 2, perfect: false).effectTier, .combo)
    XCTAssertEqual(event(rows: 4, combo: 2, perfect: true).effectTier, .perfectClear)
  }
}
