/// One repeat clock per player, shared by keyboard and controller input.
/// Polling never uses the operating system's keyboard-repeat preferences.
struct InputRepeater {
  private var previous: Set<InputCommand> = []
  private var deadlines: [InputCommand: Double] = [:]

  mutating func immediate(_ command: InputCommand, now: Double, configuration: InputConfiguration) {
    deadlines[command] = now + (command == .down ? configuration.interval : configuration.delay)
  }
  mutating func poll(
    _ pressed: Set<InputCommand>, now: Double,
    configuration: InputConfiguration
  ) -> [InputCommand] {
    let prior = previous
    previous = pressed
    var result: [InputCommand] = []
    for command in InputCommand.allCases where command != .unassigned {
      guard pressed.contains(command) else {
        deadlines.removeValue(forKey: command)
        continue
      }
      let fresh = !prior.contains(command)
      if (fresh && deadlines[command] == nil)
        || (command.repeats && now >= (deadlines[command] ?? .infinity))
      {
        result.append(command)
        deadlines[command] =
          now + (fresh && command != .down ? configuration.delay : configuration.interval)
      }
    }
    return result
  }
  mutating func clearRepeats() { deadlines.removeAll() }
  mutating func releaseAll() {
    previous = []
    deadlines = [:]
  }
}
