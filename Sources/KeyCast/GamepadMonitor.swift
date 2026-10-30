import Foundation
import GameController

final class GamepadMonitor {
    var onChange: (([GamepadState]) -> Void)?
    var states: [GamepadState] = []
    var names: [String] = []

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        if #available(macOS 14.0, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(controllerChanged), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerChanged), name: .GCControllerDidDisconnect, object: nil)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func controllerChanged(_ n: Notification) {
        poll()
    }

    private func poll() {
        let controllers = GCController.controllers()
        var newStates: [GamepadState] = []
        var newNames: [String] = []
        for c in controllers {
            var s = GamepadState()
            s.connected = true
            s.layout = detectLayout(c)
            if let g = c.extendedGamepad {
                s.a = g.buttonA.isPressed
                s.b = g.buttonB.isPressed
                s.x = g.buttonX.isPressed
                s.y = g.buttonY.isPressed
                s.up = g.dpad.up.isPressed
                s.down = g.dpad.down.isPressed
                s.left = g.dpad.left.isPressed
                s.right = g.dpad.right.isPressed
                s.l1 = g.leftShoulder.isPressed
                s.r1 = g.rightShoulder.isPressed
                s.l3 = g.leftThumbstickButton?.isPressed ?? false
                s.r3 = g.rightThumbstickButton?.isPressed ?? false
                s.l2 = Double(g.leftTrigger.value)
                s.r2 = Double(g.rightTrigger.value)
                s.lx = Double(g.leftThumbstick.xAxis.value)
                s.ly = -Double(g.leftThumbstick.yAxis.value)
                s.rx = Double(g.rightThumbstick.xAxis.value)
                s.ry = -Double(g.rightThumbstick.yAxis.value)
                s.menu = g.buttonMenu.isPressed
                s.options = g.buttonOptions?.isPressed ?? false
                s.home = g.buttonHome?.isPressed ?? false
            }
            newStates.append(s)
            newNames.append(c.vendorName ?? "Gamepad")
        }
        states = newStates
        names = newNames
        onChange?(states)
    }

    private func detectLayout(_ c: GCController) -> String {
        let name = [c.vendorName, c.productCategory].compactMap { $0 }.joined(separator: " ")
        if name.localizedCaseInsensitiveContains("DualShock") || name.localizedCaseInsensitiveContains("DualSense") || name.localizedCaseInsensitiveContains("PlayStation") {
            return "ps"
        }
        if name.localizedCaseInsensitiveContains("Switch") || name.localizedCaseInsensitiveContains("Pro Controller") {
            return "switch"
        }
        return "xbox"
    }
}
