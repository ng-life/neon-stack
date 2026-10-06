import XCTest

@testable import TetrisCore

final class BoardTests: XCTestCase {
  func testSevenBagAndSharedSequence() {
    var first = PieceStream(seed: 1729)
    var second = PieceStream(seed: 1729)
    for _ in 0..<20 {
      let bag = (0..<7).map { _ in first.next() }
      XCTAssertEqual(Set(bag).count, 7)
      XCTAssertEqual(bag, (0..<7).map { _ in second.next() })
    }
  }

  func testHardDropLocksAndSpawns() {
    var board = Board(seed: 12)
    let expected = board.ghost.cells
    let next = board.queue[0]
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.grid.flatMap { $0 }.filter { $0 != 0 }.count, 4)
    for cell in expected { XCTAssertNotEqual(board.grid[cell.y][cell.x], 0) }
    XCTAssertEqual(board.active.kind, next)
  }

  func testHoldOncePerPlacement() {
    var board = Board(seed: 30)
    let original = board.active.kind
    _ = board.act(.hold)
    let afterHold = board.active
    _ = board.act(.hold)
    XCTAssertEqual(board.active, afterHold)
    XCTAssertEqual(board.held, original)
    _ = board.act(.hardDrop)
    _ = board.act(.hold)
    XCTAssertEqual(board.active.kind, original)
  }

  func testTetrisCancelsGarbageAndSendsRemainder() {
    var board = Board(seed: 1)
    for y in 16..<20 {
      board.grid[y] = Array(repeating: 8, count: 10)
      board.grid[y][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.x = 3
    piece.y = 0
    board.active = piece
    board.receiveGarbage(2)
    XCTAssertEqual(board.act(.hardDrop), 2)
    XCTAssertEqual(board.lines, 4)
    XCTAssertEqual(board.pendingGarbage, 0)
    XCTAssertTrue(board.grid.flatMap { $0 }.allSatisfy { $0 == 0 })
  }

  func testGarbageAppliesWithOneHolePerRow() {
    var board = Board(seed: 1)
    board.receiveGarbage(3)
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.pendingGarbage, 0)
    for row in board.grid.suffix(3) {
      XCTAssertEqual(row.filter { $0 == 8 }.count, 9)
      XCTAssertEqual(row.filter { $0 == 0 }.count, 1)
    }
  }

  func testSRSWallKickAndFourRotations() {
    var board = Board(seed: 1)
    var piece = Piece(kind: .t)
    piece.rotation = 1
    piece.x = -1
    piece.y = 5
    board.active = piece
    XCTAssertTrue(board.fits(piece))
    _ = board.act(.counterclockwise)
    XCTAssertEqual(board.active.rotation, 0)
    XCTAssertEqual(board.active.x, 0)
    piece = Piece(kind: .i)
    piece.y = 5
    board.active = piece
    for _ in 0..<4 { _ = board.act(.clockwise) }
    XCTAssertEqual(board.active, piece)
  }

  func testLockDelayAndTopOut() {
    var board = Board(seed: 1)
    board.active = board.ghost
    XCTAssertEqual(board.tick(0.2), 0)
    XCTAssertTrue(board.grid.flatMap { $0 }.allSatisfy { $0 == 0 })
    _ = board.tick(0.31)
    XCTAssertEqual(board.grid.flatMap { $0 }.filter { $0 != 0 }.count, 4)
    board.grid = Array(repeating: Array(repeating: 8, count: 10), count: 20)
    board.active = Piece(kind: .o)
    _ = board.act(.hardDrop)
    XCTAssertTrue(board.lost)
  }
}
