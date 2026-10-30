import AppKit

final class OverlayController: NSObject, NSWindowDelegate {
    let window: NSPanel
    let view: OverlayView
    weak var state: AppState?
    private var suppressPositionSave = false
    private var geometryTimer: Timer?
    private var lastContentSize: NSSize = .zero
    private var globalMonitor: Any?

    override init() {
        view = OverlayView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered,
                         defer: false)
        super.init()
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.contentView = view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary]
        window.title = "键映 Overlay"
        window.isReleasedWhenClosed = false
        window.delegate = self
        view.startAnimation()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel]) { [weak self] _ in
            self?.refreshMousePassThrough()
        }
    }

    func syncConfig() {
        guard let state else { return }
        view.widgets = state.widgets
        view.gamepadLayout = state.gamepadLayout
        view.canvasLogical = Canvas.size(for: state.canvasSize)
        view.keycapShape = state.keycapShape
        view.pressEffect = state.pressEffect
        view.keyOutEffect = state.keyOutEffect
        view.scale = state.scale
        view.globalBackgroundBrightness = state.globalBackgroundBrightness
        view.accent = Helpers.nsColor(hex: state.accentHex)
        window.alphaValue = state.opacity
        applyLevel()
        refreshMousePassThrough()
        view.needsDisplay = true

        if state.overlayVisible && !hiddenForEditing {
            if !window.isVisible {
                window.setIsVisible(true)
                window.orderFrontRegardless()
            }
        } else {
            if window.isVisible { window.setIsVisible(false) }
        }

        scheduleGeometryUpdate()
    }

    private func scheduleGeometryUpdate() {
        geometryTimer?.invalidate()
        let t = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in self?.applyGeometry() }
        RunLoop.main.add(t, forMode: .common)
        geometryTimer = t
    }

    private func applyGeometry() {
        guard let state else { return }
        let newSize = view.canvasSize
        if newSize == lastContentSize { return }
        lastContentSize = newSize
        suppressPositionSave = true
        window.setContentSize(newSize)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.minX + CGFloat(state.overlayX),
                             y: screen.maxY - CGFloat(state.overlayY) - newSize.height)
        window.setFrameOrigin(origin)
        suppressPositionSave = false
    }

    func noteKeyDown(_ code: Int, _ name: String) { view.noteKeyDown(code, name) }
    func noteKeyUp(_ code: Int) { view.noteKeyUp(code) }
    func noteModifiers(_ codes: Set<Int>) { view.noteModifiers(codes) }
    func noteMouseButton(_ b: MouseButton, _ down: Bool) { view.noteMouseButton(b, down) }
    func noteMouseMove(_ dx: Double, _ dy: Double) { view.noteMouseMove(dx, dy) }
    func noteScroll(_ d: Double) { view.noteScroll(d) }
    func noteGamepads(_ states: [GamepadState]) { view.noteGamepads(states) }

    func refreshMousePassThrough() {
        guard let state else { return }
        if state.locked {
            if !window.ignoresMouseEvents { window.ignoresMouseEvents = true }
            return
        }
        let box = view.keysBoundingBox
        let f = window.frame
        let m = NSEvent.mouseLocation
        let inside = box.width > 1 && box.height > 1 &&
            m.x >= f.minX + box.minX && m.x <= f.minX + box.maxX &&
            m.y >= f.maxY - box.maxY && m.y <= f.maxY - box.minY
        let want = !inside
        if window.ignoresMouseEvents != want {
            window.ignoresMouseEvents = want
        }
    }

    private var hiddenForEditing = false

    func setOverlayHidden(_ hidden: Bool) {
        hiddenForEditing = hidden
        if hidden {
            window.orderOut(nil)
        } else {
            applyLevel()
            if let state, state.overlayVisible { window.orderFrontRegardless() }
        }
    }

    private func applyLevel() {
        guard let state else { return }
        let newLevel: NSWindow.Level
        if state.showOverFullscreen {
            newLevel = .screenSaver
        } else if state.alwaysOnTop {
            newLevel = .statusBar
        } else {
            newLevel = .normal
        }
        if window.level != newLevel {
            window.level = newLevel
            if window.isVisible { window.orderFrontRegardless() }
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard !suppressPositionSave, let state else { return }
        let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = window.frame.origin
        state.overlayX = Double(origin.x - screen.minX)
        state.overlayY = Double(screen.maxY - (origin.y + window.frame.height))
    }
}

struct SequenceEntry {
    var name: String
    var time: CFTimeInterval
}

struct WaterfallBlock {
    var progress: CGFloat
    var lane: CGFloat
    var speed: CGFloat
    var length: CGFloat
    var size: CGFloat
    var color: NSColor
    var drift: CGFloat
    var trail: Bool
    var fade: Bool
    var name: String
}

final class OverlayView: NSView {
    var widgets: [Widget] = []
    var gamepadLayout: String = "xbox"
    var canvasLogical: CGSize = CGSize(width: 640, height: 360)
    var keycapShape: String = "rounded"
    var pressEffect: String = "simple"
    var keyOutEffect: String = "none"
    var scale: Double = 1
    var globalBackgroundBrightness: Double = 0.08
    var accent: NSColor = NSColor(calibratedRed: 0.3, green: 0.55, blue: 0.96, alpha: 1)

