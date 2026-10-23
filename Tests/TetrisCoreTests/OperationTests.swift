import AVFoundation
import XCTest

@testable import TetrisCore

final class OperationTests: XCTestCase {
  func testFeedbackOnlyForSuccessfulRotationAndOnePlacementSound() {
    var board = Board(seed: 1)
    board.active = Piece(kind: .t)
    _ = board.act(.clockwise)
    XCTAssertEqual(board.operationFeedback.map(\.sound), [.rotate])
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.operationFeedback.map(\.sound), [.rotate, .hardDrop])
    board.active = Piece(kind: .o)
    _ = board.act(.clockwise)
    XCTAssertEqual(board.operationSerial, 2)
    board.active = board.ghost
    _ = board.tick(0.6)
    XCTAssertEqual(board.operationFeedback.last?.sound, .lock)
    board.grid = Array(repeating: Array(repeating: 8, count: 10), count: 20)
    board.active = Piece(kind: .t)
    board.active.y = 5
    for cell in board.active.cells { board.grid[cell.y][cell.x] = 0 }
    let serial = board.operationSerial
    _ = board.act(.clockwise)
    XCTAssertEqual(board.operationSerial, serial)
  }

  func testOperationClipsDecodeAndFeedbackIsBounded() throws {
    var clips: [Data] = []
    for sound in OperationSound.allCases {
      let clip = OperationSoundComposer.compose(sound)
      let player = try AVAudioPlayer(data: clip)
      XCTAssertTrue(player.prepareToPlay())
      XCTAssertGreaterThan(player.duration, 0.05)
      XCTAssertLessThan(player.duration, 0.15)
      XCTAssertFalse(clips.contains(clip))
      clips.append(clip)
    }
    var board = Board(seed: 1)
    board.active = Piece(kind: .t)
    for _ in 0..<50 { _ = board.act(.clockwise) }
    XCTAssertEqual(board.operationSerial, 50)
    XCTAssertEqual(board.operationFeedback.count, 32)
  }
}
