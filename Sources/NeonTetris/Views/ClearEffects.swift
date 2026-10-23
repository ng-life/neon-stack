import AppKit
import RealityKit
import TetrisCore

/// Short-lived visual entities; no collision or game-state responsibilities.
@MainActor final class ClearEffects {
  private struct Particle {
    let entity: ModelEntity
    let origin: SIMD3<Float>
    let velocity: SIMD3<Float>
    let color: NSColor
    let lifetime: Double
    let initialScale: SIMD3<Float>
    let spin: Float
    var age = 0.0
  }
  private let root: Entity
  private var particles: [Particle] = []
  private let shard = MeshResource.generateBox(size: 0.13, cornerRadius: 0.025)

  init(root: Entity) { self.root = root }

  func emit(_ event: ClearEvent, center: Float, palette: [NSColor], reduced: Bool) {
    guard !event.rows.isEmpty else { return }
    let tier = event.effectTier
    let intensity = Float(event.rows.count)
    let accent: NSColor =
      tier == .perfectClear
      ? .white : (tier == .combo ? .systemPink : (tier == .tetris ? .systemYellow : .systemCyan))
    let fragments = tier == .normal ? 1 : (tier == .perfectClear ? 3 : 2)
    for (rowIndex, row) in event.rows.enumerated() {
      let y = 9.5 - Float(row)
      let beam = ModelEntity(
        mesh: .generateBox(width: 10, height: reduced || tier == .normal ? 0.06 : 0.12, depth: 0.04)
      )
      add(
        beam, at: [center, y, 0.6], velocity: .zero, color: accent,
        lifetime: reduced ? 0.22 : 0.45, scale: [1, 1, 1], spin: 0)
      guard !reduced else { continue }
      for x in 0..<10 {
        let color = palette[event.colors[rowIndex][x]]
        for fragment in 0..<fragments {
          let direction: Float = x < 5 ? -1 : 1
          let velocity = SIMD3<Float>(
            direction * (0.8 + Float(fragment) * 0.8),
            Float((x * 7 + fragment * 3) % 9) * 0.35 + 0.3,
            Float(fragment) * 0.35)
          add(
            ModelEntity(mesh: shard), at: [center + Float(x) - 4.5, y, 0.7],
            velocity: velocity, color: color, lifetime: 0.55 + Double(fragment) * 0.12,
            scale: [1, 1.5, 1], spin: Float(x + 1) * direction)
        }
      }
    }
    guard !reduced else { return }
    // A segmented energy ring expands from the cleared rows; four-line clears glow gold.
    let y = 9.5 - Float(event.rows.reduce(0, +)) / Float(event.rows.count)
    let ringCount = tier == .perfectClear ? 48 : (tier == .normal ? 0 : 24)
    for index in 0..<ringCount {
      let angle = Float(index) * .pi * 2 / Float(ringCount)
      let radial = SIMD3<Float>(cos(angle), sin(angle), 0)
      add(
        ModelEntity(mesh: shard), at: SIMD3<Float>(center, y, 0.9) + radial * 0.4,
        velocity: radial * (3 + intensity), color: accent, lifetime: 0.65,
        scale: [1.6, 0.5, 0.5], spin: 0)
    }
    let message = event.effectTitle
    let text = ModelEntity(
      mesh: .generateText(
        message, extrusionDepth: 0.025,
        font: .systemFont(ofSize: 1.1, weight: .heavy),
        containerFrame: .zero,
        alignment: .center, lineBreakMode: .byWordWrapping))
    let width = text.visualBounds(relativeTo: nil).extents.x
    let textScale = min(1, 9 / max(0.01, width))
    add(
      text, at: [center - width * textScale / 2, 10.7, 1.4], velocity: [0, 0.3, 0],
      color: accent, lifetime: 0.85, scale: [textScale, textScale, textScale], spin: 0)
    // Reward text stays above the board, leaving the next landing area readable.
    // Bound entity count even when both players clear several times in one render frame.
    if particles.count > 600 {
      for particle in particles.prefix(particles.count - 600) { particle.entity.removeFromParent() }
      particles.removeFirst(particles.count - 600)
    }
  }

  private func add(
    _ entity: ModelEntity, at position: SIMD3<Float>, velocity: SIMD3<Float>,
    color: NSColor, lifetime: Double, scale: SIMD3<Float>, spin: Float
  ) {
    entity.position = position
    entity.scale = scale
    entity.model?.materials = [UnlitMaterial(color: color)]
    root.addChild(entity)
    particles.append(
      Particle(
        entity: entity, origin: position, velocity: velocity, color: color,
        lifetime: lifetime, initialScale: scale, spin: spin))
  }

  func removeAll() {
    for particle in particles { particle.entity.removeFromParent() }
    particles.removeAll()
  }

  func advance(_ delta: Double) {
    for index in particles.indices {
      particles[index].age += delta
      let particle = particles[index]
      let t = Float(particle.age)
      let progress = Float(min(1, particle.age / particle.lifetime))
      particle.entity.position = particle.origin + particle.velocity * t
      particle.entity.scale = particle.initialScale * (1 - progress * 0.7)
      particle.entity.orientation = simd_quatf(angle: particle.spin * t, axis: [0, 0, 1])
      particle.entity.model?.materials = [
        UnlitMaterial(color: particle.color.withAlphaComponent(CGFloat(1 - progress)))
      ]
      if particle.age >= particle.lifetime { particle.entity.removeFromParent() }
    }
    particles.removeAll { $0.age >= $0.lifetime }
  }
}
