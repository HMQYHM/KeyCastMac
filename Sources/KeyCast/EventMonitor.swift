import AppKit
import CoreGraphics

final class EventMonitor {
    var onKeyDown: ((Int, String) -> Void)?
    var onKeyUp: ((Int) -> Void)?
    var onModifiers: ((Set<Int>) -> Void)?
    var onMouse: ((MouseButton, Bool) -> Void)?
    var onMouseMove: ((Double, Double) -> Void)?
    var onScroll: ((Double) -> Void)?

    private var keyTap: CFMachPort?
    private var keySource: CFRunLoopSource?
    private var mouseTap: CFMachPort?
    private var mouseSource: CFRunLoopSource?

    var keyTapInstalled: Bool { keyTap != nil }
    var mouseTapInstalled: Bool { mouseTap != nil }

    func start() {
        _ = installKeyTap()
        _ = installMouseTap()
    }

    func stop() {
        if let keySource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), keySource, .commonModes) }
        if let mouseSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), mouseSource, .commonModes) }
        if let keyTap { CFMachPortInvalidate(keyTap) }
        if let mouseTap { CFMachPortInvalidate(mouseTap) }
        keyTap = nil; keySource = nil; mouseTap = nil; mouseSource = nil
    }

    @discardableResult
    func installKeyTap() -> Bool {
        guard keyTap == nil else { return true }
        let mask = bit(.keyDown) | bit(.keyUp) | bit(.flagsChanged)
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let s = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), s, .commonModes)
        keyTap = t
        keySource = s
        return true
    }

    @discardableResult
    func installMouseTap() -> Bool {
        guard mouseTap == nil else { return true }
        let mask = bit(.leftMouseDown) | bit(.leftMouseUp) |
            bit(.rightMouseDown) | bit(.rightMouseUp) |
            bit(.otherMouseDown) | bit(.otherMouseUp) |
            bit(.mouseMoved) | bit(.leftMouseDragged) | bit(.rightMouseDragged) | bit(.otherMouseDragged) |
            bit(.scrollWheel)
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let s = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), s, .commonModes)
        mouseTap = t
        mouseSource = s
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .keyDown:
                let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
                self.onKeyDown?(code, KeyNameResolver.name(forCode: code, event: event))
            case .keyUp:
                let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
                self.onKeyUp?(code)
            case .flagsChanged:
                var codes = Set<Int>()
                let f = event.flags
                if f.contains(.maskControl) { codes.insert(KeyCodes.control) }
                if f.contains(.maskShift) { codes.insert(KeyCodes.shift) }
                if f.contains(.maskAlternate) { codes.insert(KeyCodes.option) }
                if f.contains(.maskCommand) { codes.insert(KeyCodes.command) }
                self.onModifiers?(codes)
            case .leftMouseDown: self.onMouse?(.left, true)
            case .leftMouseUp: self.onMouse?(.left, false)
            case .rightMouseDown: self.onMouse?(.right, true)
            case .rightMouseUp: self.onMouse?(.right, false)
            case .otherMouseDown:
                self.onMouse?(Self.mouseButton(Int(event.getIntegerValueField(.mouseEventButtonNumber))), true)
            case .otherMouseUp:
                self.onMouse?(Self.mouseButton(Int(event.getIntegerValueField(.mouseEventButtonNumber))), false)
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                let dx = event.getDoubleValueField(.mouseEventDeltaX)
                let dy = event.getDoubleValueField(.mouseEventDeltaY)
                self.onMouseMove?(dx, dy)
            case .scrollWheel:
                self.onScroll?(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
            default: break
            }
        }
    }

    static func mouseButton(_ b: Int) -> MouseButton {
        switch b {
        case 2: return .middle
        case 3: return .side1
        case 4: return .side2
        default: return .middle
        }
    }
}

private func bit(_ type: CGEventType) -> CGEventMask {
    CGEventMask(1) << UInt64(type.rawValue)
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<EventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
