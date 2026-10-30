import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    let state = AppState()
    let monitor = EventMonitor()
    let gamepadMonitor = GamepadMonitor()
    var overlay: OverlayController!
    var onKeyForRecording: ((Int, String) -> Void)?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activityToken = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "保持输入监听响应")
        overlay = OverlayController()
        overlay.state = state
        state.onChange = { [weak self] in self?.overlay.syncConfig() }
        wireMonitor()
        gamepadMonitor.onChange = { [weak self] states in
            self?.overlay.noteGamepads(states)
            let names = self?.gamepadMonitor.names ?? []
            if self?.state.gamepadNames != names {
                self?.state.gamepadNames = names
            }
        }
        gamepadMonitor.start()
        buildMenu()
        buildStatusItem()
        overlay.syncConfig()
        showSettings(nil)

        DiagLog.log("launch pre-prompt: inputMonitoring=\(CGPreflightListenEventAccess()) accessibility=\(AXIsProcessTrusted())")

        requestPermissions()

        monitor.start()
        DiagLog.log("taps: keyTap=\(monitor.keyTapInstalled) mouseTap=\(monitor.mouseTapInstalled)")

        if !monitor.keyTapInstalled || !monitor.mouseTapInstalled {
            DispatchQueue.main.async { [weak self] in self?.showPermissionAlert() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ConfigStore.save(state.config)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func wireMonitor() {
        monitor.onKeyDown = { [weak self] code, name in
            guard let self else { return }
            if let rec = self.onKeyForRecording {
                self.onKeyForRecording = nil
                rec(code, name)
                return
            }
            self.overlay.noteKeyDown(code, name)
        }
        monitor.onKeyUp = { [weak self] code in
            guard let self else { return }
            self.overlay.noteKeyUp(code)
        }
        monitor.onModifiers = { [weak self] codes in
            guard let self else { return }
            self.overlay.noteModifiers(codes)
        }
        monitor.onMouse = { [weak self] b, down in
            guard let self else { return }
            self.overlay.noteMouseButton(b, down)
        }
        monitor.onMouseMove = { [weak self] dx, dy in
            guard let self else { return }
            self.overlay.noteMouseMove(dx, dy)
        }
        monitor.onScroll = { [weak self] d in
            guard let self else { return }
            self.overlay.noteScroll(d)
        }
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 键映", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "显示设置", action: #selector(showSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(withTitle: "重启应用", action: #selector(relaunch), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 键映", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "键映")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "设置", action: #selector(showSettings(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "显示 / 隐藏覆盖层", action: #selector(toggleOverlay(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "锁定 / 解锁覆盖层", action: #selector(toggleLock(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "重启应用", action: #selector(relaunch), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let root = SettingsView().environmentObject(state)
            let host = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: host)
            win.title = "键映 设置"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 1000, height: 640))
            win.isReleasedWhenClosed = false
            win.delegate = self
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        overlay.setOverlayHidden(false)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        overlay.setOverlayHidden(true)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        overlay.setOverlayHidden(false)
    }

    @objc func toggleSettingsFullscreen() {
        settingsWindow?.toggleFullScreen(nil)
    }

    @objc func toggleOverlay(_ sender: Any?) {
        state.overlayVisible = !state.overlayVisible
    }

    @objc func toggleLock(_ sender: Any?) {
        state.locked = !state.locked
    }

    @objc func relaunch() {
        DiagLog.log("relaunch requested")
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    func requestPermissions() {
        _ = CGRequestListenEventAccess()
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func permissionsGranted() -> Bool {
        CGPreflightListenEventAccess() && AXIsProcessTrusted()
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要系统权限"
        alert.informativeText = "键映 需要“输入监控”和“辅助功能”权限才能读取键盘与鼠标。请在系统设置中开启对应开关，然后点击菜单栏的“重启应用”。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            if !CGPreflightListenEventAccess(), let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(u)
            }
            if !AXIsProcessTrusted(), let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(u)
            }
        }
    }
}
