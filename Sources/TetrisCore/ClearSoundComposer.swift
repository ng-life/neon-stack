import Foundation

public enum ClearSoundComposer {
  /// Short ascending synth chimes, with a longer celebratory chord for a four-line clear.
  public static func compose(rows: Int, sampleRate: Int = 22050) -> Data {
    let rows = min(4, max(1, rows))
    let notes = [72, 76, 79, 84, 88, 91]
    let duration = rows == 4 ? 0.8 : 0.28 + Double(rows) * 0.09
    var samples = [Double](repeating: 0, count: Int(duration * Double(sampleRate)))
    for note in 0..<(rows + 2) {
      let frequency = 440 * pow(2, Double(notes[note] - 69) / 12)
      let start = Double(note) * 0.045
      let length = duration - start
      for index in 0..<Int(length * Double(sampleRate)) {
        let time = Double(index) / Double(sampleRate)
        let envelope = min(1, time / 0.004) * min(1, (length - time) / 0.025) * exp(-time * 9)
        let phase = 2 * Double.pi * frequency * time
        samples[Int(start * Double(sampleRate)) + index] +=
          (sin(phase) + 0.18 * sin(phase * 2)) * envelope * 0.19
      }
    }
    let peak = max(1, samples.map { abs($0) }.max() ?? 1)
    let pcm = samples.map { Int16(($0 / peak * 0.85 * 32767).rounded()).littleEndian }
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
