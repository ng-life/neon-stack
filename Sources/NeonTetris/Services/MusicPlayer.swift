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
          self.logger.info("BGM loaded: level \(level), \(MusicComposer.tempo(level: level)) BPM")
        } catch {
          self.trackTitle = "音乐暂时不可用"
          self.logger.error("BGM load failed: \(error.localizedDescription)")
        }
      }
    }
    guard isRunning else {
      current?.pause()
      outgoing?.pause()
      return
    }
    if let current, !current.isPlaying { current.play() }
    if let outgoing, !outgoing.isPlaying { outgoing.play() }
    fadeElapsed = min(1, fadeElapsed + delta)
    current?.volume = volume * Float(fadeElapsed)
    outgoing?.volume = volume * Float(1 - fadeElapsed)
    if fadeElapsed >= 1 {
      outgoing?.stop()
      outgoing = nil
    }
  }

  func stop() {
    generation?.cancel()
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