    private var pressedKeys: Set<Int> = []
    private var pressTimes: [Int: CFTimeInterval] = [:]
    private var releaseTimes: [Int: CFTimeInterval] = [:]
    private var pressedMouse: Set<MouseButton> = []
    var gamepads: [GamepadState] = []
    private var gamepad: GamepadState { gamepads.first ?? GamepadState() }
    private var dispOffset = CGPoint.zero
    private var wheelOffset: CGFloat = 0
    private var wheelDir: CGFloat = 0
    private var lastScrollTime: CFTimeInterval = 0
    private var sequenceEntries: [SequenceEntry] = []
    private var waterfallBlocks: [WaterfallBlock] = []

    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var keysBoundingBox: CGRect {
        guard !widgets.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for w in widgets {
            let r = widgetRect(w)
            minX = min(minX, r.minX)
            minY = min(minY, r.minY)
            maxX = max(maxX, r.maxX)
            maxY = max(maxY, r.maxY)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: nil)
        if keysBoundingBox.isEmpty || !keysBoundingBox.contains(p) { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if keysBoundingBox.contains(p) {
            window?.performDrag(with: event)
        }
    }

    func startAnimation() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var canvasSize: NSSize {
        let s = CGFloat(scale)
        var maxX = canvasLogical.width
        var maxY = canvasLogical.height
        for w in widgets {
            maxX = max(maxX, CGFloat(w.x + w.w))
            maxY = max(maxY, CGFloat(w.y + w.h))
        }
        return NSSize(width: (maxX + 8) * s, height: (maxY + 8) * s)
    }

    // MARK: - input

    func noteKeyDown(_ code: Int, _ name: String) {
        pressedKeys.insert(code)
        pressTimes[code] = CACurrentMediaTime()
        sequenceEntries.append(SequenceEntry(name: name, time: CACurrentMediaTime()))
        while sequenceEntries.count > 300 { sequenceEntries.removeFirst() }
        for w in widgets where w.type == .waterfall {
            spawnWaterfall(widget: w, code: code, name: name)
        }
        needsDisplay = true
    }

    func noteKeyUp(_ code: Int) {
        pressedKeys.remove(code)
        releaseTimes[code] = CACurrentMediaTime()
        needsDisplay = true
    }

    func noteModifiers(_ codes: Set<Int>) {
        for c in [KeyCodes.control, KeyCodes.shift, KeyCodes.option, KeyCodes.command] {
            if codes.contains(c) { pressedKeys.insert(c) } else { pressedKeys.remove(c) }
        }
        needsDisplay = true
    }

    func noteMouseButton(_ b: MouseButton, _ down: Bool) {
        if down {
            pressedMouse.insert(b)
            let name = mouseButtonName(b)
            sequenceEntries.append(SequenceEntry(name: name, time: CACurrentMediaTime()))
            while sequenceEntries.count > 300 { sequenceEntries.removeFirst() }
            for w in widgets where w.type == .waterfall {
                spawnWaterfall(widget: w, code: b.rawValue, name: name)
            }
        } else {
            pressedMouse.remove(b)
        }
        needsDisplay = true
    }

    private func mouseButtonName(_ b: MouseButton) -> String {
        switch b {
        case .left: return L("btn.left")
        case .right: return L("btn.right")
        case .middle: return L("btn.middle")
        case .side1: return L("btn.side1")
        case .side2: return L("btn.side2")
        }
    }

    func noteMouseMove(_ dx: Double, _ dy: Double) {
        guard widgets.contains(where: { $0.type == .displacement }) else { return }
        dispOffset.x = min(1, max(-1, dispOffset.x + CGFloat(dx) * 0.012))
        dispOffset.y = min(1, max(-1, dispOffset.y + CGFloat(dy) * 0.012))
        needsDisplay = true
    }

    func noteScroll(_ d: Double) {
        guard widgets.contains(where: { $0.type == .wheel }) else { return }
        wheelOffset = min(1, max(-1, wheelOffset + CGFloat(d) * 0.2))
        wheelDir = d > 0 ? 1 : -1
        lastScrollTime = CACurrentMediaTime()
        needsDisplay = true
    }

    func noteGamepads(_ states: [GamepadState]) {
        gamepads = states
        needsDisplay = true
    }

    // MARK: - animation

    private func spawnWaterfall(widget: Widget, code: Int, name: String) {
        let r = widgetRect(widget)
        let dir = widget.direction ?? "down"
        let sc = CGFloat(scale)
        let speed: CGFloat
        if widget.waterfallRandomSpeed ?? false {
            let mn = CGFloat(widget.waterfallSpeedMin ?? 60)
            let mx = max(mn, CGFloat(widget.waterfallSpeedMax ?? 320))
            speed = CGFloat.random(in: mn...mx) * sc
        } else {
            speed = CGFloat(widget.speed ?? 140) * sc
        }
        let length: CGFloat = (dir == "up" || dir == "down") ? r.height : r.width
        let random = widget.waterfallRandom ?? false
        let trail = widget.waterfallTrail ?? false
        let fade = widget.waterfallFade ?? false
        let lane = random ? CGFloat.random(in: 0...1) : CGFloat((code * 37) % 97) / 97.0
        let drift: CGFloat
        if widget.waterfallRandomAngle ?? false {
            let amin = CGFloat(widget.waterfallAngleMin ?? -45) * .pi / 180.0
            let amax = CGFloat(widget.waterfallAngleMax ?? 45) * .pi / 180.0
            let a = CGFloat.random(in: min(amin, amax)...max(amin, amax))
            drift = tan(a)
        } else {
            drift = 0
        }
        let size = (widget.waterfallRandomSize ?? false) ? CGFloat.random(in: 7...16) * sc : sc * 10
        waterfallBlocks.append(WaterfallBlock(progress: 0, lane: lane, speed: speed, length: max(length, 1), size: size, color: accent, drift: drift, trail: trail, fade: fade, name: name))
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTick)
        lastTick = now

        if !waterfallBlocks.isEmpty {
            for i in waterfallBlocks.indices {
                waterfallBlocks[i].progress += dt * waterfallBlocks[i].speed / waterfallBlocks[i].length
            }
            let countBefore = waterfallBlocks.count
            waterfallBlocks.removeAll { $0.progress > 1.0 }
            if waterfallBlocks.count != countBefore {
                needsDisplay = true
            }
        }

        let decay: CGFloat = 0.16
        dispOffset.x *= (1 - decay); dispOffset.y *= (1 - decay)
        if abs(dispOffset.x) < 0.01 { dispOffset.x = 0 }
        if abs(dispOffset.y) < 0.01 { dispOffset.y = 0 }
        wheelOffset *= (1 - decay)
        if abs(wheelOffset) < 0.01 { wheelOffset = 0 }

        if needsContinuousRedraw {
            needsDisplay = true
        }
    }

    private var needsContinuousRedraw: Bool {
        if !waterfallBlocks.isEmpty { return true }
        if abs(dispOffset.x) > 0.001 || abs(dispOffset.y) > 0.001 { return true }
        if abs(wheelOffset) > 0.001 { return true }
        if CACurrentMediaTime() - lastScrollTime < 0.5 { return true }
        if pressEffect != "simple" || keyOutEffect != "none" {
            let now = CACurrentMediaTime()
            if !pressedKeys.isEmpty { return true }
            for t in releaseTimes.values where now - t < 0.4 { return true }
        }
        return false
    }

    private func widgetRect(_ w: Widget) -> NSRect {
        let s = CGFloat(scale)
        return NSRect(x: CGFloat(w.x) * s, y: CGFloat(w.y) * s, width: CGFloat(w.w) * s, height: CGFloat(w.h) * s)
    }

    // MARK: - draw

