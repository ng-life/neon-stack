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

  var operationsEnabled: Bool {
    didSet { defaults.set(operationsEnabled, forKey: "audio.operations.enabled") }
  }
  var operationsVolume: Float {
    didSet { defaults.set(operationsVolume, forKey: "audio.operations.volume") }
  }

  var warningEnabled: Bool {
    didSet { defaults.set(warningEnabled, forKey: "audio.warning.enabled") }
  }
  var warningVolume: Float {
    didSet { defaults.set(warningVolume, forKey: "audio.warning.volume") }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    warningEnabled = defaults.object(forKey: "audio.warning.enabled") as? Bool ?? true
    warningVolume = Self.volume(defaults.object(forKey: "audio.warning.volume"), fallback: 0.25)
    operationsEnabled = defaults.object(forKey: "audio.operations.enabled") as? Bool ?? true
    operationsVolume = Self.volume(
      defaults.object(forKey: "audio.operations.volume"), fallback: 0.35)
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
