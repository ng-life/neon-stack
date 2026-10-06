import SwiftUI
import TetrisCore

/// System glass styles on macOS 26+, with native controls on earlier supported systems.
struct GameButtonAppearance: ViewModifier {
  var prominent = false
  var size: ControlSize = .large

  @ViewBuilder func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      if prominent {
        // Prominent glass uses a dense fill; a stronger tint keeps actions identifiable without an opaque fill.
        content.buttonStyle(.glass(.regular.tint(.cyan.opacity(0.75)).interactive()))
          .fontWeight(.semibold)
          .controlSize(size).buttonBorderShape(.capsule)
      } else {
        content.buttonStyle(.glass).controlSize(size).buttonBorderShape(.capsule)
      }
    } else {
      if prominent {
        content.buttonStyle(.borderedProminent).tint(.cyan).controlSize(size)
      } else {
        content.buttonStyle(.bordered).controlSize(size)
      }
    }
  }
}

struct GameGlassGroup<Content: View>: View {
  @ViewBuilder let content: Content

  @ViewBuilder var body: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: 12) { content }
    } else {
      content
    }
  }
}

struct GameModeControl: View {
  @Binding var selection: GameMode

  var body: some View {
    HStack(spacing: 14) {
      modeButton(.solo, title: "单人挑战", symbol: "person.fill")
      modeButton(.versus, title: "双人对战", symbol: "person.2.fill")
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("游戏模式")
  }

  private func modeButton(_ mode: GameMode, title: String, symbol: String) -> some View {
    Button {
      selection = mode
    } label: {
      HStack(spacing: 7) {
        Label(title, systemImage: symbol)
        Image(systemName: "checkmark.circle.fill")
          .opacity(selection == mode ? 1 : 0)
          .accessibilityHidden(true)
      }
      .foregroundStyle(selection == mode ? Color.cyan : Color.secondary)
    }
    .modifier(GameButtonAppearance(prominent: selection == mode))
    .accessibilityAddTraits(selection == mode ? .isSelected : [])
    .accessibilityValue(selection == mode ? "已选中" : "未选中")
  }
}
