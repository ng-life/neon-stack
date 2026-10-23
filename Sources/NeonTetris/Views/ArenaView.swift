import AppKit
import Combine
import RealityKit
import SwiftUI
import TetrisCore

struct ArenaView: NSViewRepresentable {
  let boards: [Board]
  let reducedEffects: Bool

  func makeNSView(context: Context) -> ARView {
    let view = TransparentARView(frame: .zero)
    view.environment.background = .color(.clear)
    view.layer?.isOpaque = false
    context.coordinator.setup(view, playerCount: boards.count)
    context.coordinator.update(boards, reducedEffects: reducedEffects)
    return view
  }
  func updateNSView(_ nsView: ARView, context: Context) {
    context.coordinator.update(boards, reducedEffects: reducedEffects)
  }
  func makeCoordinator() -> Renderer { Renderer() }

  @MainActor final class Renderer {
    let root = AnchorEntity(world: .zero)
    var cubes: [[ModelEntity]] = []
    var previous: [[Int]] = []
    var serials = [0, 0]
    var ghostOutlines: [[Entity]] = []
    var dangerEdges: [[ModelEntity]] = []
    var dangerLevels: [DangerLevel] = []
    lazy var effects = ClearEffects(root: root)
    private var wasReduced = false
    var subscription: (any Cancellable)?
    let palette: [NSColor] = [
      .clear, .systemCyan, .systemYellow, .systemPurple,
      .systemGreen, .systemRed, .systemBlue, .systemOrange,
      NSColor(white: 0.4, alpha: 1),
    ]
    let mesh = MeshResource.generateBox(size: 0.91, cornerRadius: 0.08)

    func setup(_ view: ARView, playerCount: Int) {
      view.scene.addAnchor(root)
      subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
        let delta = event.deltaTime
        MainActor.assumeIsolated { self?.effects.advance(delta) }
      }
      let camera = PerspectiveCamera()
      camera.camera.fieldOfViewInDegrees = 42
      camera.position = [0, 0, 36]
      root.addChild(camera)
      let light = DirectionalLight()
      light.light.intensity = 2500
      light.look(at: [0, 0, 0], from: [5, 12, 15], relativeTo: nil)
      root.addChild(light)
      for player in 0..<playerCount {
        let center: Float = playerCount == 1 ? 0 : (player == 0 ? -6.5 : 6.5)
        let plate = ModelEntity(
          mesh: .generateBox(width: 10.5, height: 20.5, depth: 0.3, cornerRadius: 0.2),
          materials: [
            SimpleMaterial(
              color: NSColor(red: 0.06, green: 0.08, blue: 0.13, alpha: 1), roughness: 0.7,
              isMetallic: false)
          ])
        var edges: [ModelEntity] = []
        for x in [-5.15, 5.15] {
          let edge = ModelEntity(
            mesh: .generateBox(width: 0.09, height: 20.4, depth: 0.08),
            materials: [UnlitMaterial(color: .clear)])
          edge.position = [center + Float(x), 0, 0.2]
          root.addChild(edge)
          edges.append(edge)
        }
        dangerEdges.append(edges)
        dangerLevels.append(.safe)
        var outlines: [Entity] = []
        for _ in 0..<4 {
          let outline = Entity()
          for horizontal in [true, false] {
            for sign: Float in [-1, 1] {
              let line = ModelEntity(
                mesh: .generateBox(
                  width: horizontal ? 0.84 : 0.04, height: horizontal ? 0.04 : 0.84, depth: 0.03),
                materials: [UnlitMaterial(color: NSColor.white.withAlphaComponent(0.6))])
              line.position = horizontal ? [0, sign * 0.4, 0] : [sign * 0.4, 0, 0]
              outline.addChild(line)
            }
          }
          outline.isEnabled = false
          root.addChild(outline)
          outlines.append(outline)
        }
        ghostOutlines.append(outlines)
        plate.position = [center, 0, -0.6]
        root.addChild(plate)
        var cells: [ModelEntity] = []
        for y in 0..<20 {
          for x in 0..<10 {
            let cube = ModelEntity(mesh: mesh)
            cube.position = [center + Float(x) - 4.5, 9.5 - Float(y), 0]
            root.addChild(cube)
            cells.append(cube)
            let tile = ModelEntity(
              mesh: .generateBox(width: 0.94, height: 0.94, depth: 0.02),
              materials: [UnlitMaterial(color: NSColor(white: 0.12, alpha: 1))])
            tile.position = [cube.position.x, cube.position.y, -0.42]
            root.addChild(tile)
          }
        }
        cubes.append(cells)
        previous.append(Array(repeating: -1, count: 200))
      }
    }

    func update(_ boards: [Board], reducedEffects: Bool) {
      guard cubes.count == boards.count else { return }
      if reducedEffects && !wasReduced { effects.removeAll() }
      wasReduced = reducedEffects
      for player in boards.indices {
        let board = boards[player]
        var values = board.grid.flatMap { $0 }
        let center: Float = boards.count == 1 ? 0 : (player == 0 ? -6.5 : 6.5)
        let activeCells = board.active.cells
        for (index, cell) in board.ghost.cells.enumerated() {
          let outline = ghostOutlines[player][index]
          outline.isEnabled =
            !board.lost && cell.y >= 0 && cell.y < 20
            && !activeCells.contains(where: { $0.x == cell.x && $0.y == cell.y })
          outline.position = [center + Float(cell.x) - 4.5, 9.5 - Float(cell.y), 0.05]
        }
        for cell in activeCells where cell.y >= 0 && cell.y < 20 {
          values[cell.y * 10 + cell.x] = board.active.kind.rawValue + 20
        }
        if dangerLevels[player] != board.dangerLevel {
          dangerLevels[player] = board.dangerLevel
          let color: NSColor = board.dangerLevel == .critical ? .systemRed : .systemOrange
          for edge in dangerEdges[player] {
            edge.isEnabled = board.dangerLevel != .safe
            edge.model?.materials = [UnlitMaterial(color: color)]
          }
        }
        for index in 0..<200 where values[index] != previous[player][index] {
          let value = values[index]
          let cube = cubes[player][index]
          cube.isEnabled = value != 0
          if value != 0 {
            let active = value > 20
            let color = palette[active ? value - 20 : value]
            if active {
              cube.model?.materials = [UnlitMaterial(color: color)]
            } else {
              cube.model?.materials = [
                SimpleMaterial(
                  color: color.withAlphaComponent(0.9), roughness: 0.65, isMetallic: false)
              ]
            }
            cube.scale = active ? [1.02, 1.02, 1] : [0.97, 0.97, 0.8]

          }
        }
        for event in board.clearEvents where event.serial > serials[player] {
          let center: Float = boards.count == 1 ? 0 : (player == 0 ? -6.5 : 6.5)
          effects.emit(event, center: center, palette: palette, reduced: reducedEffects)
        }
        serials[player] = board.clearSerial
        previous[player] = values
      }
    }
  }
}

/// Let the SwiftUI background remain visible outside the opaque board plates.
private final class TransparentARView: ARView {
  override var isOpaque: Bool { false }
}
