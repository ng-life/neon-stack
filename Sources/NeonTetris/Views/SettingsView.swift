import AppKit
import SwiftUI

struct SettingsView: View {
  @Bindable var settings: AudioSettings
  let sounds: ClearSoundPlayer
  let operations: OperationSoundPlayer
  let input: InputSettings
  let scores: ScoreStore
  let hub: ControllerHub
  let onOpen: () -> Void

  var body: some View {
    TabView {
      ScoreSettingsView(scores: scores).tabItem { Label("成绩", systemImage: "trophy") }
      diagnostics.tabItem { Label("日志", systemImage: "doc.text.magnifyingglass") }
      audioForm.tabItem { Label("声音", systemImage: "speaker.wave.2") }
      InputSettingsView(input: input).tabItem { Label("操作", systemImage: "keyboard") }
      ControllerDiagnosticsView(hub: hub, input: input)
        .tabItem { Label("手柄诊断", systemImage: "gamecontroller") }
    }
    .frame(width: 620, height: 650)
    .onAppear(perform: onOpen)
  }

  private var diagnostics: some View {
    Form {
      Text("关键操作、音效播放和异常会自动记录到本机，最多保留三份约 500 KB 的日志。")
      Text("意外退出后重新打开游戏，再通过此入口找到日志，与 macOS 崩溃报告一起用于分析。未正常关闭标记也可能来自强制退出。")
        .font(.callout).foregroundStyle(.secondary)
      Text(DiagnosticLog.shared.directory.path).font(.caption).textSelection(.enabled)
      Button("打开日志文件夹") {
        DiagnosticLog.shared.record("logs_opened")
        NSWorkspace.shared.open(DiagnosticLog.shared.directory)
      }
    }.formStyle(.grouped)
  }

  private var audioForm: some View {
    Form {
      Section {
        Toggle("启用背景音乐", isOn: $settings.musicEnabled)
        volumeRow("背景音乐音量", value: $settings.musicVolume)
          .disabled(!settings.musicEnabled)
        Text("随等级自动换曲，暂停游戏时音乐同步暂停。")
          .font(.caption).foregroundStyle(.secondary)
      } header: {
        Label("背景音乐", systemImage: "music.note")
      }
      Section {
        Toggle("启用消行音效", isOn: $settings.effectsEnabled)
        volumeRow("消行音效音量", value: $settings.effectsVolume)
          .disabled(!settings.effectsEnabled)
        HStack {
          Text("消除行数越多，音效越丰富。")
            .font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button("试听四行消除") { sounds.play(rows: 4) }
            .modifier(GameButtonAppearance(size: .small))
            .disabled(!settings.effectsEnabled || settings.effectsVolume == 0)
        }
      } header: {
        Label("消行音效", systemImage: "waveform")
      }
      Section {
        Toggle("启用操作音效", isOn: $settings.operationsEnabled)
        volumeRow("操作音效音量", value: $settings.operationsVolume)
          .disabled(!settings.operationsEnabled)
        Button("试听硬降") { operations.play(.hardDrop) }
          .modifier(GameButtonAppearance(size: .small))
          .disabled(!settings.operationsEnabled || settings.operationsVolume == 0)
        Text("旋转、锁定与硬降使用轻量反馈。消行时 BGM 短暂降低至 30%，随后平滑恢复。")
          .font(.caption).foregroundStyle(.secondary)
      } header: {
        Label("操作音效", systemImage: "hand.tap")
      }
      Text("设置自动保存。关闭设置后，点击游戏中的「继续」恢复游戏。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .formStyle(.grouped)

  }

  private func volumeRow(_ title: String, value: Binding<Float>) -> some View {
    HStack {
      Text(title).frame(width: 110, alignment: .leading)
      Slider(value: value, in: 0...1).accessibilityLabel(title)
      Text("\(Int((value.wrappedValue * 100).rounded()))%")
        .monospacedDigit().frame(width: 45, alignment: .trailing)
    }
  }
}
