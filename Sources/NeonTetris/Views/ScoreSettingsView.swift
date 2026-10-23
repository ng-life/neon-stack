import SwiftUI
import TetrisCore

struct ScoreSettingsView: View {
  let scores: ScoreStore
  @State private var mode: GameMode = .solo
  @State private var clearAll = false
  @State private var confirming = false

  var body: some View {
    Form {
      Picker("模式", selection: $mode) {
        Text("单人挑战").tag(GameMode.solo)
        Text("双人对战").tag(GameMode.versus)
      }.pickerStyle(.segmented)
      LabeledContent("最高分", value: scores.best(mode).map(String.init) ?? "暂无成绩")
      Text("双人纪录取双方最高得分。只记录已结束的对局，每个模式保留最近 100 局；最高分不受历史条数限制。")
        .font(.caption).foregroundStyle(.secondary)
      if let message = scores.errorMessage { Text(message).foregroundStyle(.orange) }
      Section("历史成绩") {
        if scores.records(mode).isEmpty { Text("暂无已结束的对局").foregroundStyle(.secondary) }
        ForEach(scores.records(mode)) { record in
          VStack(alignment: .leading, spacing: 4) {
            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
              .foregroundStyle(.secondary)
            Text(
              record.players.enumerated().map {
                "玩家 \($0.offset + 1)：\($0.element.score) 分 / \($0.element.lines) 行"
              }.joined(separator: " · "))
            Text(
              "用时 \(Int(record.elapsed)) 秒"
                + (record.mode == .versus
                  ? (record.winnerPlayer.map { " · 玩家 \($0 + 1) 获胜" } ?? " · 平局") : "")
            )
            .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      HStack {
        Button("清理当前模式", role: .destructive) {
          clearAll = false
          confirming = true
        }
        Button("清理全部成绩", role: .destructive) {
          clearAll = true
          confirming = true
        }
      }
    }.formStyle(.grouped)
      .confirmationDialog("清理\(clearAll ? "全部" : "当前模式")成绩及最高分？", isPresented: $confirming) {
        Button("清理成绩", role: .destructive) { scores.clear(clearAll ? nil : mode) }
      } message: {
        Text("清理后无法恢复。")
      }
  }
}
