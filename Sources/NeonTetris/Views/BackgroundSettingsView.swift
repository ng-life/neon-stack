import SwiftUI

struct BackgroundSettingsView: View {
  let settings: BackgroundSettings
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("当前预览 · \(settings.target.rawValue)").font(.headline)
      GameBackgroundView(settings: settings, target: settings.target)
        .frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 16))
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
        ForEach(BuiltInBackground.all) { background in
          Button {
            settings.select(background.id, for: settings.target)
          } label: {
            VStack(spacing: 5) {
              if let image = settings.thumbnails[background.id] {
                Image(nsImage: image).resizable().scaledToFill().frame(height: 55).clipped()
              }
              Text(background.title).font(.caption)
            }.frame(maxWidth: .infinity).padding(5)
          }.buttonStyle(.plain)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              if settings.selection(settings.target) == background.id {
                RoundedRectangle(cornerRadius: 8).stroke(.cyan, lineWidth: 2)
              }
            }
        }
      }
      Text("开始界面与游戏界面分别保存。方向键选择「背景图片」后左右切换；本机图片导入后保留在应用目录，原文件可移动。图片按比例铺满，边缘可能裁切。")
        .font(.caption).foregroundStyle(.secondary)
      if settings.importing { ProgressView("正在导入图片…") }
      if let error = settings.errorMessage { Text(error).foregroundStyle(.orange) }
    }
  }
}
