import Foundation

enum WidgetType: String, Codable, CaseIterable {
    case keycap
    case mouse
    case gamepad
    case gamepadButton
    case sequence
    case waterfall
    case displacement
    case wheel
    case text
}

struct Widget: Codable, Identifiable, Equatable {
    var id: UUID
    var type: WidgetType
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var keyCode: Int?
    var displayName: String?
    var gamepadButton: String?
    var gamepadFaceLayout: String?
    var gamepadDevice: Int?
    var label: String?
    var direction: String?
    var speed: Double?
    var dwell: Double?
    var sequenceCentered: Bool?
    var backgroundBrightness: Double?
    var backgroundBrightnessOn: Bool?
    var sensitivity: Double?
    var returnSpeed: Double?
    var fontSize: Double?
    var textAlign: String?
    var textColorHex: String?
    var waterfallRandom: Bool?
    var waterfallTrail: Bool?
    var waterfallAngle: Double?
    var waterfallFade: Bool?
    var waterfallRandomSize: Bool?
    var waterfallRandomSpeed: Bool?
    var waterfallSpeedMin: Double?
    var waterfallSpeedMax: Double?
    var waterfallRandomAngle: Bool?
    var waterfallAngleMin: Double?
    var waterfallAngleMax: Double?
    var opacity: Double?
}

extension WidgetType {
    var defaultSize: (w: Double, h: Double) {
        switch self {
        case .keycap: return (64, 64)
        case .mouse: return (84, 140)
        case .gamepad: return (360, 210)
        case .gamepadButton: return (64, 64)
        case .sequence: return (380, 64)
        case .waterfall: return (380, 240)
        case .displacement: return (140, 140)
        case .wheel: return (40, 160)
        case .text: return (240, 120)
        }
    }

    var title: String {
        switch self {
        case .keycap: return L("type.keycap")
        case .mouse: return L("type.mouse")
        case .gamepad: return L("type.gamepad")
        case .gamepadButton: return L("type.gamepadButton")
        case .sequence: return L("type.sequence")
        case .waterfall: return L("type.waterfall")
        case .displacement: return L("type.displacement")
        case .wheel: return L("type.wheel")
        case .text: return L("type.text")
        }
    }
}

enum MouseButton: Int, CaseIterable, Codable {
    case left = 0, right = 1, middle = 2, side1 = 3, side2 = 4
}

struct GamepadState: Equatable {
    var connected = false
    var layout = "xbox"
    var a = false, b = false, x = false, y = false
    var up = false, down = false, left = false, right = false
    var l1 = false, r1 = false, l3 = false, r3 = false
    var l2 = 0.0, r2 = 0.0
    var lx = 0.0, ly = 0.0, rx = 0.0, ry = 0.0
    var menu = false, options = false, home = false
}

struct Config: Codable {
    var widgets: [Widget] = []
    var gamepadLayout: String = "auto"
    var canvasSize: String = "full"
    var keycapShape: String = "rounded"
    var pressEffect: String = "simple"
    var keyOutEffect: String = "none"
    var opacity: Double = 1.0
    var scale: Double = 1.0
    var locked: Bool = true
    var overlayVisible: Bool = true
    var alwaysOnTop: Bool = true
    var showOverFullscreen: Bool = false
    var theme: String = "dark"
    var accentHex: String = "#4C8BF5"
    var overlayX: Double = 140
    var overlayY: Double = 140

    init() {}

    init(widgets: [Widget] = [], gamepadLayout: String = "auto", canvasSize: String = "full",
         keycapShape: String = "rounded", pressEffect: String = "simple", keyOutEffect: String = "none",
         opacity: Double = 1.0, scale: Double = 1.0, locked: Bool = true, overlayVisible: Bool = true, alwaysOnTop: Bool = true, showOverFullscreen: Bool = false,
         theme: String = "dark", accentHex: String = "#4C8BF5", overlayX: Double = 140, overlayY: Double = 140) {
        self.widgets = widgets
        self.gamepadLayout = gamepadLayout
        self.canvasSize = canvasSize
        self.keycapShape = keycapShape
        self.pressEffect = pressEffect
        self.keyOutEffect = keyOutEffect
        self.opacity = opacity
        self.scale = scale
        self.locked = locked
        self.overlayVisible = overlayVisible
        self.alwaysOnTop = alwaysOnTop
        self.showOverFullscreen = showOverFullscreen
        self.theme = theme
        self.accentHex = accentHex
        self.overlayX = overlayX
        self.overlayY = overlayY
    }

