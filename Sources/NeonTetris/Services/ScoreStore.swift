import Foundation
import Observation
import TetrisCore

struct PlayerScore: Codable, Equatable {
  let score: Int
  let lines: Int
  // Optional fields preserve archives written before detailed statistics existed.
  let fourLineClears: Int?
  let attackSent: Int?
  let roundWins: Int?

  init(
    score: Int, lines: Int, fourLineClears: Int? = nil, attackSent: Int? = nil,
    roundWins: Int? = nil
  ) {
    self.score = score
    self.lines = lines
    self.fourLineClears = fourLineClears
    self.attackSent = attackSent
    self.roundWins = roundWins
  }

  func linesPerMinute(elapsed: Double) -> Double {
    guard elapsed.isFinite, elapsed > 0 else { return 0 }
    return Double(lines) * 60 / elapsed
  }
}

struct ScoreRecord: Codable, Identifiable, Equatable {
  let id: UUID
  let mode: GameMode
  let date: Date
  let elapsed: Double
  let players: [PlayerScore]
  let winnerPlayer: Int?
}

@MainActor @Observable final class ScoreStore {
  private struct Archive: Codable {
    var records: [ScoreRecord] = []
    var best: [String: Int] = [:]
  }
  private var archive = Archive()
  private let defaults: UserDefaults
  var errorMessage: String?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    guard let data = defaults.data(forKey: "scores.archive") else { return }
    do { archive = try JSONDecoder().decode(Archive.self, from: data) } catch {
      errorMessage = "成绩读取失败，请查看诊断日志。"
      DiagnosticLog.shared.record(
        "scores_load_failed", fields: ["error": error.localizedDescription], error: true)
    }
  }

  func best(_ mode: GameMode) -> Int? { archive.best[mode.rawValue] }
  func records(_ mode: GameMode) -> [ScoreRecord] {
    archive.records.filter { $0.mode == mode }.reversed()
  }

  /// Keep 100 finished matches per mode; the lifetime best survives history trimming.
  @discardableResult func save(_ record: ScoreRecord) -> Set<Int> {
    guard !archive.records.contains(where: { $0.id == record.id }),
      record.players.count == record.mode.playerCount, record.elapsed.isFinite, record.elapsed >= 0
    else { return [] }
    let maximum = record.players.map(\.score).max() ?? 0
    let isNew = best(record.mode).map { maximum > $0 } ?? true
    if isNew { archive.best[record.mode.rawValue] = maximum }
    archive.records.append(record)
    let ids = Set(archive.records.filter { $0.mode == record.mode }.suffix(100).map(\.id))
    archive.records.removeAll { $0.mode == record.mode && !ids.contains($0.id) }
    persist()
    DiagnosticLog.shared.record(
      "score_saved",
      fields: [
        "round": record.id.uuidString, "mode": record.mode.rawValue, "score": String(maximum),
        "newRecord": String(isNew),
      ])
    return isNew ? Set(record.players.indices.filter { record.players[$0].score == maximum }) : []
  }

  func clear(_ mode: GameMode? = nil) {
    if let mode {
      archive.records.removeAll { $0.mode == mode }
      archive.best.removeValue(forKey: mode.rawValue)
    } else {
      archive = Archive()
    }
    persist()
    DiagnosticLog.shared.record("scores_cleared", fields: ["mode": mode?.rawValue ?? "all"])
  }

  private func persist() {
    do {
      defaults.set(try JSONEncoder().encode(archive), forKey: "scores.archive")
      errorMessage = nil
    } catch {
      errorMessage = "成绩保存失败，请查看诊断日志。"
      DiagnosticLog.shared.record(
        "scores_save_failed", fields: ["error": error.localizedDescription], error: true)
    }
  }
}