    override func draw(_ dirtyRect: NSRect) {
        for w in widgets {
            switch w.type {
            case .keycap: drawKeycap(widget: w)
            case .mouse: drawMouseWidget(widget: w)
            case .gamepad: drawGamepadWidget(widget: w)
            case .gamepadButton: drawGamepadButtonWidget(widget: w)
            case .sequence: drawSequenceWidget(widget: w)
            case .waterfall: drawWaterfallWidget(widget: w)
            case .displacement: drawDisplacementWidget(widget: w)
            case .wheel: drawWheelWidget(widget: w)
            case .text: drawTextWidget(widget: w)
            }
        }
    }

    private func drawKeycap(widget: Widget) {
        let r = widgetRect(widget)
        let name = widget.displayName ?? "?"
        let code = widget.keyCode
        let pressed = code.map { pressedKeys.contains($0) } ?? false
        let progress = code.map { pressProgress($0, pressed: pressed) } ?? 0
        drawKey(r, title: name, pressed: pressed, s: CGFloat(scale), progress: progress, code: code)
    }

    private func pressProgress(_ code: Int, pressed: Bool) -> CGFloat {
        let now = CACurrentMediaTime()
        if pressed {
            let t = pressTimes[code] ?? now
            return min(1, CGFloat(now - t) / 0.12)
        } else {
            let t = releaseTimes[code] ?? 0
            return max(0, 1 - CGFloat(now - t) / 0.28)
        }
    }

    private func drawKey(_ r: NSRect, title: String, pressed: Bool, s: CGFloat, progress: CGFloat, code: Int?) {
        var scaleFactor: CGFloat = 1
        switch pressEffect {
        case "shrink": scaleFactor = 1 - 0.18 * progress
        case "pulse": scaleFactor = 1 + 0.10 * sin(progress * .pi * 3)
        case "bounce": scaleFactor = 1 + 0.22 * sin(progress * .pi) * (1 - progress)
        case "jelly": scaleFactor = 1 + 0.08 * sin(progress * .pi * 6) * (1 - progress)
        default: break
        }

        let sr = NSRect(x: r.midX - r.width / 2 * scaleFactor, y: r.midY - r.height / 2 * scaleFactor,
                        width: r.width * scaleFactor, height: r.height * scaleFactor)

        drawKeyOutEffect(r: sr, code: code, progress: progress, s: s)

        let path: NSBezierPath
        if keycapShape == "circle" {
            let d = min(sr.width, sr.height)
            path = NSBezierPath(ovalIn: NSRect(x: sr.midX - d / 2, y: sr.midY - d / 2, width: d, height: d))
        } else {
            path = NSBezierPath(roundedRect: sr.insetBy(dx: 1, dy: 1), xRadius: sr.height * 0.16, yRadius: sr.height * 0.16)
        }

        (pressed ? accent : NSColor(calibratedWhite: 0.14, alpha: 0.88)).setFill()
        path.fill()
        NSColor(calibratedWhite: 0.9, alpha: 0.9).setStroke()
        path.lineWidth = 1.5 * s
        path.stroke()
        drawText(title, sr, 15 * s * scaleFactor, color: pressed ? NSColor.white : NSColor(calibratedWhite: 0.96, alpha: 1))
    }

    private func drawKeyOutEffect(r: NSRect, code: Int?, progress: CGFloat, s: CGFloat) {
        guard let code, progress > 0.001 else { return }
        let now = CACurrentMediaTime()
        let pressT = pressTimes[code] ?? now
        let t = CGFloat(now - pressT)
        switch keyOutEffect {
        case "glow":
            let gr = r.insetBy(dx: -8 * s, dy: -8 * s)
            let gp = NSBezierPath(roundedRect: gr, xRadius: gr.height * 0.2, yRadius: gr.height * 0.2)
            accent.withAlphaComponent(0.35 * progress).setFill()
            gp.fill()
        case "ripple":
            let maxR = max(r.width, r.height) * 0.95
            let rr = min(maxR, t * 100 * s)
            let ring = NSBezierPath(ovalIn: NSRect(x: r.midX - rr, y: r.midY - rr, width: rr * 2, height: rr * 2))
            accent.withAlphaComponent(0.7 * max(0, 1 - t / 0.45)).setStroke()
            ring.lineWidth = 2.5 * s
            ring.stroke()
        case "spark":
            for i in 0..<6 {
                let ang = CGFloat(i) / 6.0 * .pi * 2 + 0.35
                let dist = t * 80 * s + 8 * s
                let pr = max(0, 3.5 * s * (1 - t / 0.45))
                if pr > 0 {
                    let px = r.midX + cos(ang) * dist
                    let py = r.midY + sin(ang) * dist
                    let dot = NSBezierPath(ovalIn: NSRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
                    accent.withAlphaComponent(0.9 * max(0, 1 - t / 0.45)).setFill()
                    dot.fill()
                }
            }
        default: break
        }
    }

    private func drawMouseWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)

        // body: rounded, tapered toward the front (top)
        let nose = r.width * 0.12
        let body = NSBezierPath()
        body.move(to: NSPoint(x: r.minX + nose, y: r.minY))
        body.curve(to: NSPoint(x: r.maxX - nose, y: r.minY),
                   controlPoint1: NSPoint(x: r.minX + r.width * 0.32, y: r.minY),
                   controlPoint2: NSPoint(x: r.maxX - r.width * 0.32, y: r.minY))
        body.curve(to: NSPoint(x: r.maxX, y: r.maxY),
                   controlPoint1: NSPoint(x: r.maxX, y: r.minY + r.height * 0.16),
                   controlPoint2: NSPoint(x: r.maxX, y: r.minY + r.height * 0.55))
        body.curve(to: NSPoint(x: r.minX, y: r.maxY),
                   controlPoint1: NSPoint(x: r.maxX - r.width * 0.55, y: r.maxY + r.height * 0.06),
                   controlPoint2: NSPoint(x: r.minX + r.width * 0.55, y: r.maxY + r.height * 0.06))
        body.curve(to: NSPoint(x: r.minX + nose, y: r.minY),
                   controlPoint1: NSPoint(x: r.minX, y: r.minY + r.height * 0.55),
                   controlPoint2: NSPoint(x: r.minX, y: r.minY + r.height * 0.16))
        body.close()
        NSColor(calibratedWhite: 0.13, alpha: 0.95).setFill()
        body.fill()
        NSColor(calibratedWhite: 0.75, alpha: 0.45).setStroke()
        body.lineWidth = 1 * s
        body.stroke()

