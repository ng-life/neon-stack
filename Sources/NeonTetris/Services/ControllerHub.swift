import GameController
import Observation

struct ControllerReading: Equatable {
  var name = "未连接"
  var connected = false
  var x: Float = 0
  var y: Float = 0
  var controls: Set<PadControl> = []

  static func directions(
    dpadX: Float, dpadY: Float, stickX: Float, stickY: Float,
    deadZone: Float
  ) -> Set<PadControl> {
    // D-pad remains digital; the dead zone applies only to the stick.
    let x = abs(dpadX) > 0.2 ? dpadX : (abs(stickX) > deadZone ? stickX : 0)
    let y = abs(dpadY) > 0.2 ? dpadY : (abs(stickY) > deadZone ? stickY : 0)
    var result: Set<PadControl> = []
    if x < 0 { result.insert(.left) }
    if x > 0 { result.insert(.right) }
    if y < 0 { result.insert(.down) }
    if y > 0 { result.insert(.up) }
    return result
  }
}

/// Keeps connected devices in their player slots, even when the other device disconnects.
@MainActor @Observable final class ControllerHub {
  private var devices: [GCController?] = [nil, nil]
  private(set) var readings = [ControllerReading(), ControllerReading()]
  private(set) var availableCount = 0

  /// Returns slots that lost a device; diagnostics and gameplay use the same readings.
  func refresh(deadZone: Float) -> Set<Int> {
    let available = GCController.controllers().filter {
      $0.extendedGamepad != nil && !$0.isSnapshot
    }
    if availableCount != available.count { availableCount = available.count }
    var disconnected: Set<Int> = []
    for index in devices.indices {
      if let old = devices[index], !available.contains(where: { $0 === old }) {
        devices[index] = nil
        disconnected.insert(index)
      }
    }
    for device in available where !devices.contains(where: { $0 === device }) {
      if let index = devices.firstIndex(where: { $0 == nil }) {
        devices[index] = device
        device.playerIndex = index == 0 ? .index1 : .index2
      }
    }
    for index in devices.indices {
      guard let device = devices[index], let pad = device.extendedGamepad else {
        if readings[index].connected { readings[index] = ControllerReading() }
        continue
      }
      var controls = ControllerReading.directions(
        dpadX: pad.dpad.xAxis.value,
        dpadY: pad.dpad.yAxis.value, stickX: pad.leftThumbstick.xAxis.value,
        stickY: pad.leftThumbstick.yAxis.value, deadZone: deadZone)
      let buttons: [(PadControl, GCControllerButtonInput)] = [
        (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
        (.lb, pad.leftShoulder), (.rb, pad.rightShoulder), (.lt, pad.leftTrigger),
        (.rt, pad.rightTrigger), (.menu, pad.buttonMenu),
      ]
      for (control, button) in buttons where button.isPressed { controls.insert(control) }
      let reading = ControllerReading(
        name: device.vendorName ?? device.productCategory,
        connected: true, x: pad.leftThumbstick.xAxis.value, y: pad.leftThumbstick.yAxis.value,
        controls: controls)
      if readings[index] != reading { readings[index] = reading }
    }
    return disconnected
  }
}
