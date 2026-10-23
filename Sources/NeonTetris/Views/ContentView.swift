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
          Text(match.mode == .solo ? "单人挑战" : "本地双人对战").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if match.running {
          Text(time).monospacedDigit()
          Button("暂停菜单 · " + (match.hasController ? "Menu" : "Esc")) { match.togglePause() }
            .modifier(GameButtonAppearance())
        }
      }.padding(24)
      if match.screen == .settings {
        GameSettingsView(match: match)
      } else if match.screen == .playing {
        HStack(alignment: .top, spacing: 0) {
          playerPanel(0)
          ZStack {
            ArenaView(
              boards: match.boards, reducedEffects: match.reducedEffects || systemReduceMotion
            )
            .id(match.roundID)
            if let number = match.countdownNumber {
              VStack(spacing: 12) {
                Text("准备开始").font(.title2.bold())
                Text("\(number)").font(.system(size: 80, weight: .black, design: .rounded))
                  .foregroundStyle(.cyan)
              }.padding(32).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
          if match.mode == .versus { playerPanel(1) } else { soloPanel }
        }
      } else {
        Spacer()
        VStack(spacing: 20) {
          Text(menuTitle).font(.system(size: 34, weight: .bold, design: .rounded))
          if match.screen == .results {
            if !match.newRecordPlayers.isEmpty {
              Label("新纪录！", systemImage: "trophy.fill").foregroundStyle(.yellow)
            }
            ResultStatisticsView(
              players: match.resultPlayers, elapsed: match.elapsed, versus: match.mode == .versus)
          }
          if match.screen == .pause {
            Text(match.pauseReason).foregroundStyle(.secondary)
            if let number = match.countdownNumber {
              Text("倒计时剩余 \(number) 秒").foregroundStyle(.secondary)
            }
          }
          ForEach(match.menuActions) { action in
            Button {
              match.activateMenu(action)
            } label: {
              HStack {
                Text(action.title)
                Spacer()
                if action == match.selectedMenuAction {
                  Text(match.confirmHint).font(.caption.bold()).padding(6).background(
                    .white.opacity(0.15), in: Circle())
                }
              }.frame(width: 260).padding(6)
            }.modifier(GameButtonAppearance(prominent: action == match.selectedMenuAction))
              .overlay {
                if action == match.selectedMenuAction {
                  RoundedRectangle(cornerRadius: 14).stroke(.yellow, lineWidth: 3).padding(-4)
                }
              }
          }
          Text(match.menuHint + (match.screen == .modes ? " · " + match.backHint + " 返回" : ""))
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
      }
      HStack {
        Text(
          match.running
            ? (match.hasController ? "Menu 打开暂停菜单" : "Esc 打开暂停菜单") : "NEON STACK · REALITYKIT")
        Spacer()
        Label(match.music.trackTitle, systemImage: "music.note")
        if match.running {
          Toggle("减少动效", isOn: $match.reducedEffects).toggleStyle(.checkbox)
        }
      }.font(.caption).foregroundStyle(.secondary).padding(20)
    }
    .background {
      GameBackgroundView(settings: match.backgrounds, target: match.started ? .game : .menu)
    }
    .preferredColorScheme(.dark)
    .frame(minWidth: 1100, minHeight: 760)
  }
  private var menuTitle: String {
    switch match.screen {
    case .main: "NEON STACK"
    case .modes: "选择游戏模式"
    case .pause: "暂停菜单"
    case .results: match.winner ?? "游戏结束"
    default: ""
    }
  }

  private var soloPanel: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("最高分：" + (match.scores.best(.solo).map(String.init) ?? "暂无成绩")).font(.headline)
        .foregroundStyle(.yellow)
      Text("SOLO / 单人挑战").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
      Label("消行得分", systemImage: "sparkles").font(.headline)
      Text("每消除 10 行提升等级，下落速度逐渐加快。")
        .font(.callout).foregroundStyle(.secondary)
      Label("本局目标", systemImage: "target").font(.headline)
      Text("下一等级还需 \(10 - match.boards[0].lines % 10) 行").font(.callout)
      if let record = match.scores.best(.solo) {
        Text(
          match.boards[0].score > record
            ? "已超过纪录 \(match.boards[0].score - record) 分"
            : "再得 \(record - match.boards[0].score + 1) 分刷新纪录"
        )
        .font(.callout).foregroundStyle(.secondary)
      } else {
        Text("完成本局，建立首个纪录").font(.callout).foregroundStyle(.secondary)
      }
      Text("操作说明见棋盘左侧，完整映射可在设置中查看。")
        .font(.caption).foregroundStyle(.secondary)
      Spacer()
    }.padding(20).frame(width: 190)
  }

  private var time: String {
    String(format: "%02d:%02d", Int(match.elapsed) / 60, Int(match.elapsed) % 60)
  }
  private func playerPanel(_ player: Int) -> some View {
    let board = match.boards[player]
    return ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 20) {
        Text("模式最高分：" + (match.scores.best(match.mode).map(String.init) ?? "暂无")).font(.caption)
          .foregroundStyle(.yellow)
        Text("PLAYER 0\(player + 1)").font(.caption.bold()).tracking(2).foregroundStyle(
          player == 0 ? .cyan : .purple)
        Label(match.controllerNames[player], systemImage: "gamecontroller").font(.caption)
          .lineLimit(
            2)
        VStack(alignment: .leading, spacing: 4) {
          Text("得分").foregroundStyle(.secondary).font(.caption)
          Text("\(board.score)").font(.system(size: 30, weight: .bold, design: .monospaced))
          Text("\(board.lines) 行  ·  等级 \(board.lines / 10 + 1)").font(.caption).foregroundStyle(
            .secondary)
        }
        if match.mode == .versus {
          CombatFeedbackView(board: board)
        } else if board.dangerLevel != .safe {
          Label("接近堆顶", systemImage: "exclamationmark.triangle.fill").font(.caption.bold())
            .foregroundStyle(board.dangerLevel == .critical ? .red : .orange)
        }
        if let reward = board.lastReward, !reward.title.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(reward.title).font(.caption.bold()).foregroundStyle(.yellow)
            if let clear = board.clearEvents.last, clear.reward == reward, clear.combo > 0 {
              Text("COMBO \(clear.combo)").font(.caption.bold()).foregroundStyle(.pink)
            }
            Text(
              "+\(reward.points) 分" + (match.mode == .versus ? " · 攻击 \(reward.attack) 行（抵消前）" : "")
            )
            .font(.caption2).foregroundStyle(.secondary)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("HOLD / 暂存").font(.caption).foregroundStyle(.secondary)
          PiecePreview(kind: board.held)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("NEXT / 接下来").font(.caption).foregroundStyle(.secondary)
          ForEach(Array(board.queue.enumerated()), id: \.offset) { _, kind in
            PiecePreview(kind: kind)
          }
        }
        Spacer()
        Text(
          match.controllerHub.readings[player].connected
            ? [PadControl.a, .b, .x, .y].filter {
              match.input.mapping(player: player, control: $0) != .unassigned
            }.map { "\($0.title) \(match.input.mapping(player: player, control: $0).title)" }
              .joined(
                separator: " · ") : match.input.keyboardSummary(player: player)
        )
        .font(.caption2).foregroundStyle(.secondary).lineSpacing(5)
      }.padding(20)
    }.frame(width: 190)
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
