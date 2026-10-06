import AVFoundation
import XCTest

@testable import TetrisCore

final class FeedbackTests: XCTestCase {
  func testClearEventPreservesOriginalRowsAndColors() {
    var board = Board(seed: 1)
    for y in 16..<20 {
      board.grid[y] = Array(repeating: 8, count: 10)
      board.grid[y][5] = 0
    }
    var piece = Piece(kind: .i)
    piece.rotation = 1
    piece.y = 16
    board.active = piece
    _ = board.act(.hardDrop)
    let event = try! XCTUnwrap(board.clearEvents.last)
    XCTAssertEqual(event.rows, [16, 17, 18, 19])
    XCTAssertEqual(event.colors.count, 4)
    XCTAssertEqual(event.colors[0][5], PieceKind.i.rawValue)
    XCTAssertEqual(event.serial, board.clearSerial)
    XCTAssertTrue(board.grid.flatMap { $0 }.allSatisfy { $0 == 0 })
    _ = board.act(.hardDrop)
    XCTAssertEqual(board.clearEvents.last, event)
  }

  func testClearSoundsDecodeAndVaryByRowCount() throws {
    var previous = Data()
    for rows in 1...4 {
      let clip = ClearSoundComposer.compose(rows: rows)
      XCTAssertNotEqual(clip, previous)
      let player = try AVAudioPlayer(data: clip)
      XCTAssertEqual(player.numberOfChannels, 1)
      XCTAssertGreaterThan(player.duration, 0.3)
      XCTAssertLessThanOrEqual(player.duration, 0.81)
      XCTAssertTrue(player.prepareToPlay())
      previous = clip
    }
  }

  func testLevelMusicIsDecodableDistinctAndLoopSized() throws {
    let first = MusicComposer.compose(level: 1, sampleRate: 8000)
    let second = MusicComposer.compose(level: 2, sampleRate: 8000)
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(first, MusicComposer.compose(level: 1, sampleRate: 8000))
    let player = try AVAudioPlayer(data: first)
    XCTAssertEqual(player.numberOfChannels, 1)
    XCTAssertEqual(
      player.duration, 32 * 60 / Double(MusicComposer.tempo(level: 1)), accuracy: 0.001)
    XCTAssertTrue(player.prepareToPlay())
    let secondPlayer = try AVAudioPlayer(data: second)
    XCTAssertLessThan(secondPlayer.duration, player.duration)
    XCTAssertNotEqual(MusicComposer.title(level: 1), MusicComposer.title(level: 2))
  }
}
