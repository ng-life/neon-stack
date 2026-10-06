import AppKit
import Combine
import RealityKit
import SwiftUI
import TetrisCore

struct ArenaView: NSViewRepresentable {
  let boards: [Board]
  let reducedEffects: Bool

  func makeNSView(context: Context) -> ARView {
    let view = ARView(frame: .zero)
    view.environment.background = .color(NSColor(red: 0.025, green: 0.035, blue: 0.07, alpha: 1))
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
    lazy var effects = ClearEffects(root: root)
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
      for player in boards.indices {
        let board = boards[player]
        var values = board.grid.flatMap { $0 }
        for cell in board.ghost.cells where cell.y >= 0 && cell.y < 20 {
          if values[cell.y * 10 + cell.x] == 0 {
            values[cell.y * 10 + cell.x] = board.active.kind.rawValue + 10
          }
        }
        for cell in board.active.cells where cell.y >= 0 && cell.y < 20 {
          values[cell.y * 10 + cell.x] = board.active.kind.rawValue
        }
        for index in 0..<200 where values[index] != previous[player][index] {
          let value = values[index]
          let cube = cubes[player][index]
          cube.isEnabled = value != 0
          if value != 0 {
            let ghost = value > 10
            let color = palette[ghost ? value - 10 : value]
            cube.model?.materials = [
              SimpleMaterial(
                color: ghost ? color.withAlphaComponent(0.18) : color,
                roughness: ghost ? 1 : 0.25, isMetallic: !ghost)
            ]
            cube.scale = ghost ? [0.9, 0.9, 0.12] : [1, 1, 1]
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