        // left / right buttons + center split line
        let btnH = r.height * 0.50
        let btnW = (r.width - nose * 2) * 0.46
        let lBtn = NSBezierPath(roundedRect: NSRect(x: r.minX + nose, y: r.minY + 2 * s, width: btnW, height: btnH),
                                xRadius: r.width * 0.06, yRadius: r.width * 0.06)
        (pressedMouse.contains(.left) ? accent : NSColor(calibratedWhite: 0.26, alpha: 0.95)).setFill()
        lBtn.fill()
        let rBtn = NSBezierPath(roundedRect: NSRect(x: r.maxX - nose - btnW, y: r.minY + 2 * s, width: btnW, height: btnH),
                                xRadius: r.width * 0.06, yRadius: r.width * 0.06)
        (pressedMouse.contains(.right) ? accent : NSColor(calibratedWhite: 0.26, alpha: 0.95)).setFill()
        rBtn.fill()
        let split = NSBezierPath()
        split.move(to: NSPoint(x: r.midX, y: r.minY + 4 * s))
        split.line(to: NSPoint(x: r.midX, y: r.minY + btnH + 4 * s))
        split.lineWidth = 1 * s
        NSColor(calibratedWhite: 0.06, alpha: 0.7).setStroke()
        split.stroke()

        // scroll wheel (vertical capsule)
        let wr = NSRect(x: r.midX - r.width * 0.075, y: r.minY + r.height * 0.05, width: r.width * 0.15, height: r.height * 0.40)
        let wheel = NSBezierPath(roundedRect: wr, xRadius: wr.width * 0.5, yRadius: wr.width * 0.5)
        (pressedMouse.contains(.middle) ? accent : NSColor(calibratedWhite: 0.40, alpha: 1)).setFill()
        wheel.fill()
        NSColor(calibratedWhite: 0.10, alpha: 0.9).setStroke()
        wheel.lineWidth = 1 * s
        wheel.stroke()
        for i in 1...3 {
            let yy = wr.minY + wr.height * CGFloat(i) / 4.0
            let line = NSBezierPath()
            line.move(to: NSPoint(x: wr.minX + 2 * s, y: yy))
            line.line(to: NSPoint(x: wr.maxX - 2 * s, y: yy))
            line.lineWidth = 0.8 * s
            NSColor(calibratedWhite: 0.15, alpha: 0.8).setStroke()
            line.stroke()
        }

        let fade = 1 - min(1, CGFloat(CACurrentMediaTime() - lastScrollTime) / 0.5)
        if fade > 0, wheelDir != 0 {
            drawArrow(up: wheelDir > 0, center: NSPoint(x: wr.midX, y: wr.midY), size: wr.width * 0.6, active: true, alpha: fade, s: s)
        }

