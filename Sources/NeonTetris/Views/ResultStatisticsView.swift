import SwiftUI

struct ResultStatisticsView: View {
  let players: [PlayerScore]
  let elapsed: Double
  let versus: Bool

  var body: some View {
    VStack(spacing: 12) {
      Label("有效用时 \(duration)", systemImage: "clock")
        .font(.headline).foregroundStyle(.secondary)
      if versus {
        Text(
          "局分 \(players.first?.roundWins.map(String.init) ?? "—") : \(players.last?.roundWins.map(String.init) ?? "—")"
        )
        .font(.title2.bold()).foregroundStyle(.cyan)
      }
      HStack(alignment: .top, spacing: 20) {
        ForEach(Array(players.enumerated()), id: \.offset) { player, stats in
          VStack(alignment: .leading, spacing: 10) {
            if versus {
              Text("玩家 \(player + 1)").font(.headline).foregroundStyle(
                player == 0 ? .cyan : .purple)
            }
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
              row("得分", String(stats.score))
              row("消行数", "\(stats.lines) 行")
              row("每分钟消行数", String(format: "%.1f 行", stats.linesPerMinute(elapsed: elapsed)))
              row("四行消除", stats.fourLineClears.map { "\($0) 次" } ?? "—")
              if versus { row("发出攻击", stats.attackSent.map { "\($0) 行" } ?? "—") }
            }
          }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        }
      }
      if versus {
        Text("攻击量为抵消后的实际发送量；局分在连续重开中累计，结束游戏后重置。").font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private var duration: String { String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60) }
  private func row(_ title: String, _ value: String) -> some View {
    GridRow {
      Text(title).foregroundStyle(.secondary)
      Text(value).monospacedDigit().bold()
    }
  }
}
