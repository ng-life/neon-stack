import Foundation
import GameController
import IOKit.hid

RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
let controllers = GCController.controllers()
print("GameController count: \(controllers.count)")
for controller in controllers {
  print(
    "vendor=\(controller.vendorName ?? "unknown") category=\(controller.productCategory) extended=\(controller.extendedGamepad != nil)"
  )
}
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatchingMultiple(
  manager,
  [
    [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 4],
    [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 5],
  ] as CFArray)
IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
print("HID joystick/gamepad count: \(devices.count)")
for device in devices {
  print(
    "product=\(IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) ?? "unknown" as CFString)"
  )
}
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
