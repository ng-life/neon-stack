import AVFoundation
import OSLog
import Observation
import TetrisCore

@MainActor @Observable
final class MusicPlayer {
  private let settings: AudioSettings
  var enabled: Bool {
    get { settings.musicEnabled }
    set { settings.musicEnabled = newValue }
  }
  var volume: Float {
    get { settings.musicVolume }
    set { settings.musicVolume = newValue }
  }

  init(settings: AudioSettings = AudioSettings()) { self.settings = settings }
  private(set) var trackTitle = "开始游戏后播放"
  private(set) var activeLevel = 0
  var isPlaying: Bool { current?.isPlaying ?? false }
  private var current: AVAudioPlayer?
  private var outgoing: AVAudioPlayer?
  private var requestedLevel = 0
  private var isRunning = false
  private var generation: Task<Void, Never>?
  private var fadeElapsed = 1.0
  private var duckRemaining = 0.0
  private(set) var duckGain: Float = 1
  var effectiveVolume: Float { current?.volume ?? 0 }

  func duckForClear() {
    duckRemaining = 0.35
    DiagnosticLog.shared.record("music_duck")
  }
  private let logger = Logger(subsystem: "com.nglife.neon-tetris", category: "music")

  func update(level: Int, running: Bool, delta: Double) {
    isRunning = running && enabled
    if level != requestedLevel && running {
      requestedLevel = level
      generation?.cancel()
      generation = Task { [weak self] in
        let data = await Task.detached(priority: .utility) { MusicComposer.compose(level: level) }
          .value
        guard !Task.isCancelled, let self, self.requestedLevel == level else { return }
        do {
          let player = try AVAudioPlayer(data: data)
          player.numberOfLoops = -1
          player.prepareToPlay()
          player.volume = 0
          self.outgoing?.stop()
          self.outgoing = self.current
          self.current = player
          self.activeLevel = level
          self.fadeElapsed = 0
          self.trackTitle = MusicComposer.title(level: level)
          if self.isRunning { player.play() }
          DiagnosticLog.shared.record("music_loaded", fields: ["level": String(level)])
          self.logger.info("BGM loaded: level \(level), \(MusicComposer.tempo(level: level)) BPM")
        } catch {
          self.trackTitle = "音乐暂时不可用"
          DiagnosticLog.shared.record(
            "music_load_failed", fields: ["error": error.localizedDescription], error: true)
          self.logger.error("BGM load failed: \(error.localizedDescription)")
        }
      }
    }
    guard isRunning else {
      duckRemaining = 0
      duckGain = 1
      current?.pause()
      outgoing?.pause()
      return
    }
    if let current, !current.isPlaying { current.play() }
    if let outgoing, !outgoing.isPlaying { outgoing.play() }
    // Fast attack, a short hold, then a smooth release; repeated clears extend the hold.
    duckRemaining = max(0, duckRemaining - delta)
    let target: Float = duckRemaining > 0 ? 0.3 : 1
    let blend = Float(min(1, max(0, delta) / (target < duckGain ? 0.035 : 0.3)))
    duckGain += (target - duckGain) * blend
    fadeElapsed = min(1, fadeElapsed + delta)
    current?.volume = volume * Float(fadeElapsed) * duckGain
    outgoing?.volume = volume * Float(1 - fadeElapsed) * duckGain
    if fadeElapsed >= 1 {
      outgoing?.stop()
      outgoing = nil
    }
  }

  func stop() {
    generation?.cancel()
    duckRemaining = 0
    duckGain = 1
    requestedLevel = 0
    activeLevel = 0
    current?.stop()
    outgoing?.stop()
    current = nil
    outgoing = nil
    isRunning = false
    trackTitle = "开始游戏后播放"
  }
}
