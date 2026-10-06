// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NeonTetris",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "NeonTetris", targets: ["NeonTetris"])],
  targets: [
    .target(name: "TetrisCore"),
    .executableTarget(name: "NeonTetris", dependencies: ["TetrisCore"]),
    .testTarget(name: "TetrisCoreTests", dependencies: ["TetrisCore"]),
    .testTarget(name: "NeonTetrisTests", dependencies: ["NeonTetris", "TetrisCore"]),
  ]
)
