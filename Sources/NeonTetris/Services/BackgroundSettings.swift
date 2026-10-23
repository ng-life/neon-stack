import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers

struct BuiltInBackground: Identifiable {
  let id: String
  let title: String
  static let all: [Self] = [
    .init(id: "aurora", title: "极光静湖"), .init(id: "nebula", title: "紫夜星云"),
    .init(id: "city", title: "霓虹雨城"), .init(id: "prisms", title: "晶体光场"),
    .init(id: "moon", title: "月映山湖"), .init(id: "desert", title: "星环沙海"),
    .init(id: "ocean", title: "深海微光"), .init(id: "retro", title: "落日脉冲"),
    .init(id: "forest", title: "萤火竹林"), .init(id: "silk", title: "流光丝绸"),
  ]
  var url: URL? {
    Bundle.module.url(forResource: id, withExtension: "jpg", subdirectory: "Backgrounds")
  }
}

enum BackgroundTarget: String, CaseIterable {
  case menu = "开始界面"
  case game = "游戏界面"
}

@MainActor @Observable final class BackgroundSettings {
  private let defaults: UserDefaults
  private let directory: URL
  private var selections: [String: String]
  private(set) var images: [String: NSImage] = [:]
  let thumbnails: [String: NSImage]
  var target: BackgroundTarget = .menu
  var importing = false
  var errorMessage: String?
  var importerRequest = 0
  var choosingImage = false

  init(defaults: UserDefaults = .standard, directory: URL? = nil) {
    self.defaults = defaults
    self.directory =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("NeonStack/Backgrounds")
    thumbnails = Dictionary(
      uniqueKeysWithValues: BuiltInBackground.all.compactMap { item in
        guard let url = item.url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(
            source, 0,
            [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceThumbnailMaxPixelSize: 320,
            ] as CFDictionary)
        else { return nil }
        return (item.id, NSImage(cgImage: image, size: .zero))
      })
    selections = defaults.dictionary(forKey: "background.selections") as? [String: String] ?? [:]
    for target in BackgroundTarget.allCases { refresh(target) }
  }
  func selection(_ target: BackgroundTarget) -> String { selections[target.rawValue] ?? "aurora" }
  func image(_ target: BackgroundTarget) -> NSImage? { images[target.rawValue] }
  func customURL(_ target: BackgroundTarget) -> URL {
    directory.appendingPathComponent(target == .menu ? "menu.jpg" : "game.jpg")
  }
  func hasCustom(_ target: BackgroundTarget) -> Bool {
    FileManager.default.fileExists(atPath: customURL(target).path)
  }
  func select(_ id: String, for target: BackgroundTarget) {
    guard
      BuiltInBackground.all.contains(where: { $0.id == id })
        || (id == "custom" && hasCustom(target))
    else { return }
    selections[target.rawValue] = id
    defaults.set(selections, forKey: "background.selections")
    refresh(target)
  }
  func cycle(_ direction: Int) {
    var ids = BuiltInBackground.all.map(\.id)
    if hasCustom(target) { ids.append("custom") }
    let index = ids.firstIndex(of: selection(target)) ?? 0
    select(ids[(index + direction + ids.count) % ids.count], for: target)
  }
  private func refresh(_ target: BackgroundTarget) {
    let id = selection(target)
    let url =
      id == "custom" ? customURL(target) : BuiltInBackground.all.first(where: { $0.id == id })?.url
    images[target.rawValue] =
      url.flatMap { NSImage(contentsOf: $0) }
      ?? BuiltInBackground.all[0].url.flatMap { NSImage(contentsOf: $0) }
  }
  /// Decode a bounded thumbnail off the main actor and own a normalized copy, not an external URL.
  func importImage(from url: URL, for target: BackgroundTarget) async {
    guard !importing else { return }
    importing = true
    errorMessage = nil
    defer { importing = false }
    do {
      let data = try await Task.detached(priority: .userInitiated) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(
            source, 0,
            [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true,
              kCGImageSourceThumbnailMaxPixelSize: 2560,
              kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary)
        else { throw CocoaError(.fileReadCorruptFile) }
        let data = NSMutableData()
        guard
          let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(
          destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
      }.value
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try data.write(to: customURL(target), options: .atomic)
      select("custom", for: target)
      DiagnosticLog.shared.record("background_imported", fields: ["target": target.rawValue])
    } catch {
      errorMessage = "无法导入图片，请选择可读取的有效图片。"
      DiagnosticLog.shared.record(
        "background_import_failed", fields: ["error": error.localizedDescription], error: true)
    }
  }
}
