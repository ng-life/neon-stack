import SwiftUI

struct ControllerDiagnosticsView: View {
  let hub: ControllerHub
  let input: InputSettings
  var body: some View {
    Form {
      Section("实体设备") {
        LabeledContent("可用扩展手柄", value: "\(hub.availableCount) 只")
        Text(hub.availableCount < 2 ? "未连接两只手柄，实体双手柄验收尚未完成。" : "已检测到两只手柄，请按验收清单逐项操作；检测到设备不代表测试通过。")
          .font(.caption).foregroundStyle(hub.availableCount < 2 ? .orange : .secondary)
      }
      ForEach(0..<2, id: \.self) { player in
        let reading = hub.readings[player]
        Section("玩家 \(player + 1)") {
          LabeledContent("绑定设备", value: reading.name)
          LabeledContent("连接状态", value: reading.connected ? "已连接" : "未连接")
          LabeledContent("左摇杆 X / Y", value: String(format: "%.2f / %.2f", reading.x, reading.y))
          LabeledContent("摇杆死区", value: "\(Int((input.deadZone * 100).rounded()))%")
          Text(
            "当前输入："
              + (reading.controls.isEmpty
                ? "无"
                : PadControl.allCases.filter {
                  reading.controls.contains($0)
                }.map(\.title).joined(separator: "、")))
          Text(
            "映射操作："
              + InputCommand.allCases.filter {
                input.commands(player: player, controls: reading.controls).contains($0)
              }.map(\.title).joined(separator: "、")
          )
          .foregroundStyle(.cyan)
        }
      }
      Section("验收步骤") {
        Text(
          "1. 分别按两只手柄，确认只有对应玩家的输入变化。\n2. 在游戏中测试短按、长按、旋转、暂存和硬降。\n3. 双人游戏中断开一只手柄，确认暂停；重连后手动继续。\n4. 单人游戏中断开第二只手柄，确认游戏不暂停。\n5. 交换断开顺序并重复多局，检查绑定是否稳定。"
        )
        .font(.callout)
        Text("设置窗口中的手柄输入只用于诊断，不会操作棋盘。连接状态不代表验收通过，请逐项验证。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped)
  }
}
