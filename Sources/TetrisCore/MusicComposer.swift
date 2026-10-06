import Foundation

/// Original looping synth compositions. The level seeds the melody, harmony and rhythm.
public enum MusicComposer {
  public static func tempo(level: Int) -> Int { min(184, 100 + max(0, level - 1) * 7) }

  public static func title(level: Int) -> String {
    let names = ["Neon Dawn", "Crystal Drive", "Pulse Runner", "Hyper Grid", "Overdrive"]
    return "LV \(level) · \(names[(max(1, level) - 1) % names.count])"
  }

  public static func compose(level: Int, sampleRate: Int = 22050) -> Data {
    let level = max(1, level)
    let beat = 60.0 / Double(tempo(level: level))
    let step = beat / 2
    let duration = beat * 32  // Eight bars, seamless at the same beat boundary.
    var samples = [Double](repeating: 0, count: Int(duration * Double(sampleRate)))
    let progression = [0, 5, 3, 6]
    let scale = [0, 2, 3, 5, 7, 8, 10]
    let tonic = 45 + (level - 1) % 12
    var random = UInt64(level) &* 7919

    func addNote(_ midi: Int, at start: Double, length: Double, gain: Double, bass: Bool) {
      let frequency = 440 * pow(2, Double(midi - 69) / 12)
      let count = Int(length * Double(sampleRate))
      let offset = Int(start * Double(sampleRate))
      for index in 0..<count {
        let time = Double(index) / Double(sampleRate)
        let phase = 2 * Double.pi * frequency * time
        let attack = min(1, time / 0.008)
        let release = min(1, (length - time) / 0.045)
        let envelope = attack * release * exp(-time * (bass ? 3 : 5))
        let wave = sin(phase) + 0.28 * sin(phase * 2) + (bass ? 0 : 0.12 * sin(phase * 3))
        // Wrap tails into the start of the loop rather than cutting them off.
        samples[(offset + index) % samples.count] += gain * envelope * wave
      }
    }

    for bar in 0..<8 {
      let root = progression[(bar / 2 + level / 3) % progression.count]
      for eighth in 0..<8 {
        let time = Double(bar * 8 + eighth) * step
        random ^= random << 13
        random ^= random >> 7
        random ^= random << 17
        let degree = (root + Int(random % 7)) % 7
        addNote(tonic + 24 + scale[degree], at: time, length: step * 0.85, gain: 0.12, bass: false)
        if eighth % 2 == 0 {
          addNote(tonic + scale[root], at: time, length: beat * 0.7, gain: 0.2, bass: true)
        }
        if eighth == 0 || eighth == 4 {
          for chord in [0, 2, 4] {
            addNote(
              tonic + 12 + scale[(root + chord) % 7], at: time, length: beat * 1.9, gain: 0.035,
              bass: false)
          }
        }
        let offset = Int(time * Double(sampleRate))
        let drumDuration = 0.18
        for index in 0..<Int(drumDuration * Double(sampleRate)) {
          let t = Double(index) / Double(sampleRate)
          random ^= random << 13
          random ^= random >> 7
          random ^= random << 17
          let noise = Double(random % 65536) / 32768 - 1
          var drum = noise * exp(-t * 70) * (level >= 4 ? 0.035 : 0.02)
          if eighth % 4 == 0 {
            drum += sin(2 * Double.pi * (48 * t + 9 * (1 - exp(-t * 30)))) * exp(-t * 24) * 0.26
          } else if eighth % 4 == 2 {
            drum += noise * exp(-t * 28) * 0.09
          }
          samples[(offset + index) % samples.count] += drum
        }
      }
    }
    let peak = max(1, samples.map { abs($0) }.max() ?? 1)
    let pcm = samples.map { Int16(($0 / peak * 0.8 * 32767).rounded()).littleEndian }
    let payload = pcm.withUnsafeBytes { Data($0) }
    var result = Data()
    func word(_ value: UInt32) {
      var v = value.littleEndian
      withUnsafeBytes(of: &v) { result.append(contentsOf: $0) }
    }
    func short(_ value: UInt16) {
      var v = value.littleEndian
      withUnsafeBytes(of: &v) { result.append(contentsOf: $0) }
    }
    result.append(contentsOf: "RIFF".utf8)
    word(UInt32(payload.count + 36))
    result.append(contentsOf: "WAVEfmt ".utf8)
    word(16)
    short(1)
    short(1)
    word(UInt32(sampleRate))
    word(UInt32(sampleRate * 2))
    short(2)
    short(16)
    result.append(contentsOf: "data".utf8)
    word(UInt32(payload.count))
    result.append(payload)
    return result
  }
}
