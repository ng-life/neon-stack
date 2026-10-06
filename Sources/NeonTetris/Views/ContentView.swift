import SwiftUI
import TetrisCore

struct ContentView: View {
  @Bindable var match: MatchStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("NEON / STACK").font(.system(size: 24, weight: .black, design: .rounded)).tracking(3)
          Text(match.mode == .solo ? "REALITYKIT  ·  单人挑战" : "REALITYKIT  ·  本地双人对战").font(.caption)
            .foregroundStyle(.secondary).tracking(2)
        }
        Spacer()
        GameGlassGroup {
          HStack(spacing: 12) {
            GameModeControl(selection: Binding(get: { match.mode }, set: { match.selectMode($0) }))
              .disabled(match.started && match.winner == nil)
            Text(time).font(.system(.title2, design: .monospaced)).foregroundStyle(.secondary)
              .padding(.horizontal, 4)
            Button(match.started ? "重新开始" : "开始游戏") { match.start() }
              .modifier(GameButtonAppearance(prominent: true))
            if match.started {
              Button("返回大厅") { match.returnToLobby() }
                .modifier(GameButtonAppearance())
            }
            if match.started && match.winner == nil {
              Button(match.running ? "暂停" : "继续") { match.togglePause() }
                .modifier(GameButtonAppearance())
            }
          }
        }
      }.padding(24)
      HStack(alignment: .top, spacing: 0) {
        playerPanel(0)
        ZStack {
          ArenaView(
            boards: match.boards, reducedEffects: match.reducedEffects || systemReduceMotion
          )
          .id(match.roundID)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          if !match.running {
            VStack(spacing: 12) {
              Image(
                systemName: match.winner == nil
                  ? "gamecontroller.fill" : (match.mode == .solo ? "flag.checkered" : "trophy.fill")
              )
              .font(.system(size: 38)).foregroundStyle(.cyan)
              Text(match.winner ?? match.pauseReason).font(.title2.bold())
              Text(overlayDetail)
                .foregroundStyle(.secondary)
              Button(match.winner != nil || !match.started ? "开始游戏" : "继续游戏") {
                if match.winner != nil || !match.started {
                  match.start()
                } else {
                  match.togglePause()
                }
              }.modifier(GameButtonAppearance(prominent: true))
            }.padding(32).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
          }
        }
        if match.mode == .versus { playerPanel(1) } else { soloPanel }
      }
      HStack(spacing: 28) {
        Label("方向键 / 摇杆移动", systemImage: "dpad")
        Text("A / B 旋转 · X 暂存 · Y 硬降")
        Spacer()
        Label(match.music.trackTitle, systemImage: "music.note").font(.caption2)
        SettingsLink { Label("设置", systemImage: "gearshape") }
          .modifier(GameButtonAppearance(size: .small))
        Toggle("减少动效", isOn: $match.reducedEffects).toggleStyle(.checkbox)
        Text(match.mode == .solo ? "消行升级 · 挑战高分" : "先堆顶者落败").foregroundStyle(.cyan)
      }.font(.caption).foregroundStyle(.secondary).padding(20)
    }
    .background(Color(red: 0.025, green: 0.035, blue: 0.07))
    .preferredColorScheme(.dark)
    .frame(minWidth: 1100, minHeight: 760)
  }
  private var overlayDetail: String {
    if match.mode == .solo {
      if match.winner != nil {
        return "得分 \(match.boards[0].score) · 消除 \(match.boards[0].lines) 行"
      }
      return match.started ? "消行升级 · 挑战高分" : "连接一只手柄，或使用键盘开始"
    }
    return match.started ? "同一序列 · 公平对决" : "连接两只手柄，或使用键盘开始"
  }

  private var soloPanel: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("SOLO / 单人挑战").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
      Label("消行得分", systemImage: "sparkles").font(.headline)
      Text("每消除 10 行提升等级，下落速度逐渐加快。")
        .font(.callout).foregroundStyle(.secondary)
      Label("自由操作", systemImage: "keyboard").font(.headline)
      Text("可使用 A / D 或方向键移动。空格或 Enter 硬降，Esc 暂停。")
        .font(.callout).foregroundStyle(.secondary)
      Text("返回大厅后可切换游戏模式。")
        .font(.caption).foregroundStyle(.secondary)
      Spacer()
    }.padding(20).frame(width: 190)
  }

  private var time: String {
    String(format: "%02d:%02d", Int(match.elapsed) / 60, Int(match.elapsed) % 60)
  }
  private func playerPanel(_ player: Int) -> some View {
    let board = match.boards[player]
    return VStack(alignment: .leading, spacing: 20) {
      Text("PLAYER 0\(player + 1)").font(.caption.bold()).tracking(2).foregroundStyle(
        player == 0 ? .cyan : .purple)
      Label(match.controllerNames[player], systemImage: "gamecontroller").font(.caption).lineLimit(
        2)
      VStack(alignment: .leading, spacing: 4) {
        Text("得分").foregroundStyle(.secondary).font(.caption)
        Text("\(board.score)").font(.system(size: 30, weight: .bold, design: .monospaced))
        Text("\(board.lines) 行  ·  等级 \(board.lines / 10 + 1)").font(.caption).foregroundStyle(
          .secondary)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("HOLD / 暂存").font(.caption).foregroundStyle(.secondary)
        PiecePreview(kind: board.held)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("NEXT / 接下来").font(.caption).foregroundStyle(.secondary)
        ForEach(Array(board.queue.enumerated()), id: \.offset) { _, kind in PiecePreview(kind: kind)
        }
      }
      if match.mode == .versus {
        Label("待接收 \(board.pendingGarbage) 行", systemImage: "arrow.down.square")
          .font(.caption).foregroundStyle(board.pendingGarbage > 0 ? .orange : .secondary)
      }
      Spacer()
      Text(
        player == 0
          ? "A / D 移动 · S 软降\nW / Q 旋转 · E 暂存\n空格硬降 · Esc 暂停"
          : "← / → 移动 · ↓ 软降\n↑ / , 旋转 · . 暂存\nEnter 硬降 · Esc 暂停"
      )
      .font(.caption2).foregroundStyle(.secondary).lineSpacing(5)
    }.padding(20).frame(width: 190)
  }
}

private struct PiecePreview: View {
  let kind: PieceKind?
  private let colors: [Color] = [.clear, .cyan, .yellow, .purple, .green, .red, .blue, .orange]
  var body: some View {
    Canvas { context, size in
      guard let kind else { return }
      let piece = Piece(kind: kind)
      for cell in piece.cells {
        let rect = CGRect(
          x: (cell.x - 3) * 19 + 25, y: (cell.y + 2) * 19 + 3, width: 16, height: 16)
        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(colors[kind.rawValue]))
      }
    }.frame(width: 128, height: 42)
  }
}
