import XCTest

@testable import NeonTetris

@MainActor final class InputTests: XCTestCase {
  func testPersistenceConflictDetectionAndReset() {
    let domain = "NeonInputTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let input = InputSettings(defaults: defaults)
    XCTAssertTrue(input.configuration.isValid)
    XCTAssertFalse(input.setKey(player: 0, command: .left, code: 123))
    XCTAssertEqual(input.key(player: 0, command: .left), 0)
    XCTAssertTrue(input.setKey(player: 0, command: .left, code: 3))
    input.delay = 0.25
    input.interval = 0.03
    input.deadZone = 0.2
    XCTAssertTrue(input.setMapping(player: 1, control: .a, command: .hold))
    XCTAssertFalse(input.setMapping(player: 1, control: .menu, command: .unassigned))
    let restored = InputSettings(defaults: defaults)
    XCTAssertEqual(restored.configuration, input.configuration)
    XCTAssertEqual(restored.commands(player: 1, controls: [.a, .b]), [.hold])
    XCTAssertEqual(restored.commands(player: 0, controls: [.x]), [.clockwise])
    XCTAssertTrue(restored.keyboardSummary(player: 0).contains("F 左移"))
    restored.reset()
    XCTAssertEqual(InputSettings(defaults: defaults).configuration, InputConfiguration())
  }

  func testOldDefaultGamepadMappingMigratesButCustomMappingSurvives() throws {
    for version in 0...1 {
      let domain = "NeonInputTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: domain)!
      defer { defaults.removePersistentDomain(forName: domain) }
      var old = InputConfiguration()
      for player in 0..<2 {
        old.gamepad[player]["a"] = .clockwise
        old.gamepad[player]["b"] = .counterclockwise
        old.gamepad[player]["x"] = version == 0 ? .hold : .drop
        old.gamepad[player]["y"] = version == 0 ? .drop : .hold
      }
      old.gamepad[1]["a"] = .hold
      defaults.set(version, forKey: "input.gamepadDefaultsVersion")
      defaults.set(try JSONEncoder().encode(old), forKey: "input.configuration")
      let input = InputSettings(defaults: defaults)
      XCTAssertEqual(input.mapping(player: 0, control: .x), .clockwise)
      XCTAssertEqual(input.mapping(player: 0, control: .y), .counterclockwise)
      XCTAssertEqual(input.mapping(player: 0, control: .a), .drop)
      XCTAssertEqual(input.mapping(player: 0, control: .b), .hold)
      XCTAssertEqual(input.configuration.gamepad[1], old.gamepad[1])
      XCTAssertEqual(InputSettings(defaults: defaults).configuration, input.configuration)
      // After migration, explicitly choosing an older layout remains a user preference.
      for control in [PadControl.a, .b, .x, .y] {
        XCTAssertTrue(
          input.setMapping(
            player: 0, control: control,
            command: old.gamepad[0][control.rawValue]!))
      }
      XCTAssertEqual(InputSettings(defaults: defaults).configuration.gamepad[0], old.gamepad[0])
    }
  }

  func testInvalidSavedConfigurationFallsBackAndRangesClamp() throws {
    let domain = "NeonInputTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    var invalid = InputConfiguration()
    invalid.keyboard = []
    defaults.set(try JSONEncoder().encode(invalid), forKey: "input.configuration")
    let input = InputSettings(defaults: defaults)
    XCTAssertEqual(input.configuration, InputConfiguration())
    input.delay = 10
    input.interval = 0
    input.deadZone = 0
    XCTAssertEqual(input.delay, 0.5)
    XCTAssertEqual(input.interval, 0.016)
    XCTAssertEqual(input.deadZone, 0.1)
  }

  func testRepeatUsesConfiguredDelayAndIntervalWithoutDoubleTap() {
    var config = InputConfiguration()
    config.delay = 0.25
    config.interval = 0.03
    var clock = InputRepeater()
    clock.immediate(.left, now: 0, configuration: config)
    XCTAssertEqual(clock.poll([.left], now: 0.01, configuration: config), [])
    XCTAssertEqual(clock.poll([.left], now: 0.24, configuration: config), [])
    XCTAssertEqual(clock.poll([.left], now: 0.25, configuration: config), [.left])
    XCTAssertEqual(clock.poll([.left], now: 0.27, configuration: config), [])
    XCTAssertEqual(clock.poll([.left], now: 0.28, configuration: config), [.left])
    XCTAssertEqual(clock.poll([], now: 0.29, configuration: config), [])
    XCTAssertEqual(clock.poll([.left], now: 0.30, configuration: config), [.left])
  }

  func testControllerEdgesSoftDropAndIndependentPlayerClocks() {
    let config = InputConfiguration()
    var first = InputRepeater()
    var second = InputRepeater()
    XCTAssertEqual(
      first.poll([.drop, .clockwise], now: 0, configuration: config), [.clockwise, .drop])
    XCTAssertEqual(first.poll([.drop, .clockwise], now: 5, configuration: config), [])
    XCTAssertEqual(second.poll([.right], now: 5, configuration: config), [.right])
    XCTAssertEqual(first.poll([.down], now: 6, configuration: config), [.down])
    XCTAssertEqual(first.poll([.down], now: 6.04, configuration: config), [])
    XCTAssertEqual(first.poll([.down], now: 6.05, configuration: config), [.down])
    XCTAssertEqual(second.poll([.right], now: 5.18, configuration: config), [.right])
  }

  func testHeldMenuCannotImmediatelyPauseAfterStart() {
    var clock = InputRepeater()
    let config = InputConfiguration()
    XCTAssertEqual(clock.poll([.pause], now: 0, configuration: config), [.pause])
    clock.clearRepeats()
    XCTAssertEqual(clock.poll([.pause], now: 1, configuration: config), [])
    _ = clock.poll([], now: 2, configuration: config)
    XCTAssertEqual(clock.poll([.pause], now: 3, configuration: config), [.pause])
    clock.releaseAll()
    XCTAssertEqual(clock.poll([.left], now: 4, configuration: config), [.left])
  }

  func testStickDeadZoneAndDigitalDpadOverride() {
    XCTAssertEqual(
      ControllerReading.directions(
        dpadX: 0, dpadY: 0,
        stickX: 0.2, stickY: -0.3, deadZone: 0.5), [])
    XCTAssertEqual(
      ControllerReading.directions(
        dpadX: 0, dpadY: 0,
        stickX: 0.2, stickY: -0.3, deadZone: 0.1), [.right, .down])
    XCTAssertEqual(
      ControllerReading.directions(
        dpadX: -1, dpadY: 0,
        stickX: 1, stickY: 0.5, deadZone: 0.9), [.left])
    XCTAssertEqual(
      ControllerReading.directions(
        dpadX: 0, dpadY: 1,
        stickX: 0.5, stickY: -1, deadZone: 0.5), [.up])
  }
}
