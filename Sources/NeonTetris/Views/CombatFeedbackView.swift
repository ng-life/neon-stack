import SwiftUI
import TetrisCore

struct CombatFeedbackView: View {
  let board: Board
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let event = board.lastCombatEvent {
        Text("上次交互").font(.caption2).foregroundStyle(.secondary)
        Text("发送 \(event.sent) · 抵消 \(event.cancelled)").font(.caption.bold()).foregroundStyle(
          .cyan)
        if event.received > 0 {
          Text("已进入 \(event.received) 行").font(.caption).foregroundStyle(.orange)
        }
      }
      Text("待接收 \(board.pendingGarbage) 行").font(.caption.bold()).foregroundStyle(
        board.pendingGarbage > 0 ? .orange : .secondary)
      if board.pendingGarbage > 0 {
        HStack(spacing: 3) {
          ForEach(0..<8, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2).fill(
              index < min(8, board.pendingGarbage) ? Color.orange : Color.white.opacity(0.1)
            ).frame(height: 5)
          }
        }
        Text("下次未消行锁定时进入，最多 8 行；消行可先抵消。")
          .font(.caption2).foregroundStyle(.secondary)
      }
      if board.dangerLevel != .safe {
        Label(
          board.dangerLevel == .critical ? "堆顶危险" : "堆叠偏高",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption.bold()).foregroundStyle(board.dangerLevel == .critical ? .red : .orange)
      }
    }.accessibilityElement(children: .combine)
  }
}
