import SwiftUI

struct GameBackgroundView: View {
  let settings: BackgroundSettings
  let target: BackgroundTarget
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(red: 0.025, green: 0.035, blue: 0.07)
        if let image = settings.image(target) {
          Image(nsImage: image).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        Color.black.opacity(target == .game ? 0.48 : 0.35)
        LinearGradient(
          colors: [.black.opacity(0.45), .clear, .black.opacity(0.6)], startPoint: .top,
          endPoint: .bottom)
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
