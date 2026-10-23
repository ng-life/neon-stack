import Foundation
import OSLog

/// Serialized, bounded breadcrumbs survive process crashes without installing unsafe signal handlers.
final class DiagnosticLog: @unchecked Sendable {
  static let shared = DiagnosticLog()
  let directory: URL
  private let lock = NSLock()
  private let enabled: Bool
  private let limit: Int
  private let runID = UUID().uuidString
  private let logger = Logger(subsystem: "com.nglife.neon-tetris", category: "diagnostics")

  init(
    directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Logs/NeonStack"), limit: Int = 512_000,
    enabled: Bool = ProcessInfo.processInfo.processName != "xctest"
  ) {
    self.directory = directory
    self.limit = limit
    self.enabled = enabled
  }

  func record(_ event: String, fields: [String: String] = [:], error: Bool = false) {
    guard enabled else { return }
    lock.lock()
    defer { lock.unlock() }
    if error {
      logger.error("\(event, privacy: .public) \(fields.description, privacy: .public)")
    } else {
      logger.debug("\(event, privacy: .public) \(fields.description, privacy: .public)")
    }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appendingPathComponent("events.jsonl")
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      if size >= limit {
        let oldest = directory.appendingPathComponent("events.2.jsonl")
        try? FileManager.default.removeItem(at: oldest)
        let previous = directory.appendingPathComponent("events.1.jsonl")
        if FileManager.default.fileExists(atPath: previous.path) {
          try FileManager.default.moveItem(at: previous, to: oldest)
        }
        try FileManager.default.moveItem(at: url, to: previous)
      }
      var entry = fields
      entry["event"] = event
      entry["run"] = runID
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      entry["time"] = formatter.string(from: Date())
      entry["uptime"] = String(ProcessInfo.processInfo.systemUptime)
      entry["level"] = error ? "error" : "info"
      var data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
      data.append(10)
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      let handle = try FileHandle(forWritingTo: url)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
    } catch {
      logger.error("Diagnostic write failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func startSession() {
    let marker = directory.appendingPathComponent("session.json")
    if let data = try? Data(contentsOf: marker),
      let state = try? JSONSerialization.jsonObject(with: data) as? [String: String],
      state["clean"] == "false"
    {
      record(
        "previous_session_unclosed", fields: ["previousRun": state["run"] ?? "unknown"], error: true
      )
    }
    record("app_start", fields: ["os": ProcessInfo.processInfo.operatingSystemVersionString])
    writeMarker(clean: false)
  }

  func finishSession() {
    record("app_terminate")
    writeMarker(clean: true)
  }

  private func writeMarker(clean: Bool) {
    guard enabled else { return }
    lock.lock()
    defer { lock.unlock() }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let data = try JSONSerialization.data(withJSONObject: ["run": runID, "clean": String(clean)])
      try data.write(to: directory.appendingPathComponent("session.json"), options: .atomic)
    } catch {
      logger.error("Session marker failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
