import TetrisCore

@MainActor final class ClearSoundPlayer {
  var onClearPlayed: (() -> Void)?
  private let settings: AudioSettings
  private let pool = SoundVoicePool(
    clips: (1...4).map { ClearSoundComposer.compose(rows: $0) }, maximumPlaying: 8, name: "clear")
  private var serials: [Int] = []
  private(set) var playedEventCount = 0
  var playingCount: Int { pool.playingCount }
  var retainedVoiceCount: Int { pool.retainedCount }

  init(settings: AudioSettings) { self.settings = settings }

  func process(_ boards: [Board]) {
    if !settings.effectsEnabled { stop() }
    pool.updateVolume(settings.effectsVolume)
    if serials.count != boards.count { serials = Array(repeating: 0, count: boards.count) }
    for index in boards.indices {
      // Muted events are still consumed, so re-enabling never replays old clears.
      for event in boards[index].clearEvents where event.serial > serials[index] {
        if play(rows: event.rows.count) {
          playedEventCount += 1
          onClearPlayed?()
        }
      }
      serials[index] = boards[index].clearSerial
    }
  }

  @discardableResult func play(rows: Int) -> Bool {
    guard settings.effectsEnabled else { return false }
    return pool.play(clip: min(4, max(1, rows)) - 1, volume: settings.effectsVolume)
  }

  func stop() { pool.stop() }
  func reset() {
    stop()
    serials = []
    playedEventCount = 0
  }
}
