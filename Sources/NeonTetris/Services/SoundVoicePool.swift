import AVFoundation
import OSLog

/// Retains every allocated player until the audio service itself is released.
/// `isPlaying == false` can precede the queued `finishedPlaying:` main-thread callback,
/// so completion, voice stealing and stop must never remove the owning player.
@MainActor final class SoundVoicePool {
  private struct Voice {
    let clip: Int
    let player: AVAudioPlayer
    var sequence: Int
  }
  private let name: String
  private let clips: [Data]
  private let voicesPerClip: Int
  private let maximumPlaying: Int
  private var voices: [Voice] = []
  private var sequence = 0
  private let logger = Logger(subsystem: "com.nglife.neon-tetris", category: "sound-voices")

  var playingCount: Int { voices.filter { $0.player.isPlaying }.count }
  var retainedCount: Int { voices.count }

  init(clips: [Data], voicesPerClip: Int = 2, maximumPlaying: Int, name: String = "sound") {
    self.name = name
    self.clips = clips
    self.voicesPerClip = voicesPerClip
    self.maximumPlaying = maximumPlaying
  }

  @discardableResult func play(clip: Int, volume: Float) -> Bool {
    guard clips.indices.contains(clip), volume > 0 else { return false }
    DiagnosticLog.shared.record(
      "audio_play_begin",
      fields: [
        "pool": name, "clip": String(clip), "retained": String(retainedCount),
        "playing": String(playingCount),
      ])
    do {
      let matching = voices.indices.filter { voices[$0].clip == clip }
      let index: Int
      if let idle = matching.first(where: { !voices[$0].player.isPlaying }) {
        index = idle
      } else if matching.count < voicesPerClip {
        let player = try AVAudioPlayer(data: clips[clip])
        player.prepareToPlay()
        // Retain before starting playback, including when play() reports failure.
        voices.append(Voice(clip: clip, player: player, sequence: 0))
        index = voices.count - 1
      } else {
        index = matching.min { voices[$0].sequence < voices[$1].sequence }!
      }
      let player = voices[index].player
      if player.isPlaying { player.stop() }
      if playingCount >= maximumPlaying,
        let oldest = voices.indices.filter({ voices[$0].player.isPlaying })
          .min(by: { voices[$0].sequence < voices[$1].sequence })
      {
        voices[oldest].player.stop()
      }
      sequence += 1
      voices[index].sequence = sequence
      player.volume = volume
      player.currentTime = 0
      let played = player.play()
      DiagnosticLog.shared.record(
        "audio_play_completed",
        fields: [
          "pool": name, "clip": String(clip), "played": String(played),
          "retained": String(retainedCount),
        ], error: !played)
      return played
    } catch {
      DiagnosticLog.shared.record(
        "audio_play_failed", fields: ["pool": name, "error": error.localizedDescription],
        error: true)
      logger.error("Sound playback failed: \(error.localizedDescription)")
      return false
    }
  }

  func updateVolume(_ volume: Float) {
    for voice in voices { voice.player.volume = volume }
  }

  func stop() {
    for voice in voices { voice.player.stop() }
    // Keep idle and stopped voices alive: delayed completion callbacks may still be queued.
  }
}
