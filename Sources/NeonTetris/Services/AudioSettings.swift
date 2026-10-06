import Foundation
import Observation

/// Shared by the game and the Settings scene; writes each change immediately.
@MainActor @Observable
final class AudioSettings {
  private let defaults: UserDefaults
  var musicEnabled: Bool { didSet { defaults.set(musicEnabled, forKey: "audio.music.enabled") } }
  var musicVolume: Float { didSet { defaults.set(musicVolume, forKey: "audio.music.volume") } }
  var effectsEnabled: Bool {
    didSet { defaults.set(effectsEnabled, forKey: "audio.clear.enabled") }
  }
  var effectsVolume: Float { didSet { defaults.set(effectsVolume, forKey: "audio.clear.volume") } }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    musicEnabled = defaults.object(forKey: "audio.music.enabled") as? Bool ?? true
    effectsEnabled = defaults.object(forKey: "audio.clear.enabled") as? Bool ?? true
    musicVolume = Self.volume(defaults.object(forKey: "audio.music.volume"), fallback: 0.3)
    effectsVolume = Self.volume(defaults.object(forKey: "audio.clear.volume"), fallback: 0.65)
  }

  private static func volume(_ stored: Any?, fallback: Float) -> Float {
    guard let value = stored as? NSNumber, value.floatValue.isFinite else { return fallback }
    return min(1, max(0, value.floatValue))
  }
}
