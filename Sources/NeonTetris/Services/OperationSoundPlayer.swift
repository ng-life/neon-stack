import TetrisCore

@MainActor final class OperationSoundPlayer {
  private let settings: AudioSettings
  private let pool = SoundVoicePool(
    clips: OperationSound.allCases.map { OperationSoundComposer.compose($0) }, maximumPlaying: 4,
    name: "operation")
  private var serials: [Int] = []
  private var lastRotationTimes: [Double] = []
  private(set) var playedCount = 0
  var playingCount: Int { pool.playingCount }
  var retainedVoiceCount: Int { pool.retainedCount }

  init(settings: AudioSettings) { self.settings = settings }
  func process(_ boards: [Board], now: Double) {
    if !settings.operationsEnabled { stop() }
    pool.updateVolume(settings.operationsVolume)
    if serials.count != boards.count {
      serials = Array(repeating: 0, count: boards.count)
      lastRotationTimes = Array(repeating: -.infinity, count: boards.count)
    }
    for index in boards.indices {
      for event in boards[index].operationFeedback where event.serial > serials[index] {
        // Throttle rotation bursts independently so both players retain feedback.
        if event.sound == .rotate && now - lastRotationTimes[index] < 0.06 { continue }
        if play(event.sound) {
          playedCount += 1
          if event.sound == .rotate { lastRotationTimes[index] = now }
        }
      }
      serials[index] = boards[index].operationSerial
    }
  }
  @discardableResult func play(_ sound: OperationSound) -> Bool {
    guard settings.operationsEnabled else { return false }
    return pool.play(
      clip: OperationSound.allCases.firstIndex(of: sound)!,
      volume: settings.operationsVolume)
  }
  func stop() { pool.stop() }
  func reset() {
    stop()
    serials = []
    lastRotationTimes = []
    playedCount = 0
  }
}
