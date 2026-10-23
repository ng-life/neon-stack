import SwiftUI
import TetrisCore
import UniformTypeIdentifiers

struct GameSettingsView: View {
  @Bindable var match: MatchStore
  @Environment(\.dismiss) private var dismiss
  @State private var showingImporter = false
  @State private var importTarget: BackgroundTarget = .menu
  var inWindow = false
  private var settings: GameMenuSettings { match.menuSettings }

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Text("设置").font(.title.bold())
        Spacer()
        Button("返回 · " + match.backHint) { match.closeSettings() }
          .modifier(GameButtonAppearance())
      }
      HStack(spacing: 10) {
        Text(match.hasController ? "LB" : "PgUp").foregroundStyle(.secondary)
        ForEach(GameMenuSettings.Tab.allCases, id: \.self) { tab in
          Button(tab.rawValue) {
            settings.tab = tab
            settings.selected = 0
            settings.pendingClear = false
            settings.bindingCommand = nil
          }
          .modifier(GameButtonAppearance(prominent: settings.tab == tab))
          .foregroundStyle(settings.tab == tab ? .cyan : .primary)
          .overlay {
            if settings.tab == tab {
              RoundedRectangle(cornerRadius: 12).stroke(.cyan, lineWidth: 2).padding(-3)
            }
          }
          .accessibilityAddTraits(settings.tab == tab ? .isSelected : [])
        }
        Text(match.hasController ? "RB" : "PgDn").foregroundStyle(.secondary)
      }
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 8) {
            ForEach(Array(settings.titles.enumerated()), id: \.offset) { index, title in
              HStack {
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
                settingControl(index)
              }.padding(12)
                .background(
                  .white.opacity(settings.selected == index ? 0.12 : 0.04),
                  in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                  if settings.selected == index {
                    RoundedRectangle(cornerRadius: 12).stroke(.yellow, lineWidth: 2)
                  }
                }
                .id(index)
            }
            if settings.tab == .background { BackgroundSettingsView(settings: match.backgrounds) }
            if settings.tab == .scores {
              Text("最高分：" + (match.scores.best(settings.scoreMode).map(String.init) ?? "暂无成绩"))
              ForEach(match.scores.records(settings.scoreMode)) { record in
                VStack(alignment: .leading, spacing: 8) {
                  Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    .foregroundStyle(.secondary)
                  ResultStatisticsView(
                    players: record.players, elapsed: record.elapsed, versus: record.mode == .versus
                  )
                }.padding(8)

              }
            }
            if settings.tab == .controllers {
              ForEach(0..<2, id: \.self) { player in
                let reading = match.controllerHub.readings[player]
                VStack(alignment: .leading, spacing: 8) {
                  Text("玩家 \(player + 1) · \(reading.name)").font(.headline)
                  Text(reading.connected ? "已连接" : "未连接")
                  Text(String(format: "摇杆 X %.2f / Y %.2f", reading.x, reading.y))
                  Text(
                    "当前输入："
                      + PadControl.allCases.filter { reading.controls.contains($0) }.map(\.title)
                      .joined(separator: "、"))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
              }
              Text("菜单按键固定；棋盘按键可在操作页调整。").font(.caption).foregroundStyle(.secondary)
            }
            if settings.tab == .logs {
              Text("日志保存在本机：\n" + DiagnosticLog.shared.directory.path).font(.caption).textSelection(
                .enabled)
            }
            if !settings.notice.isEmpty { Text(settings.notice).foregroundStyle(.orange) }
            if let error = match.scores.errorMessage { Text(error).foregroundStyle(.orange) }
          }.padding(4)
        }
        .onChange(of: settings.selected) {
          withAnimation { proxy.scrollTo(settings.selected, anchor: .center) }
        }
        .onChange(of: settings.tab) { proxy.scrollTo(0, anchor: .top) }
      }
      Text(match.settingsHint + "\n设置自动保存；清理成绩需要再次按 " + match.confirmHint + " 确认。")
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
      .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.image]) { result in
        if case .success(let url) = result {
          let target = importTarget
          Task { await match.backgrounds.importImage(from: url, for: target) }
        } else if case .failure = result {
          match.backgrounds.errorMessage = "无法打开所选图片。"
        }
      }
      .onChange(of: showingImporter) {
        if !showingImporter { match.backgrounds.choosingImage = false }
      }
      .onChange(of: match.backgrounds.importerRequest) {
        guard inWindow == match.settingsWindowVisible else { return }
        importTarget = match.backgrounds.target
        showingImporter = true
      }
      .onAppear {
        if inWindow {
          match.settingsWindowVisible = true
          match.openSettings()
        }
      }
      .onDisappear {
        if inWindow {
          match.settingsWindowVisible = false
          match.closeSettings()
        }
      }
      .onChange(of: match.screen) { if inWindow && match.screen != .settings { dismiss() } }
  }

  @ViewBuilder private func settingControl(_ index: Int) -> some View {
    if settings.tab == .background {
      if index == 0 {
        Picker(
          "应用界面",
          selection: Binding(
            get: { match.backgrounds.target },
            set: {
              match.backgrounds.target = $0
              settings.selected = index
            })
        ) {
          ForEach(BackgroundTarget.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.labelsHidden().frame(width: 180)
      } else if index == 1 {
        Picker(
          "背景图片",
          selection: Binding(
            get: { match.backgrounds.selection(match.backgrounds.target) },
            set: {
              match.backgrounds.select($0, for: match.backgrounds.target)
              settings.selected = index
            })
        ) {
          ForEach(BuiltInBackground.all) { Text($0.title).tag($0.id) }
          if match.backgrounds.hasCustom(match.backgrounds.target) { Text("本机图片").tag("custom") }
        }.labelsHidden().frame(width: 180)
      } else {
        Button("选择图片…") {
          settings.selected = index
          match.confirmSetting()
        }.disabled(match.backgrounds.importing)
      }
    } else if settings.tab == .audio && [0, 2, 4, 8, 10].contains(index) {
      Toggle(
        settings.value(index),
        isOn: Binding(
          get: {
            switch index {
            case 0: settings.audio.musicEnabled
            case 2: settings.audio.effectsEnabled
            case 4: settings.audio.operationsEnabled
            case 8: settings.audio.warningEnabled
            default: settings.reducedEffects
            }
          },
          set: { value in
            settings.selected = index
            if index == 10 {
              settings.reducedEffects = value
            } else if index == 8 {
              settings.audio.warningEnabled = value
            } else if index == 0 {
              settings.audio.musicEnabled = value
            } else if index == 2 {
              settings.audio.effectsEnabled = value
            } else {
              settings.audio.operationsEnabled = value
            }
          })
      ).toggleStyle(.switch).fixedSize().accessibilityLabel(settings.titles[index])
    } else if settings.tab == .audio && [1, 3, 5, 9].contains(index) {
      Slider(
        value: Binding<Float>(
          get: {
            switch index {
            case 1: settings.audio.musicVolume
            case 3: settings.audio.effectsVolume
            case 5: settings.audio.operationsVolume
            default: settings.audio.warningVolume
            }
          },
          set: { value in
            settings.selected = index
            if index == 9 {
              settings.audio.warningVolume = value
            } else if index == 1 {
              settings.audio.musicVolume = value
            } else if index == 3 {
              settings.audio.effectsVolume = value
            } else {
              settings.audio.operationsVolume = value
            }
          }), in: 0...1
      ).frame(width: 180).accessibilityLabel(settings.titles[index])
      Text(settings.value(index)).monospacedDigit().frame(width: 45)
    } else if settings.tab == .input && index == 0 {
      Picker(
        "玩家",
        selection: Binding(
          get: { settings.player },
          set: {
            settings.player = $0
            settings.selected = index
            settings.bindingCommand = nil
          })
      ) {
        Text("玩家 1").tag(0)
        Text("玩家 2").tag(1)
      }.labelsHidden().frame(width: 170)
    } else if settings.tab == .input && (1...3).contains(index) {
      Stepper {
        Text(settings.value(index)).monospacedDigit().frame(width: 90, alignment: .trailing)
      } onIncrement: {
        settings.selected = index
        settings.adjust(1)
      } onDecrement: {
        settings.selected = index
        settings.adjust(-1)
      }
      .fixedSize().accessibilityLabel(settings.titles[index])
    } else if settings.tab == .input && PadControl.allCases.indices.contains(index - 4) {
      let control = PadControl.allCases[index - 4]
      Picker(
        control.title,
        selection: Binding(
          get: { settings.input.mapping(player: settings.player, control: control) },
          set: { command in
            settings.selected = index
            if !settings.input.setMapping(
              player: settings.player, control: control, command: command)
            {
              settings.notice = "至少保留一个暂停按键"
            }
          })
      ) {
        ForEach(InputCommand.allCases) { command in Text(command.title).tag(command) }
      }.labelsHidden().frame(width: 170)
    } else if let command = settings.keyboardCommand(index) {
      Button(
        settings.bindingCommand == command
          ? "请按新按键 · Esc 取消"
          : KeyChoice.title(settings.input.key(player: settings.player, command: command))
            + " · 重新绑定"
      ) {
        settings.selected = index
        settings.bindingCommand = command
        settings.notice = ""
      }.modifier(GameButtonAppearance(size: .small))
    } else if settings.tab == .scores && index == 0 {
      Picker(
        "成绩模式",
        selection: Binding(
          get: { settings.scoreMode },
          set: {
            settings.scoreMode = $0
            settings.selected = index
            settings.pendingClear = false
          })
      ) {
        Text("单人挑战").tag(GameMode.solo)
        Text("双人对战").tag(GameMode.versus)
      }.labelsHidden().frame(width: 170)
    } else {
      Button(
        settings.pendingClear && settings.tab == .scores && settings.selected == index
          ? "确认清理"
          : (settings.tab == .audio
            ? "试听" : (settings.tab == .logs ? "打开" : (settings.tab == .scores ? "清理" : "恢复默认")))
      ) {
        if settings.selected != index { settings.pendingClear = false }
        settings.selected = index
        match.confirmSetting()
      }.modifier(GameButtonAppearance(size: .small))
    }
  }
}
