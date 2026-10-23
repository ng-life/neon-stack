import Foundation

public enum OperationSoundComposer {
  /// Quiet, short percussive tones, synthesized without external audio assets.
  public static func compose(_ sound: OperationSound, sampleRate: Int = 22050) -> Data {
    let duration: Double = sound == .rotate ? 0.065 : (sound == .lock ? 0.09 : 0.14)
    let frequency: Double = sound == .rotate ? 680 : (sound == .lock ? 220 : 130)
    let count = Int(duration * Double(sampleRate))
    let samples = (0..<count).map { index -> Int16 in
      let t = Double(index) / Double(sampleRate)
      let envelope = min(1, t / 0.003) * pow(max(0, 1 - t / duration), 3)
      let phase = 2 * Double.pi * frequency * (t - t * t / (duration * 3))
      return Int16((sin(phase) * envelope * 0.32 * 32767).rounded()).littleEndian
    }
    let payload = samples.withUnsafeBytes { Data($0) }
    var data = Data()
    func word(_ value: UInt32) {
      var value = value.littleEndian
      withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    func short(_ value: UInt16) {
      var value = value.littleEndian
      withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    data.append(contentsOf: "RIFF".utf8)
    word(UInt32(payload.count + 36))
    data.append(contentsOf: "WAVEfmt ".utf8)
    word(16)
    short(1)
    short(1)
    word(UInt32(sampleRate))
    word(UInt32(sampleRate * 2))
    short(2)
    short(16)
    data.append(contentsOf: "data".utf8)
    word(UInt32(payload.count))
    data.append(payload)
    return data
  }
}
