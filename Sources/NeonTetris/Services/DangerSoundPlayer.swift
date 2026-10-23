import Foundation
import TetrisCore

@MainActor final class DangerSoundPlayer {
  private let settings: AudioSettings
  private let pool = SoundVoicePool(
    clips: [DangerSoundPlayer.clip()], maximumPlaying: 2, name: "danger")
  private var levels: [DangerLevel] = []
  private var lastPlayed: [Double] = []
  private(set) var playedCount = 0
  init(settings: AudioSettings) { self.settings = settings }
  func process(_ boards: [Board], active: Bool, now: Double) {
    if levels.count != boards.count {
      levels = Array(repeating: .safe, count: boards.count)
      lastPlayed = Array(repeating: -.infinity, count: boards.count)
    }
    if !active || !settings.warningEnabled { stop() }
    for player in boards.indices {
      let level = boards[player].dangerLevel
      if active && settings.warningEnabled && level != .safe && level != levels[player]
        && now - lastPlayed[player] >= 5
      {
        if pool.play(clip: 0, volume: settings.warningVolume) {
          playedCount += 1
          lastPlayed[player] = now
        }
      }
      levels[player] = level
    }
  }
  func stop() { pool.stop() }
  func reset() {
    stop()
    levels = []
    lastPlayed = []
    playedCount = 0
  }

  private static func clip() -> Data {
    let rate = 22050
    let samples: [Int16] = (0..<Int(Double(rate) * 0.24)).map { index in
      let t = Double(index) / Double(rate)
      let local = t.truncatingRemainder(dividingBy: 0.12)
      let envelope = min(1, local / 0.008) * max(0, 1 - local / 0.09)
      return Int16(sin(2 * .pi * (t < 0.12 ? 330 : 440) * t) * envelope * 0.2 * 32767).littleEndian
    }
    let payload = samples.withUnsafeBytes { Data($0) }
    var data = Data()
    func word(_ value: UInt32) {
      var n = value.littleEndian
      withUnsafeBytes(of: &n) { data.append(contentsOf: $0) }
    }
    func short(_ value: UInt16) {
      var n = value.littleEndian
      withUnsafeBytes(of: &n) { data.append(contentsOf: $0) }
    }
    data.append(contentsOf: "RIFF".utf8)
    word(UInt32(payload.count + 36))
    data.append(contentsOf: "WAVEfmt ".utf8)
    word(16)
    short(1)
    short(1)
    word(UInt32(rate))
    word(UInt32(rate * 2))
    short(2)
    short(16)
    data.append(contentsOf: "data".utf8)
    word(UInt32(payload.count))
    data.append(payload)
    return data
  }
}