        // side buttons (left thumb area)
        let sw = r.width * 0.14
        let sh = r.height * 0.12
        let s1 = NSBezierPath(roundedRect: NSRect(x: r.minX + 1 * s, y: r.minY + r.height * 0.30, width: sw, height: sh),
                              xRadius: sw * 0.28, yRadius: sw * 0.28)
        (pressedMouse.contains(.side1) ? accent : NSColor(calibratedWhite: 0.34, alpha: 0.95)).setFill()
        s1.fill()
        let s2 = NSBezierPath(roundedRect: NSRect(x: r.minX + 1 * s, y: r.minY + r.height * 0.46, width: sw, height: sh),
                              xRadius: sw * 0.28, yRadius: sw * 0.28)
        (pressedMouse.contains(.side2) ? accent : NSColor(calibratedWhite: 0.34, alpha: 0.95)).setFill()
        s2.fill()
    }

    // MARK: gamepad

    private func resolvedLayout() -> String {
        if gamepadLayout == "auto" { return gamepad.layout }
        return gamepadLayout
    }

    private func faceLabels(_ layout: String) -> (bottom: String, right: String, left: String, top: String) {
        switch layout {
        case "ps": return ("×", "○", "□", "△")
        case "switch": return ("B", "A", "Y", "X")
        default: return ("A", "B", "X", "Y")
        }
    }

    private func shoulderLabels(_ layout: String) -> (lb: String, rb: String) {
        switch layout {
        case "ps": return ("L1", "R1")
        case "switch": return ("L", "R")
        default: return ("LB", "RB")
        }
    }

    private func drawGamepadWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        let g: GamepadState
        if let device = widget.gamepadDevice, device >= 0, device < gamepads.count {
            g = gamepads[device]
        } else {
            g = gamepad
        }

        let body = NSBezierPath()
        body.move(to: NSPoint(x: r.minX + r.width * 0.10, y: r.minY))
        body.line(to: NSPoint(x: r.maxX - r.width * 0.10, y: r.minY))
        body.curve(to: NSPoint(x: r.maxX, y: r.minY + r.height * 0.52),
                   controlPoint1: NSPoint(x: r.maxX, y: r.minY + r.height * 0.16),
                   controlPoint2: NSPoint(x: r.maxX, y: r.minY + r.height * 0.34))
        body.curve(to: NSPoint(x: r.maxX - r.width * 0.12, y: r.maxY),
                   controlPoint1: NSPoint(x: r.maxX, y: r.minY + r.height * 0.72),
                   controlPoint2: NSPoint(x: r.maxX - r.width * 0.04, y: r.maxY))
        body.line(to: NSPoint(x: r.minX + r.width * 0.12, y: r.maxY))
        body.curve(to: NSPoint(x: r.minX, y: r.minY + r.height * 0.52),
                   controlPoint1: NSPoint(x: r.minX + r.width * 0.04, y: r.maxY),
                   controlPoint2: NSPoint(x: r.minX, y: r.minY + r.height * 0.72))
        body.curve(to: NSPoint(x: r.minX + r.width * 0.10, y: r.minY),
                   controlPoint1: NSPoint(x: r.minX, y: r.minY + r.height * 0.34),
                   controlPoint2: NSPoint(x: r.minX, y: r.minY + r.height * 0.16))
        body.close()
        NSColor(calibratedWhite: 0.13, alpha: 0.9 * widgetBackgroundBrightness(widget)).setFill()
        body.fill()
        NSColor(calibratedWhite: 0.8, alpha: 0.8).setStroke()
        body.lineWidth = 1.5 * s
        body.stroke()

        let L = faceLabels(resolvedLayout())
        let sh = shoulderLabels(resolvedLayout())

        drawStick(NSPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.58), radius: r.height * 0.14,
                  dx: CGFloat(g.lx), dy: CGFloat(g.ly), pressed: g.l3, s: s)
        drawStick(NSPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.58), radius: r.height * 0.14,
                  dx: CGFloat(g.rx), dy: CGFloat(g.ry), pressed: g.r3, s: s)
        drawDpad(NSPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.34), radius: r.height * 0.11, s: s)
        drawFaceButtons(NSPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.34), radius: r.height * 0.09, labels: L, s: s)

        drawShoulder(NSRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.02, width: r.width * 0.24, height: r.height * 0.10), label: sh.lb, pressed: g.l1, s: s)
        drawShoulder(NSRect(x: r.minX + r.width * 0.66, y: r.minY + r.height * 0.02, width: r.width * 0.24, height: r.height * 0.10), label: sh.rb, pressed: g.r1, s: s)

        drawTrigger(NSRect(x: r.minX + r.width * 0.06, y: r.minY - r.height * 0.02, width: r.width * 0.18, height: r.height * 0.08), value: g.l2, s: s)
        drawTrigger(NSRect(x: r.minX + r.width * 0.76, y: r.minY - r.height * 0.02, width: r.width * 0.18, height: r.height * 0.08), value: g.r2, s: s)

        let layout = resolvedLayout()
        if layout == "ps" {
            let tp = NSBezierPath(roundedRect: NSRect(x: r.minX + r.width * 0.30, y: r.minY + r.height * 0.28, width: r.width * 0.40, height: r.height * 0.16), xRadius: r.width * 0.05, yRadius: r.height * 0.05)
            NSColor(calibratedWhite: 0.22, alpha: 0.9).setFill()
            tp.fill()
            NSColor(calibratedWhite: 0.65, alpha: 0.5).setStroke()
            tp.lineWidth = 1 * s
            tp.stroke()
            drawCenterButton(NSRect(x: r.minX + r.width * 0.33, y: r.minY + r.height * 0.50, width: r.width * 0.13, height: r.height * 0.07), label: "Share", pressed: g.options, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.54, y: r.minY + r.height * 0.50, width: r.width * 0.13, height: r.height * 0.07), label: "Options", pressed: g.menu, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.465, y: r.minY + r.height * 0.62, width: r.width * 0.07, height: r.height * 0.09), label: "PS", pressed: g.home, s: s)
        } else if layout == "switch" {
            drawCenterButton(NSRect(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.42, width: r.width * 0.09, height: r.height * 0.08), label: "-", pressed: g.options, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.53, y: r.minY + r.height * 0.42, width: r.width * 0.09, height: r.height * 0.08), label: "+", pressed: g.menu, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.43, y: r.minY + r.height * 0.56, width: r.width * 0.07, height: r.height * 0.09), label: "⌂", pressed: g.home, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.56, width: r.width * 0.07, height: r.height * 0.09), label: "◎", pressed: g.home, s: s)
        } else {
            drawCenterButton(NSRect(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.42, width: r.width * 0.09, height: r.height * 0.08), label: "☰", pressed: g.menu, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.53, y: r.minY + r.height * 0.42, width: r.width * 0.09, height: r.height * 0.08), label: "≡", pressed: g.options, s: s)
            drawCenterButton(NSRect(x: r.minX + r.width * 0.465, y: r.minY + r.height * 0.56, width: r.width * 0.07, height: r.height * 0.09), label: "⊞", pressed: g.home, s: s)
        }
    }

    private func gamepadButtonState(_ id: String, device: Int?) -> (pressed: Bool, value: Double) {
        let g: GamepadState
        if let device = device, device >= 0, device < gamepads.count {
            g = gamepads[device]
        } else {
            g = mergedGamepad()
        }
        switch id {
        case "a": return (g.a, g.a ? 1 : 0)
        case "b": return (g.b, g.b ? 1 : 0)
        case "x": return (g.x, g.x ? 1 : 0)
        case "y": return (g.y, g.y ? 1 : 0)
        case "up": return (g.up, g.up ? 1 : 0)
        case "down": return (g.down, g.down ? 1 : 0)
        case "left": return (g.left, g.left ? 1 : 0)
        case "right": return (g.right, g.right ? 1 : 0)
        case "l1": return (g.l1, g.l1 ? 1 : 0)
        case "r1": return (g.r1, g.r1 ? 1 : 0)
        case "l2": return (g.l2 > 0.15, g.l2)
        case "r2": return (g.r2 > 0.15, g.r2)
        case "l3": return (g.l3, g.l3 ? 1 : 0)
        case "r3": return (g.r3, g.r3 ? 1 : 0)
        case "menu": return (g.menu, g.menu ? 1 : 0)
        case "options": return (g.options, g.options ? 1 : 0)
        case "home": return (g.home, g.home ? 1 : 0)
        case "share": return (g.options, g.options ? 1 : 0)
        case "touchpad": return (g.menu, g.menu ? 1 : 0)
        case "plus": return (g.menu, g.menu ? 1 : 0)
        case "minus": return (g.options, g.options ? 1 : 0)
        case "capture": return (g.home, g.home ? 1 : 0)
        default: return (false, 0)
        }
    }

    private func widgetBackgroundBrightness(_ widget: Widget) -> CGFloat {
        if widget.backgroundBrightnessOn ?? false {
            return CGFloat(widget.backgroundBrightness ?? 1.0)
        }
        return CGFloat(globalBackgroundBrightness)
    }

    private func mergedGamepad() -> GamepadState {
        var m = GamepadState()
        for g in gamepads {
            m.a = m.a || g.a; m.b = m.b || g.b; m.x = m.x || g.x; m.y = m.y || g.y
            m.up = m.up || g.up; m.down = m.down || g.down; m.left = m.left || g.left; m.right = m.right || g.right
            m.l1 = m.l1 || g.l1; m.r1 = m.r1 || g.r1; m.l3 = m.l3 || g.l3; m.r3 = m.r3 || g.r3
            m.l2 = max(m.l2, g.l2); m.r2 = max(m.r2, g.r2)
            m.menu = m.menu || g.menu; m.options = m.options || g.options; m.home = m.home || g.home
            if !m.connected && g.connected { m.connected = true; m.layout = g.layout }
        }
        return m
    }

    private func drawGamepadButtonWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        let id = widget.gamepadButton ?? "a"

        if id == "dpad" {
            drawDpad(NSPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) * 0.38, s: s)
            return
        }
        if id == "face" {
            let fl = widget.gamepadFaceLayout ?? "auto"
            let layout = fl == "auto" ? resolvedLayout() : fl
            drawFaceButtons(NSPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) * 0.16, labels: faceLabels(layout), s: s)
            return
        }

        let label = widget.displayName ?? id.uppercased()
        let (pressed, value) = gamepadButtonState(id, device: widget.gamepadDevice)

        let path: NSBezierPath
        if keycapShape == "circle" {
            let d = min(r.width, r.height)
            path = NSBezierPath(ovalIn: NSRect(x: r.midX - d / 2, y: r.midY - d / 2, width: d, height: d))
        } else {
            path = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: r.height * 0.16, yRadius: r.height * 0.16)
        }
        if pressed || value > 0.02 {
            accent.withAlphaComponent(0.25 + 0.75 * CGFloat(value)).setFill()
        } else {
            NSColor(calibratedWhite: 0.14, alpha: 0.88).setFill()
        }
        path.fill()
        NSColor(calibratedWhite: 0.9, alpha: 0.9).setStroke()
        path.lineWidth = 1.5 * s
        path.stroke()
        drawText(label, r, 15 * s, color: pressed ? NSColor.white : NSColor(calibratedWhite: 0.96, alpha: 1))
    }

    private func drawStick(_ c: NSPoint, radius: CGFloat, dx: CGFloat, dy: CGFloat, pressed: Bool, s: CGFloat) {
        let o = NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
        (pressed ? accent : NSColor(calibratedWhite: 0.22, alpha: 0.9)).setFill()
        o.fill()
        NSColor(calibratedWhite: 0.7, alpha: 0.8).setStroke()
        o.lineWidth = 1 * s
        o.stroke()
        let knob = radius * 0.5
        let kx = c.x + dx * radius * 0.5
        let ky = c.y + dy * radius * 0.5
        let k = NSBezierPath(ovalIn: NSRect(x: kx - knob, y: ky - knob, width: knob * 2, height: knob * 2))
        NSColor(calibratedWhite: 0.85, alpha: 0.9).setFill()
        k.fill()
    }

    private func drawDpad(_ c: NSPoint, radius: CGFloat, s: CGFloat) {
        let g = gamepad
        let th = radius * 0.8
        let len = radius
        drawDpadArm(NSRect(x: c.x - th / 2, y: c.y - len, width: th, height: len), g.up, s)
        drawDpadArm(NSRect(x: c.x - th / 2, y: c.y, width: th, height: len), g.down, s)
        drawDpadArm(NSRect(x: c.x - len, y: c.y - th / 2, width: len, height: th), g.left, s)
        drawDpadArm(NSRect(x: c.x, y: c.y - th / 2, width: len, height: th), g.right, s)
    }

    private func drawDpadArm(_ r: NSRect, _ pressed: Bool, _ s: CGFloat) {
        let p = NSBezierPath(roundedRect: r, xRadius: 2, yRadius: 2)
        (pressed ? accent : NSColor(calibratedWhite: 0.3, alpha: 0.9)).setFill()
        p.fill()
    }

    private func drawFaceButtons(_ c: NSPoint, radius: CGFloat, labels: (bottom: String, right: String, left: String, top: String), s: CGFloat) {
        let g = gamepad
        let off = radius * 1.3
        drawFaceButton(NSPoint(x: c.x, y: c.y + off), radius, labels.bottom, g.a, faceColor(0), s)
        drawFaceButton(NSPoint(x: c.x + off, y: c.y), radius, labels.right, g.b, faceColor(1), s)
        drawFaceButton(NSPoint(x: c.x - off, y: c.y), radius, labels.left, g.x, faceColor(2), s)
        drawFaceButton(NSPoint(x: c.x, y: c.y - off), radius, labels.top, g.y, faceColor(3), s)
    }

    private func faceColor(_ i: Int) -> NSColor {
        switch i {
        case 0: return NSColor(calibratedRed: 0.18, green: 0.65, blue: 0.26, alpha: 0.92)
        case 1: return NSColor(calibratedRed: 0.88, green: 0.24, blue: 0.19, alpha: 0.92)
        case 2: return NSColor(calibratedRed: 0.23, green: 0.47, blue: 0.85, alpha: 0.92)
        default: return NSColor(calibratedRed: 0.91, green: 0.76, blue: 0.23, alpha: 0.92)
        }
    }

    private func drawFaceButton(_ c: NSPoint, _ r: CGFloat, _ label: String, _ pressed: Bool, _ resting: NSColor, _ s: CGFloat) {
        let o = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        (pressed ? accent : resting).setFill()
        o.fill()
        NSColor(calibratedWhite: 0.15, alpha: 0.9).setStroke()
        o.lineWidth = 1 * s
        o.stroke()
        drawText(label, NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), r * 1.1, color: .white)
    }

    private func drawShoulder(_ r: NSRect, label: String, pressed: Bool, s: CGFloat) {
        let p = NSBezierPath(roundedRect: r, xRadius: r.height * 0.4, yRadius: r.height * 0.4)
        (pressed ? accent : NSColor(calibratedWhite: 0.28, alpha: 0.9)).setFill()
        p.fill()
        drawText(label, r, r.height * 0.5, color: .white)
    }

    private func drawTrigger(_ r: NSRect, value: Double, s: CGFloat) {
        let p = NSBezierPath(roundedRect: r, xRadius: r.height * 0.3, yRadius: r.height * 0.3)
        accent.withAlphaComponent(0.25 + CGFloat(value) * 0.75).setFill()
        p.fill()
        NSColor(calibratedWhite: 0.6, alpha: 0.8).setStroke()
        p.lineWidth = 1 * s
        p.stroke()
    }

    private func drawCenterButton(_ r: NSRect, label: String, pressed: Bool, s: CGFloat) {
        let p = NSBezierPath(ovalIn: r)
        (pressed ? accent : NSColor(calibratedWhite: 0.35, alpha: 0.9)).setFill()
        p.fill()
        drawText(label, r, 7 * s, color: .white)
    }

    // MARK: sequence

    private func drawSequenceWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        drawRoundedFill(r, NSColor(calibratedWhite: 0.08, alpha: 0.3 * widgetBackgroundBrightness(widget)), radius: 8 * s)
        let now = CACurrentMediaTime()
        let dwell = CGFloat(widget.dwell ?? 3.0)
        let entries = Array(sequenceEntries.filter { now - $0.time < dwell }.reversed())
        let dir = widget.direction ?? "h"
        let fontSize = min(100, max(8, CGFloat(widget.fontSize ?? 14))) * s
        let lineH = fontSize * 1.4
        let gap = fontSize * 0.45
        let pad = 6 * s
        let textColor = Helpers.nsColor(hex: widget.textColorHex ?? "#FFFFFF")
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize), .foregroundColor: textColor]

        let items: [(String, CGFloat)] = entries.map { e in
            let w = (e.name as NSString).size(withAttributes: attrs).width
            return (e.name, w)
        }
        let availW = r.width - 2 * pad
        let availH = r.height - 2 * pad

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: r.insetBy(dx: 1, dy: 1)).setClip()
        func draw(_ str: String, _ rect: NSRect) {
            (str as NSString).draw(in: rect, withAttributes: attrs)
        }

        if widget.sequenceCentered ?? false {
            // centered layout
            if dir == "v" || dir == "vr" {
                var columns: [[(String, CGFloat)]] = [[]]
                var curH: CGFloat = 0
                for it in items {
                    if curH + lineH > availH && !columns[columns.count - 1].isEmpty {
                        columns.append([])
                        curH = 0
                    }
                    columns[columns.count - 1].append(it)
                    curH += lineH + gap
                }
                let colW = columns.compactMap { col in col.map { $0.1 }.max() }.max() ?? 0
                let blockW = CGFloat(columns.count) * (colW + gap) - gap
                let blockH = min(availH, columns.map { CGFloat($0.count) * (lineH + gap) - gap }.max() ?? 0)
                let ox = r.minX + pad + (availW - blockW) / 2
                let oy = r.minY + pad + (availH - blockH) / 2
                var cx = ox
                for col in columns {
                    var cy = (dir == "vr") ? oy : (oy + blockH - lineH)
                    for it in col {
                        let y = (dir == "vr") ? cy : (cy - lineH)
                        draw(it.0, NSRect(x: cx, y: y, width: it.1, height: lineH))
                        if dir == "vr" { cy += lineH + gap } else { cy -= lineH + gap }
                    }
                    cx += colW + gap
                }
            } else {
                var lines: [[(String, CGFloat)]] = [[]]
                var curW: CGFloat = 0
                for it in items {
                    if curW + it.1 > availW && !lines[lines.count - 1].isEmpty {
                        lines.append([])
                        curW = 0
                    }
                    lines[lines.count - 1].append(it)
                    curW += it.1 + gap
                }
                let lineWMax = lines.map { line in line.reduce(0) { $0 + $1.1 + gap } - gap }.max() ?? 0
                let blockW = min(availW, lineWMax)
                let blockH = CGFloat(lines.count) * (lineH + gap) - gap
                let ox = r.minX + pad + (availW - blockW) / 2
                let oy = r.minY + pad + (availH - blockH) / 2
                var ly = oy
                for line in lines {
                    let lineW = line.reduce(0) { $0 + $1.1 + gap } - gap
                    var cx: CGFloat
                    if dir == "hr" {
                        cx = ox + blockW
                        for it in line {
                            draw(it.0, NSRect(x: cx - it.1, y: ly, width: it.1, height: lineH))
                            cx -= it.1 + gap
                        }
                    } else {
                        cx = ox
                        for it in line {
                            draw(it.0, NSRect(x: cx, y: ly, width: it.1, height: lineH))
                            cx += it.1 + gap
                        }
                    }
                    ly += lineH + gap
                }
            }
        } else {
            // corner-based layout
            let minX = r.minX + pad, maxX = r.maxX - pad
            let minY = r.minY + pad, maxY = r.maxY - pad
            switch dir {
            case "hr":
                var cx = minX, cy = minY
                for it in items {
                    if cx + it.1 > maxX { cx = minX; cy += lineH; if cy + lineH > maxY { break } }
                    draw(it.0, NSRect(x: cx, y: cy, width: it.1, height: lineH))
                    cx += it.1 + gap
                }
            case "v":
                var cx = minX, cy = maxY, colW: CGFloat = 0
                for it in items {
                    if cy - lineH < minY { cx += colW + gap; cy = maxY; colW = 0; if cx > maxX { break } }
                    draw(it.0, NSRect(x: cx, y: cy - lineH, width: it.1, height: lineH))
                    cy -= lineH + gap
                    colW = max(colW, it.1)
                }
            case "vr":
                var cx = minX, cy = minY, colW: CGFloat = 0
                for it in items {
                    if cy + lineH > maxY { cx += colW + gap; cy = minY; colW = 0; if cx > maxX { break } }
                    draw(it.0, NSRect(x: cx, y: cy, width: it.1, height: lineH))
                    cy += lineH + gap
                    colW = max(colW, it.1)
                }
            default:
                var cx = maxX, cy = minY
                for it in items {
                    if cx - it.1 < minX { cx = maxX; cy += lineH; if cy + lineH > maxY { break } }
                    draw(it.0, NSRect(x: cx - it.1, y: cy, width: it.1, height: lineH))
                    cx -= it.1 + gap
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMiniKeycap(_ r: NSRect, _ title: String, _ s: CGFloat) {
        let path = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: r.height * 0.18, yRadius: r.height * 0.18)
        NSColor(calibratedWhite: 0.16, alpha: 0.9).setFill()
        path.fill()
        NSColor(calibratedWhite: 0.85, alpha: 0.8).setStroke()
        path.lineWidth = 1 * s
        path.stroke()
        drawText(title, r, 12 * s, color: .white)
    }

    // MARK: waterfall

    private func waterfallPosition(_ b: WaterfallBlock, _ r: NSRect, _ dir: String, _ progress: CGFloat) -> NSPoint {
        switch dir {
        case "up": return NSPoint(x: r.minX + b.lane * r.width + b.drift * progress * r.height, y: r.maxY - progress * r.height)
        case "left": return NSPoint(x: r.maxX - progress * r.width, y: r.minY + b.lane * r.height + b.drift * progress * r.width)
        case "right": return NSPoint(x: r.minX + progress * r.width, y: r.minY + b.lane * r.height + b.drift * progress * r.width)
        default: return NSPoint(x: r.minX + b.lane * r.width + b.drift * progress * r.height, y: r.minY + progress * r.height)
        }
    }

    private func drawWaterfallWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        let op = CGFloat(widget.opacity ?? 1.0)
        drawRoundedFill(r, NSColor(calibratedWhite: 0.04, alpha: 0.25 * widgetBackgroundBrightness(widget)), radius: 8 * s)
        let dir = widget.direction ?? "down"

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: r.insetBy(dx: 1, dy: 1)).setClip()
        for b in waterfallBlocks {
            let fadeAlpha: CGFloat = b.fade ? min(1, max(0, (1 - b.progress) / 0.45)) : 1
            let pos = waterfallPosition(b, r, dir, b.progress)
            let headSize = b.size * 1.7
            let dirVec = movementDirection(dir, drift: b.drift)

            if b.trail {
                drawMeteorTail(pos: pos, dirVec: dirVec, headSize: headSize, color: b.color, alpha: fadeAlpha)
            }

            let headRect = NSRect(x: pos.x - headSize / 2, y: pos.y - headSize / 2, width: headSize, height: headSize)
            let headPath = NSBezierPath(roundedRect: headRect, xRadius: headSize * 0.25, yRadius: headSize * 0.25)
            b.color.withAlphaComponent(fadeAlpha).setFill()
            headPath.fill()
            NSColor(calibratedWhite: 0.95, alpha: 0.85).setStroke()
            headPath.lineWidth = 1 * s
            headPath.stroke()
            drawText(b.name, headRect, headSize * 0.45, color: .white)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func movementDirection(_ dir: String, drift: CGFloat) -> NSPoint {
        switch dir {
        case "up": return NSPoint(x: drift, y: -1)
        case "left": return NSPoint(x: -1, y: drift)
        case "right": return NSPoint(x: 1, y: drift)
        default: return NSPoint(x: drift, y: 1)
        }
    }

    private func drawMeteorTail(pos: NSPoint, dirVec: NSPoint, headSize: CGFloat, color: NSColor, alpha: CGFloat) {
        let len = max(hypot(dirVec.x, dirVec.y), 0.001)
        let d = NSPoint(x: dirVec.x / len, y: dirVec.y / len)
        let perp = NSPoint(x: -d.y, y: d.x)
        let halfW = headSize * 0.5
        let tailLen = headSize * 4

        var end = NSPoint(x: pos.x - d.x * tailLen, y: pos.y - d.y * tailLen)
        var path = NSBezierPath()
        path.move(to: NSPoint(x: pos.x + perp.x * halfW, y: pos.y + perp.y * halfW))
        path.line(to: NSPoint(x: pos.x - perp.x * halfW, y: pos.y - perp.y * halfW))
        path.line(to: end)
        path.close()
        color.withAlphaComponent(alpha * 0.30).setFill()
        path.fill()

        end = NSPoint(x: pos.x - d.x * tailLen * 0.45, y: pos.y - d.y * tailLen * 0.45)
        let innerHalfW = halfW * 0.65
        path = NSBezierPath()
        path.move(to: NSPoint(x: pos.x + perp.x * innerHalfW, y: pos.y + perp.y * innerHalfW))
        path.line(to: NSPoint(x: pos.x - perp.x * innerHalfW, y: pos.y - perp.y * innerHalfW))
        path.line(to: end)
        path.close()
        color.withAlphaComponent(alpha * 0.50).setFill()
        path.fill()
    }

    // MARK: displacement / wheel

    private func drawDisplacementWidget(widget: Widget) {
        let r = widgetRect(widget)
        let c = NSPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) / 2 - 4
        let outer = NSBezierPath(ovalIn: NSRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
        NSColor(calibratedWhite: 0.2, alpha: 0.6).setFill()
        outer.fill()
        let dotR = rad * 0.18
        let dx = c.x + dispOffset.x * rad * 0.7
        let dy = c.y + dispOffset.y * rad * 0.7
        let dot = NSBezierPath(ovalIn: NSRect(x: dx - dotR, y: dy - dotR, width: dotR * 2, height: dotR * 2))
        accent.setFill()
        dot.fill()
    }

    private func drawWheelWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        let track = NSBezierPath(roundedRect: r.insetBy(dx: r.width * 0.35, dy: 4), xRadius: r.width * 0.15, yRadius: r.width * 0.15)
        NSColor(calibratedWhite: 0.2, alpha: 0.6).setFill()
        track.fill()
        let thumbH = r.height * 0.25
        let ty = r.midY + wheelOffset * (r.height / 2 - thumbH / 2) - thumbH / 2
        let thumb = NSBezierPath(roundedRect: NSRect(x: r.minX + r.width * 0.32, y: ty, width: r.width * 0.36, height: thumbH), xRadius: r.width * 0.1, yRadius: r.width * 0.1)
        accent.setFill()
        thumb.fill()

        let now = CACurrentMediaTime()
        let fade = 1 - min(1, CGFloat(now - lastScrollTime) / 0.5)
        if fade > 0, wheelDir != 0 {
            let aSize = r.width * 0.34
            drawArrow(up: true, center: NSPoint(x: r.midX, y: r.minY - aSize * 0.6), size: aSize, active: wheelDir > 0, alpha: fade, s: s)
            drawArrow(up: false, center: NSPoint(x: r.midX, y: r.maxY + aSize * 0.6), size: aSize, active: wheelDir < 0, alpha: fade, s: s)
        }
    }

    private func drawArrow(up: Bool, center: NSPoint, size: CGFloat, active: Bool, alpha: CGFloat, s: CGFloat) {
        let path = NSBezierPath()
        let hw = size * 0.5
        let hh = size * 0.35
        if up {
            path.move(to: NSPoint(x: center.x, y: center.y - hh))
            path.line(to: NSPoint(x: center.x - hw, y: center.y + hh))
            path.line(to: NSPoint(x: center.x + hw, y: center.y + hh))
        } else {
            path.move(to: NSPoint(x: center.x, y: center.y + hh))
            path.line(to: NSPoint(x: center.x - hw, y: center.y - hh))
            path.line(to: NSPoint(x: center.x + hw, y: center.y - hh))
        }
        path.close()
        (active ? accent : NSColor(calibratedWhite: 0.7, alpha: 1)).withAlphaComponent(alpha).setFill()
        path.fill()
    }

    // MARK: text

    private func drawTextWidget(widget: Widget) {
        let r = widgetRect(widget)
        let s = CGFloat(scale)
        let text = widget.label ?? "文本"
        let fontSize = CGFloat(widget.fontSize ?? 24) * s
        let color = Helpers.nsColor(hex: widget.textColorHex ?? "#FFFFFF")
        let align = widget.textAlign ?? "left"

        let paragraph = NSMutableParagraphStyle()
        switch align {
        case "center": paragraph.alignment = .center
        case "right": paragraph.alignment = .right
        default: paragraph.alignment = .left
        }
        paragraph.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let bounding = NSRect(x: r.minX + 6 * s, y: r.minY + 6 * s, width: r.width - 12 * s, height: r.height - 12 * s)
        str.draw(with: bounding, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    // MARK: - helpers

    private func drawRoundedFill(_ r: NSRect, _ color: NSColor, radius: CGFloat) {
        let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
        color.setFill()
        p.fill()
    }

    private func drawText(_ s: String, _ r: NSRect, _ fontSize: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: r.midX - sz.width / 2, y: r.midY - sz.height / 2))
    }
}
