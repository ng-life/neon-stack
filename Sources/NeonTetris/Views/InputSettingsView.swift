import SwiftUI

struct InputSettingsView: View {
  @Bindable var input: InputSettings
  @State private var player = 0
  @State private var error: String?

  var body: some View {
    Form {
      Section("操作手感") {
        settingSlider(
          "连移首次延迟", value: $input.delay, range: 0.05...0.5,
          display: "\(Int((input.delay * 1000).rounded())) ms")
        settingSlider(
          "连续移动间隔", value: $input.interval, range: 0.016...0.15,
          display: "\(Int((input.interval * 1000).rounded())) ms")
        Text("间隔越小，连移越快。软降直接使用移动间隔；旋转、暂存和硬降每次按下只触发一次。")
          .font(.caption).foregroundStyle(.secondary)
        settingSlider(
          "摇杆死区",
          value: Binding(
            get: { Double(input.deadZone) },
            set: { input.deadZone = Float($0) }), range: 0.1...0.9,
          display: "\(Int((input.deadZone * 100).rounded()))%")
        Text("死区只影响左摇杆，方向键不受影响。以上参数由两位玩家共用。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("玩家映射") {
        Picker("玩家", selection: $player) {
          Text("玩家 1").tag(0)
          Text("玩家 2").tag(1)
        }.pickerStyle(.segmented)
      }
      Section("键盘") {
        ForEach(InputCommand.allCases.filter { $0 != .unassigned }) { command in
          Picker(
            command.title,
            selection: Binding(
              get: { input.key(player: player, command: command) },
              set: { code in
                if !input.setKey(player: player, command: command, code: code) {
                  error = "该按键已用于其他操作。两位玩家的按键不能冲突，暂停键可以共用。"
                }
              })
          ) {
            ForEach(KeyChoice.all) { key in Text(key.title).tag(key.code) }
          }
        }
        Text("按键按键盘物理位置绑定；单人模式下，两套键盘映射都控制同一棋盘。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("手柄") {
        ForEach(PadControl.allCases) { control in
          Picker(
            control.title,
            selection: Binding(
              get: { input.mapping(player: player, control: control) },
              set: { command in
                if !input.setMapping(player: player, control: control, command: command) {
                  error = "每位玩家至少需要保留一个暂停 / 继续按钮。请先绑定新的暂停按钮。"
                }
              })
          ) {
            ForEach(InputCommand.allCases) { command in Text(command.title).tag(command) }
          }
        }
        Text("A/B/X/Y 按 Xbox 对应位置命名。可将多个按钮绑定到同一操作；方向键与摇杆方向共用映射。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Button("恢复默认输入设置") { input.reset() }
        .modifier(GameButtonAppearance(size: .small))
      Text("修改立即保存；游戏保持暂停，关闭设置后手动继续。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .alert("映射未修改", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
      Button("好") { error = nil }
    } message: {
      Text(error ?? "")
    }
  }

  private func settingSlider(
    _ title: String, value: Binding<Double>, range: ClosedRange<Double>,
    display: String
  ) -> some View {
    HStack {
      Text(title).frame(width: 110, alignment: .leading)
      Slider(value: value, in: range).accessibilityLabel(title)
      Text(display).monospacedDigit().frame(width: 70, alignment: .trailing)
    }
  }
}
