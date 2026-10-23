import XCTest

@testable import TetrisCore

final class RewardTests: XCTestCase {
  func testFullTSpinDoubleRequiresRotation() {
    var board = Board(seed: 1)
    prepareSpin(&board, mini: false)
    _ = board.act(.clockwise)
    XCTAssertEqual(board.active.rotation, 2)
    XCTAssertEqual(board.act(.hardDrop), 4)
    XCTAssertEqual(board.lastReward?.spin, .full)
    XCTAssertEqual(board.lastReward?.rows, 2)
    XCTAssertEqual(board.score, 1200)
    XCTAssertEqual(board.clearEvents.last?.reward, board.lastReward)

    var withoutRotation = Board(seed: 1)
    prepareSpin(&withoutRotation, mini: false)
    withoutRotation.active.rotation = 2
    _ = withoutRotation.act(.hardDrop)
    XCTAssertEqual(withoutRotation.lastReward?.spin, SpinKind.none)
    XCTAssertEqual(withoutRotation.score, 300)
  }

  func testMiniSingleAndNoClearSpin() {
    var board = Board(seed: 1)
    prepareSpin(&board, mini: true)
    _ = board.act(.counterclockwise)
    XCTAssertEqual(board.active.rotation, 0)
    XCTAssertEqual(board.act(.hardDrop), 0)
    XCTAssertEqual(board.lastReward?.spin, .mini)
    XCTAssertEqual(board.score, 200)
    XCTAssertEqual(board.lines, 1)

    var noClear = Board(seed: 1)
    prepareSpin(&noClear, mini: false)
    noClear.grid[18] = Array(repeating: 0, count: 10)
    noClear.grid[19][0] = 0
    _ = noClear.act(.clockwise)
    _ = noClear.act(.hardDrop)
    XCTAssertEqual(noClear.lastReward?.spin, .full)
    XCTAssertEqual(noClear.score, 400)
    XCTAssertTrue(noClear.clearEvents.isEmpty)
  }

