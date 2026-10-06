import SwiftUI

struct SettingsView: View {
  @Bindable var settings: AudioSettings
  let sounds: ClearSoundPlayer
  let onOpen: () -> Void

  var body: some View {
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
      Text("设置自动保存。关闭设置后，点击游戏中的「继续」恢复游戏。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear(perform: onOpen)
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
