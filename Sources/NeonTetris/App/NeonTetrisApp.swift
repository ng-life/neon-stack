import AppKit
import SwiftUI

@main
struct NeonTetrisApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var audioSettings: AudioSettings
  @State private var match: MatchStore

  init() {
    let settings = AudioSettings()
    _audioSettings = State(initialValue: settings)
    _match = State(initialValue: MatchStore(settings: settings))
  }

  var body: some Scene {
    WindowGroup("Neon Stack") { ContentView(match: match) }
      .defaultSize(width: 1280, height: 880)
      .commands { CommandGroup(replacing: .newItem) {} }
    Settings {
      SettingsView(settings: audioSettings, sounds: match.sounds, onOpen: match.pauseForSettings)
    }
  }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
