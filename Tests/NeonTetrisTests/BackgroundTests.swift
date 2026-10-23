import AppKit
import XCTest

@testable import NeonTetris

@MainActor final class BackgroundTests: XCTestCase {
  func testCatalogIsCompleteAndSelectionsPersistIndependently() throws {
    XCTAssertEqual(BuiltInBackground.all.count, 10)
    XCTAssertEqual(Set(BuiltInBackground.all.map(\.id)).count, 10)
    for item in BuiltInBackground.all {
      let url = try XCTUnwrap(item.url, item.id)
      XCTAssertNotNil(NSImage(contentsOf: url), item.id)
    }
    let domain = "BackgroundTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
      defaults.removePersistentDomain(forName: domain)
      try? FileManager.default.removeItem(at: directory)
    }
    let settings = BackgroundSettings(defaults: defaults, directory: directory)
    settings.select("city", for: .menu)
    settings.select("ocean", for: .game)
    settings.select("unknown", for: .menu)
    let restored = BackgroundSettings(defaults: defaults, directory: directory)
    XCTAssertEqual(restored.selection(.menu), "city")
    XCTAssertEqual(restored.selection(.game), "ocean")
    XCTAssertNotNil(restored.image(.menu))
    settings.target = .game
    settings.cycle(1)
    XCTAssertEqual(settings.selection(.game), "retro")
  }

  func testBackgroundSettingsKeyboardNavigationAndImportRequest() {
    let domain = "BackgroundNavigationTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let backgrounds = BackgroundSettings(defaults: defaults)
    let match = MatchStore(
      settings: AudioSettings(defaults: defaults), input: InputSettings(defaults: defaults),
      scores: ScoreStore(defaults: defaults), backgrounds: backgrounds, startRuntime: false)
    match.openSettings()
    match.menuSettings.tab = .background
    match.handleMenuKey(124)
    XCTAssertEqual(backgrounds.target, .game)
    match.handleMenuKey(125)
    match.handleMenuKey(124)
    XCTAssertEqual(backgrounds.selection(.game), "nebula")
    XCTAssertEqual(backgrounds.selection(.menu), "aurora")
    match.handleMenuKey(125)
    match.handleMenuKey(36)
    XCTAssertEqual(backgrounds.importerRequest, 1)
    XCTAssertTrue(backgrounds.choosingImage)
  }

  func testImportOwnsCopyAndInvalidImagePreservesSelection() async throws {
    let domain = "BackgroundImportTests.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
      defaults.removePersistentDomain(forName: domain)
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let source = directory.appendingPathComponent("source.jpg")
    try Data(contentsOf: XCTUnwrap(BuiltInBackground.all[0].url)).write(to: source)
    let settings = BackgroundSettings(
      defaults: defaults, directory: directory.appendingPathComponent("owned"))
    await settings.importImage(from: source, for: .menu)
    XCTAssertNil(settings.errorMessage)
    XCTAssertEqual(settings.selection(.menu), "custom")
    XCTAssertEqual(settings.selection(.game), "aurora")
    try FileManager.default.removeItem(at: source)
    let restored = BackgroundSettings(
      defaults: defaults, directory: directory.appendingPathComponent("owned"))
    XCTAssertNotNil(restored.image(.menu))
    let invalid = directory.appendingPathComponent("invalid.jpg")
    try Data("not an image".utf8).write(to: invalid)
    await restored.importImage(from: invalid, for: .menu)
    XCTAssertNotNil(restored.errorMessage)
    XCTAssertEqual(restored.selection(.menu), "custom")
    XCTAssertNotNil(restored.image(.menu))
    XCTAssertFalse(restored.importing)
  }
}
