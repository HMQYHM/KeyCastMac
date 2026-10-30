import SwiftUI
import AppKit

final class AppState: ObservableObject {
    var onChange: (() -> Void)?
    private var suppressNotify = false

    @Published var widgets: [Widget] { didSet { persistAndNotify() } }
    @Published var gamepadLayout: String { didSet { persistAndNotify() } }
    @Published var gamepadNames: [String] = []
    @Published var canvasSize: String { didSet { persistAndNotify() } }
    @Published var keycapShape: String { didSet { persistAndNotify() } }
    @Published var pressEffect: String { didSet { persistAndNotify() } }
    @Published var keyOutEffect: String { didSet { persistAndNotify() } }
    @Published var opacity: Double { didSet { persistAndNotify() } }
    @Published var globalBackgroundBrightness: Double {
        didSet {
            UserDefaults.standard.set(globalBackgroundBrightness, forKey: "globalBackgroundBrightness")
            persistAndNotify()
        }
    }
    @Published var scale: Double { didSet { persistAndNotify() } }
    @Published var locked: Bool { didSet { persistAndNotify() } }
    @Published var overlayVisible: Bool { didSet { persistAndNotify() } }
    @Published var alwaysOnTop: Bool { didSet { persistAndNotify() } }
    @Published var showOverFullscreen: Bool { didSet { persistAndNotify() } }
    @Published var language: String {
        didSet {
            currentLanguage = language
            UserDefaults.standard.set(language, forKey: "appLanguage")
            persistAndNotify()
        }
    }
    @Published var theme: String { didSet { persistAndNotify() } }
    @Published var accentHex: String { didSet { persistAndNotify() } }
    @Published var overlayX: Double { didSet { persist() } }
    @Published var overlayY: Double { didSet { persist() } }

    @Published var profiles: [String: Config] = [:]

    var config: Config {
        Config(widgets: widgets, gamepadLayout: gamepadLayout, canvasSize: canvasSize,
               keycapShape: keycapShape, pressEffect: pressEffect, keyOutEffect: keyOutEffect,
               opacity: opacity,
               scale: scale, locked: locked, overlayVisible: overlayVisible, alwaysOnTop: alwaysOnTop, showOverFullscreen: showOverFullscreen, theme: theme,
               accentHex: accentHex, overlayX: overlayX, overlayY: overlayY)
    }

    init() {
        ConfigStore.migrateIfNeeded()
        let c = ConfigStore.load()
        widgets = c.widgets
        gamepadLayout = c.gamepadLayout
        canvasSize = "full"
        keycapShape = c.keycapShape
        pressEffect = c.pressEffect
        keyOutEffect = c.keyOutEffect
        opacity = c.opacity
        globalBackgroundBrightness = (UserDefaults.standard.object(forKey: "globalBackgroundBrightness") as? Double) ?? 1.0
        scale = c.scale
        locked = c.locked
        overlayVisible = c.overlayVisible
        alwaysOnTop = c.alwaysOnTop
        showOverFullscreen = c.showOverFullscreen
        theme = c.theme
        accentHex = c.accentHex
        overlayX = c.overlayX
        overlayY = c.overlayY
        language = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"
        currentLanguage = language
        profiles = ProfileStore.load()
    }

    func saveProfile(_ name: String) {
        guard !name.isEmpty else { return }
        profiles[name] = config
        ProfileStore.save(profiles)
    }

    func applyConfig(_ c: Config) {
        suppressNotify = true
        widgets = c.widgets
        gamepadLayout = c.gamepadLayout
        canvasSize = "full"
        keycapShape = c.keycapShape
        pressEffect = c.pressEffect
        keyOutEffect = c.keyOutEffect
        opacity = c.opacity
        globalBackgroundBrightness = (UserDefaults.standard.object(forKey: "globalBackgroundBrightness") as? Double) ?? 1.0
        scale = c.scale
        locked = c.locked
        overlayVisible = c.overlayVisible
        alwaysOnTop = c.alwaysOnTop
        showOverFullscreen = c.showOverFullscreen
        theme = c.theme
        accentHex = c.accentHex
        overlayX = c.overlayX
        overlayY = c.overlayY
        suppressNotify = false
        persist()
        onChange?()
    }

    func loadProfile(_ name: String) {
        guard let c = profiles[name] else { return }
        applyConfig(c)
    }

    func exportConfig(to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: url)
        }
    }

    func importConfig(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Config.self, from: data) else { return }
        applyConfig(c.sanitized())
    }

    func deleteProfile(_ name: String) {
        profiles.removeValue(forKey: name)
        ProfileStore.save(profiles)
    }

    private var undoStack: [[Widget]] = []
    private var redoStack: [[Widget]] = []

    func recordUndo(oldWidgets: [Widget]) {
        undoStack.append(oldWidgets)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() -> Bool {
        guard let last = undoStack.popLast() else { return false }
        redoStack.append(widgets)
        widgets = last
        return true
    }

    func redo() -> Bool {
        guard let last = redoStack.popLast() else { return false }
        undoStack.append(widgets)
        widgets = last
        return true
    }

    private func persist() {
        ConfigStore.save(config)
    }

    private func persistAndNotify() {
        if suppressNotify { return }
        persist()
        onChange?()
    }
}