    enum CodingKeys: String, CodingKey {
        case widgets, gamepadLayout, canvasSize, keycapShape, pressEffect, keyOutEffect, opacity, scale, locked, overlayVisible, alwaysOnTop, showOverFullscreen, theme, accentHex, overlayX, overlayY
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        widgets = (try? c.decode([Widget].self, forKey: .widgets)) ?? []
        gamepadLayout = (try? c.decode(String.self, forKey: .gamepadLayout)) ?? "auto"
        canvasSize = (try? c.decode(String.self, forKey: .canvasSize)) ?? "full"
        keycapShape = (try? c.decode(String.self, forKey: .keycapShape)) ?? "rounded"
        pressEffect = (try? c.decode(String.self, forKey: .pressEffect)) ?? "simple"
        keyOutEffect = (try? c.decode(String.self, forKey: .keyOutEffect)) ?? "none"
        opacity = (try? c.decode(Double.self, forKey: .opacity)) ?? 1.0
        scale = (try? c.decode(Double.self, forKey: .scale)) ?? 1.0
        locked = (try? c.decode(Bool.self, forKey: .locked)) ?? true
        overlayVisible = (try? c.decode(Bool.self, forKey: .overlayVisible)) ?? true
        alwaysOnTop = (try? c.decode(Bool.self, forKey: .alwaysOnTop)) ?? true
        showOverFullscreen = (try? c.decode(Bool.self, forKey: .showOverFullscreen)) ?? false
        theme = (try? c.decode(String.self, forKey: .theme)) ?? "dark"
        accentHex = (try? c.decode(String.self, forKey: .accentHex)) ?? "#4C8BF5"
        overlayX = (try? c.decode(Double.self, forKey: .overlayX)) ?? 140
        overlayY = (try? c.decode(Double.self, forKey: .overlayY)) ?? 140
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(widgets, forKey: .widgets)
        try c.encode(gamepadLayout, forKey: .gamepadLayout)
        try c.encode(canvasSize, forKey: .canvasSize)
        try c.encode(keycapShape, forKey: .keycapShape)
        try c.encode(pressEffect, forKey: .pressEffect)
        try c.encode(keyOutEffect, forKey: .keyOutEffect)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(scale, forKey: .scale)
        try c.encode(locked, forKey: .locked)
        try c.encode(overlayVisible, forKey: .overlayVisible)
        try c.encode(alwaysOnTop, forKey: .alwaysOnTop)
        try c.encode(showOverFullscreen, forKey: .showOverFullscreen)
        try c.encode(theme, forKey: .theme)
        try c.encode(accentHex, forKey: .accentHex)
        try c.encode(overlayX, forKey: .overlayX)
        try c.encode(overlayY, forKey: .overlayY)
    }
}

extension Config {
    func sanitized() -> Config {
        var c = self
        for i in c.widgets.indices {
            if !c.widgets[i].x.isFinite || c.widgets[i].x < 0 || c.widgets[i].x > 100000 { c.widgets[i].x = 24 }
            if !c.widgets[i].y.isFinite || c.widgets[i].y < 0 || c.widgets[i].y > 100000 { c.widgets[i].y = 24 }
            if !c.widgets[i].w.isFinite || c.widgets[i].w < 24 { c.widgets[i].w = 64 }
            if !c.widgets[i].h.isFinite || c.widgets[i].h < 24 { c.widgets[i].h = 64 }
        }
        if !c.overlayX.isFinite || c.overlayX < -10000 || c.overlayX > 100000 { c.overlayX = 140 }
        if !c.overlayY.isFinite || c.overlayY < -10000 || c.overlayY > 100000 { c.overlayY = 140 }
        return c
    }
}