  func testHardDropMovementInvalidatesRotationButZeroDistancePreservesIt() {
    var board = Board(seed: 1)
    prepareSpin(&board, mini: false)
    // Rotate in open space, then drop into the same three-corner cavity.
    board.active.y = 5
    _ = board.act(.clockwise)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)
  }

  func testTranslationAndHoldInvalidateRotation() {
    var board = Board(seed: 1)
    var piece = Piece(kind: .t)
    piece.rotation = 1
    piece.y = 5
    board.active = piece
    _ = board.act(.clockwise)
    _ = board.act(.left)
    // Create a cavity at the translated position, without a new rotation.
    prepareSpin(&board, mini: false)
    board.active.rotation = 2
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)

    prepareSpin(&board, mini: false)
    _ = board.act(.clockwise)
    _ = board.act(.hold)
    prepareSpin(&board, mini: false)
    board.active.rotation = 2
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)
  }

  func testMixedDifficultClearsChainAndNoClearPreservesChain() {
    var board = Board(seed: 1)
    prepareTetris(&board, perfect: false)
    XCTAssertEqual(board.act(.hardDrop), 4)
    XCTAssertFalse(board.lastReward!.backToBack)
    board.grid = emptyGrid()
    board.active = Piece(kind: .o)
    _ = board.act(.hardDrop)
    prepareSpin(&board, mini: false)
    XCTAssertEqual(board.act(.clockwise), 0)
    XCTAssertEqual(board.act(.hardDrop), 5)
    XCTAssertTrue(board.lastReward!.backToBack)
    XCTAssertEqual(board.lastReward!.points, 1800)
    prepareTetris(&board, perfect: false)
    XCTAssertEqual(board.act(.hardDrop), 5)
    XCTAssertTrue(board.lastReward!.backToBack)
    XCTAssertEqual(board.lastReward!.points, 1250)  // 1200 B2B + 50 combo.
  }

  func testOrdinaryClearBreaksChainAndNoClearResetsCombo() {
    var board = Board(seed: 1)
    prepareTetris(&board, perfect: false)
    _ = board.act(.hardDrop)
    board.grid = emptyGrid()
    board.grid[19] = Array(repeating: 8, count: 10)
    board.grid[19][4] = 0
    board.grid[19][5] = 0
    board.grid[10][0] = 8
    board.active = Piece(kind: .o)
    board.active.y = 18
    _ = board.act(.hardDrop)
    XCTAssertFalse(board.lastReward!.backToBack)
    XCTAssertEqual(board.lastReward!.points, 150)
    board.grid = emptyGrid()
    board.active = Piece(kind: .o)
    _ = board.act(.hardDrop)
    prepareTetris(&board, perfect: false)
    _ = board.act(.hardDrop)
    XCTAssertFalse(board.lastReward!.backToBack)
    XCTAssertEqual(board.lastReward!.points, 800)
  }

  func testPerfectClearBonusB2BAndGarbageCancellation() {
    var board = Board(seed: 1)
    prepareTetris(&board, perfect: true)
    board.receiveGarbage(12)
    XCTAssertEqual(board.act(.hardDrop), 2)
    XCTAssertEqual(board.pendingGarbage, 0)
    XCTAssertTrue(board.lastReward!.perfectClear)
    XCTAssertEqual(board.score, 2800)
    prepareTetris(&board, perfect: true)
    XCTAssertEqual(board.act(.hardDrop), 15)
    XCTAssertEqual(board.lastReward!.points, 4450)  // 1200 + 3200 + 50.
    XCTAssertTrue(board.lastReward!.backToBack)
  }

  func testFifthSRSKickPromotesMiniToFull() {
    var board = Board(seed: 1)
    for cell in [Cell(4, 15), Cell(5, 15), Cell(6, 17), Cell(6, 19), Cell(4, 19)] {
      board.grid[cell.y][cell.x] = 8
    }
    var piece = Piece(kind: .t)
    piece.rotation = 2
    piece.y = 15
    board.active = piece
    _ = board.act(.clockwise)
    XCTAssertEqual(board.active.x, 4)
    XCTAssertEqual(board.active.y, 17)
    XCTAssertEqual(board.active.rotation, 3)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, .full)
    XCTAssertEqual(board.score, 400)
  }

  func testTwoCornersDoNotQualifyAndFailedMovementPreservesSpin() {
    var board = Board(seed: 1)
    prepareSpin(&board, mini: false)
    board.grid[17][3] = 0
    _ = board.act(.clockwise)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)

    prepareSpin(&board, mini: false)
    _ = board.act(.clockwise)
    let rotated = board.active
    _ = board.act(.left)  // Blocked by the cavity; does not replace the last successful action.
    XCTAssertEqual(board.active, rotated)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, .full)
  }

  func testSoftDropInvalidatesRotationAndSpawnClearsIt() {
    var board = Board(seed: 1)
    var piece = Piece(kind: .t)
    piece.rotation = 1
    piece.y = 5
    board.active = piece
    _ = board.act(.clockwise)
    _ = board.act(.softDrop)
    prepareSpin(&board, mini: false)
    board.active.rotation = 2
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)
    prepareSpin(&board, mini: false)
    _ = board.act(.clockwise)
    _ = board.act(.hardDrop)
    prepareSpin(&board, mini: false)
    board.active.rotation = 2
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.lastReward?.spin, SpinKind.none)
  }

  func testScoreTablesAndLevelMultiplier() {
    let full = [400, 800, 1200, 1600]
    let mini = [100, 200, 400]
    for rows in 0...3 {
      let reward = PlacementReward.calculate(
        rows: rows, spin: .full, chained: true,
        perfectClear: false, combo: 0, level: 2)
      XCTAssertEqual(reward.points, full[rows] * (rows > 0 ? 3 : 2))
      XCTAssertEqual(reward.backToBack, rows > 0)
    }
    for rows in 0...2 {
      XCTAssertEqual(
        PlacementReward.calculate(
          rows: rows, spin: .mini, chained: false,
          perfectClear: false, combo: 0, level: 1
        ).points, mini[rows])
    }
    for rows in 1...4 {
      let normal = [0, 100, 300, 500, 800][rows]
      let bonus = [0, 800, 1200, 1800, 2000][rows]
      XCTAssertEqual(
        PlacementReward.calculate(
          rows: rows, spin: .none, chained: false,
          perfectClear: true, combo: 0, level: 1
        ).points, normal + bonus)
    }
  }

  private func emptyGrid() -> [[Int]] {
    Array(repeating: Array(repeating: 0, count: 10), count: 20)
  }

  private func prepareTetris(_ board: inout Board, perfect: Bool) {
    board.grid = emptyGrid()
    for row in 16..<20 {
      board.grid[row] = Array(repeating: 8, count: 10)
      board.grid[row][5] = 0
    }
    if !perfect { board.grid[10][0] = 8 }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.y = 16
    board.active = piece
  }

  private func prepareSpin(_ board: inout Board, mini: Bool) {
    board.grid = emptyGrid()
    board.grid[18] = Array(repeating: 8, count: 10)
    for x in 3...5 { board.grid[18][x] = 0 }
    board.grid[17][3] = 8
    if mini {
      board.grid[19][3] = 8
      board.grid[19][5] = 8
    } else {
      board.grid[19] = Array(repeating: 8, count: 10)
      board.grid[19][4] = 0
    }
    var piece = Piece(kind: .t)
    piece.rotation = 1
    piece.y = 17
    board.active = piece
  }
}
