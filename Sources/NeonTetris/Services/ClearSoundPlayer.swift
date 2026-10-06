import AVFoundation
import OSLog
import TetrisCore

@MainActor final class ClearSoundPlayer {
  private let settings: AudioSettings
  private let clips = (1...4).map { ClearSoundComposer.compose(rows: $0) }
  private var players: [AVAudioPlayer] = []
  private var serials: [Int] = []
  private(set) var playedEventCount = 0
  var playingCount: Int { players.filter(\.isPlaying).count }
  private let logger = Logger(subsystem: "com.nglife.neon-tetris", category: "clear-sound")

  init(settings: AudioSettings) { self.settings = settings }

  func process(_ boards: [Board]) {
    players.removeAll { !$0.isPlaying }
    if !settings.effectsEnabled { stop() }
    for player in players { player.volume = settings.effectsVolume }
    if serials.count != boards.count { serials = Array(repeating: 0, count: boards.count) }
    for index in boards.indices {
      // Muted events are still consumed, so re-enabling never replays old clears.
      for event in boards[index].clearEvents where event.serial > serials[index] {
        if play(rows: event.rows.count) { playedEventCount += 1 }
      }
      serials[index] = boards[index].clearSerial
    }
  }

  @discardableResult func play(rows: Int) -> Bool {
    guard settings.effectsEnabled, settings.effectsVolume > 0 else { return false }
    do {
      let player = try AVAudioPlayer(data: clips[min(4, max(1, rows)) - 1])
      player.volume = settings.effectsVolume
      player.prepareToPlay()
      if players.count >= 8 { players.removeFirst().stop() }
      guard player.play() else { return false }
      players.append(player)
      return true
    } catch {
      logger.error("Clear sound failed: \(error.localizedDescription)")
      return false
    }
  }

  func stop() {
    players.forEach { $0.stop() }
    players.removeAll()
  }
  func reset() {
    stop()
    serials = []
    playedEventCount = 0
  }
}
