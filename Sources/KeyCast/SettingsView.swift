import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

struct AccentPreset: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
}

struct Guide: Identifiable {
    let id = UUID()
    let isVertical: Bool
    let position: CGFloat
}

final class HoverState {
    var hoveredID: UUID?
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var editWidgets: [Widget] = []
    @State private var selectedID: UUID?
    @State private var isRecordingKey = false
    @State private var snapEnabled = true
    @State private var copiedWidget: Widget?
    @State private var isFullscreen = false

    private let grid: CGFloat = 8

    var body: some View {
        Group {
            if isFullscreen {
                FullscreenCanvasView(snapEnabled: $snapEnabled)
            } else {
                HStack(spacing: 14) {
            // LEFT: canvas + add buttons + global settings
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(L("ui.canvas"), systemImage: "square.grid.3x3")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        addButton(L("ui.undo")) { performUndo() }
                        addButton(L("ui.clear")) { clearAll() }
                        addButton(L("ui.fullscreen")) { AppDelegate.shared.toggleSettingsFullscreen() }
                        Toggle(L("ui.snap"), isOn: $snapEnabled).controlSize(.small)
                    }
                    CanvasPanel(widgets: $editWidgets, selectedID: $selectedID, grid: grid,
                                accentHex: state.accentHex, snapEnabled: snapEnabled,
                                canvasSize: Canvas.size(for: state.canvasSize),
                                onCommit: commitWidgets, onDelete: deleteSelected,
                                onUndo: performUndo, onRedo: performRedo,
                                onCopy: copySelected, onCut: cutSelected, onPaste: pasteWidget,
                                onNudge: { dx, dy in nudgeSelected(dx, dy) })
                        .frame(maxWidth: .infinity)
                        .aspectRatio(canvasAspect, contentMode: .fit)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        addIconButton("keyboard", L("ui.addKey")) { isRecordingKey = true }
                        Menu {
                            ForEach(KeyboardPresets.all, id: \.name) { p in
                                Button(p.name) { addPreset(p) }
                            }
                        } label: {
                            Label(L("ui.presets"), systemImage: "keyboard.badge.ellipsis")
                        }
                        .menuStyle(.button)
                        .controlSize(.small)
                        .fixedSize()
                        Menu {
                            Button("整块手柄") { addWidget(type: .gamepad) }
                            Divider()
                            ForEach(gamepadButtonDefs, id: \.id) { def in
                                Button(def.label) { addGamepadButton(def.id, def.label) }
                            }
                        } label: {
                            Label(L("ui.gamepad"), systemImage: "gamecontroller")
                        }
                        .menuStyle(.button)
                        .controlSize(.small)
                        .fixedSize()
                        ForEach(nonKeycapTypes, id: \.self) { t in
                            addIconButton(typeIcon(t), t.title) { addWidget(type: t) }
                        }
                    }
                }

                GlobalSettingsView(onProfileLoaded: { editWidgets = state.widgets })
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                widgetListSection()
                if let idx = selectedIndex {
                    editor(idx: idx)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 320)
                }
                .padding(16)
                .frame(minWidth: 1040, minHeight: 600)
            }
        }
        .onAppear { editWidgets = state.widgets }
        .onChange(of: state.widgets) { newValue in editWidgets = newValue }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in isFullscreen = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in isFullscreen = false }
        .sheet(isPresented: $isRecordingKey) {
            KeyRecorderView(
                onCapture: { code, name in
                    addWidget(type: .keycap, keyCode: code, name: name)
                    isRecordingKey = false
                },
                onCancel: { isRecordingKey = false }
            )
        }
    }

    private var canvasAspect: CGFloat {
        let cs = Canvas.size(for: state.canvasSize)
        return cs.width / max(cs.height, 1)
    }

    private let gamepadButtonDefs: [(id: String, label: String)] = [
        ("dpad", "方向键"), ("face", "ABXY"),
        ("l1", "L1"), ("r1", "R1"), ("l2", "L2"), ("r2", "R2"),
        ("l3", "L3"), ("r3", "R3"),
        ("menu", "菜单"), ("options", "选项"), ("home", "Home"),
        ("share", "Share"), ("touchpad", "触摸板"), ("plus", "+"), ("minus", "-"), ("capture", "截图")
    ]

    private let allGamepadButtons: [(id: String, label: String)] = [
        ("a", "A"), ("b", "B"), ("x", "X"), ("y", "Y"),
        ("up", "↑"), ("down", "↓"), ("left", "←"), ("right", "→"),
        ("l1", "L1"), ("r1", "R1"), ("l2", "L2"), ("r2", "R2"),
        ("l3", "L3"), ("r3", "R3"),
        ("menu", "菜单"), ("options", "选项"), ("home", "Home"),
        ("share", "Share"), ("touchpad", "触摸板"), ("plus", "+"), ("minus", "-"), ("capture", "截图")
    ]

    private func addPreset(_ p: KeyboardPreset) {
        let maxY = editWidgets.map { $0.y + $0.h }.max() ?? 0
        let newWidgets = p.makeWidgets(originX: 8, originY: maxY + 16)
        editWidgets.append(contentsOf: newWidgets)
        selectedID = newWidgets.first?.id
        commitWidgets()
    }

    private func addGamepadButton(_ id: String, _ label: String) {
        let o = nextOrigin()
        let sz = (id == "dpad" || id == "face") ? (140.0, 140.0) : (64.0, 64.0)
        var w = Widget(id: UUID(), type: .gamepadButton, x: o.x, y: o.y, w: sz.0, h: sz.1, keyCode: nil, displayName: label)
        w.gamepadButton = id
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private var nonKeycapTypes: [WidgetType] {
        WidgetType.allCases.filter { $0 != .keycap && $0 != .gamepadButton && $0 != .gamepad }
    }

    private var selectedIndex: Int? {
        selectedID.flatMap { id in editWidgets.firstIndex(where: { $0.id == id }) }
    }

    private func addButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func addIconButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func typeIcon(_ t: WidgetType) -> String {
        switch t {
        case .keycap: return "keyboard"
        case .mouse: return "cursorarrow"
        case .gamepad, .gamepadButton: return "gamecontroller"
        case .sequence: return "list.bullet"
        case .waterfall: return "drop"
        case .displacement: return "scope"
        case .wheel: return "dial"
        case .text: return "text.alignleft"
        }
    }

    private func nextOrigin() -> (x: Double, y: Double) {
        let n = editWidgets.count
        return (24 + Double(n % 5) * 96, 24 + Double(n / 5) * 96)
    }

    private func addWidget(type: WidgetType, keyCode: Int? = nil, name: String? = nil) {
        let sz = type.defaultSize
        let o = nextOrigin()
        var w = Widget(id: UUID(), type: type, x: o.x, y: o.y, w: sz.w, h: sz.h, keyCode: keyCode, displayName: name)
        switch type {
        case .waterfall: w.direction = "down"; w.speed = 140
        case .sequence: w.direction = "h"; w.dwell = 3
        default: break
        }
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private func commitWidgets() {
        if editWidgets != state.widgets {
            state.recordUndo(oldWidgets: state.widgets)
            state.widgets = editWidgets
        }
    }

    private func performUndo() {
        if state.undo() {
            editWidgets = state.widgets
        }
    }

    private func performRedo() {
        if state.redo() {
            editWidgets = state.widgets
        }
    }

    private func clearAll() {
        editWidgets.removeAll()
        selectedID = nil
        commitWidgets()
    }

    private func deleteSelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        editWidgets.remove(at: idx)
        selectedID = nil
        commitWidgets()
    }

    private func copySelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        var w = editWidgets[idx]
        w.id = UUID()
        copiedWidget = w
    }

    private func cutSelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        var w = editWidgets[idx]
        w.id = UUID()
        copiedWidget = w
        editWidgets.remove(at: idx)
        selectedID = nil
        commitWidgets()
    }

    private func pasteWidget() {
        guard var w = copiedWidget else { return }
        w.id = UUID()
        w.x += Double(grid) * 2
        w.y += Double(grid) * 2
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private func nudgeSelected(_ dx: Double, _ dy: Double) {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        editWidgets[idx].x = max(0, min(100000, editWidgets[idx].x + dx))
        editWidgets[idx].y = max(0, min(100000, editWidgets[idx].y + dy))
        commitWidgets()
    }

    private func duplicateSelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        var w = editWidgets[idx]
        w.id = UUID()
        w.x += Double(grid) * 2
        w.y += Double(grid) * 2
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private func widgetListSection() -> some View {
        SectionCard(icon: "list.bullet", title: L("ui.widgetList") + " \(editWidgets.count)") {
            if editWidgets.isEmpty {
                Text("暂无按键，点左侧“＋按键”添加").font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(editWidgets) { w in
                            HStack(spacing: 6) {
                                Image(systemName: typeIcon(w.type))
                                    .frame(width: 18)
                                    .foregroundColor(.secondary)
                                Text(w.displayName ?? w.type.title).lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(selectedID == w.id ? Color.accentColor.opacity(0.16) : Color.clear))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedID = w.id }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func editor(idx: Int) -> some View {
        let w = editWidgets[idx]
        return SectionCard(icon: "slider.horizontal.3", title: L("ui.inspector")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(w.type.title, systemImage: typeIcon(w.type)).bold()
                    Spacer()
                    Button("复制") { copySelected() }
                    Button("剪切") { cutSelected() }
                    Button("粘贴") { pasteWidget() }
                    Button("副本") { duplicateSelected() }.keyboardShortcut("d", modifiers: .command)
                    Button("删除") { deleteSelected() }
                }
                HStack(spacing: 6) {
                    DoubleField(label: "X", value: coordBinding(idx, "x"))
                    DoubleField(label: "Y", value: coordBinding(idx, "y"))
                    DoubleField(label: "W", value: coordBinding(idx, "w"))
                    DoubleField(label: "H", value: coordBinding(idx, "h"))
                    Spacer()
                }
                if w.type == .keycap {
                    HStack {
                        Button(w.keyCode == nil ? "绑定按键" : (w.displayName ?? "绑定按键")) { isRecordingKey = true }
                        Text(w.keyCode == nil ? "未绑定" : "已绑定").font(.caption).foregroundColor(.secondary)
                    }
                }
                if w.type == .gamepadButton && w.gamepadButton == "face" {
                    Picker("布局", selection: faceLayoutBinding(idx)) {
                        Text("自动").tag("auto")
                        Text("Xbox").tag("xbox")
                        Text("PlayStation").tag("ps")
                        Text("Switch").tag("switch")
                    }
                }
                if w.type == .gamepadButton && w.gamepadButton != "dpad" && w.gamepadButton != "face" {
                    Picker("绑定手柄", selection: gamepadDeviceBinding(idx)) {
                        Text("任意手柄").tag("any")
                        ForEach(Array(state.gamepadNames.enumerated()), id: \.offset) { i, name in
                            Text(name).tag(String(i))
                        }
                    }
                    Picker("绑定按键", selection: gamepadButtonBinding(idx)) {
                        ForEach(allGamepadButtons, id: \.id) { def in
                            Text(def.label).tag(def.id)
                        }
                    }
                }
                if w.type == .gamepad {
                    Picker("绑定手柄", selection: gamepadDeviceBinding(idx)) {
                        Text("任意手柄").tag("any")
                        ForEach(Array(state.gamepadNames.enumerated()), id: \.offset) { i, name in
                            Text(name).tag(String(i))
                        }
                    }
                    Toggle("背景透明度", isOn: backgroundBrightnessOnBinding(idx))
                    if editWidgets[idx].backgroundBrightnessOn ?? false {
                        HStack {
                            Text("透明度").frame(width: 60, alignment: .leading)
                            Slider(value: backgroundBrightnessBinding(idx), in: 0...1.0)
                            Text("\(Int((editWidgets[idx].backgroundBrightness ?? 1.0) * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                if w.type == .waterfall {
                    Picker("方向", selection: strBinding(idx, def: "down")) {
                        Text("向上").tag("up")
                        Text("向下").tag("down")
                        Text("向左").tag("left")
                        Text("向右").tag("right")
                    }
                    Toggle("随机速度", isOn: waterfallBoolBinding(idx, "randomSpeed"))
                    if editWidgets[idx].waterfallRandomSpeed ?? false {
                        HStack {
                            Text("速度").frame(width: 40, alignment: .leading)
                            TextField("", value: dblBinding(idx, key: "speedMin", def: 60), format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 56)
                            Text("~").foregroundColor(.secondary)
                            TextField("", value: dblBinding(idx, key: "speedMax", def: 320), format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 56)
                        }
                    } else {
                        HStack {
                            Text("速度").frame(width: 40, alignment: .leading)
                            TextField("", value: dblBinding(idx, key: "speed", def: 140), format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 72)
                            Text("20~800").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle("随机落点", isOn: waterfallBoolBinding(idx, "random"))
                    Toggle("随机大小", isOn: waterfallBoolBinding(idx, "randomSize"))
                    Toggle("拖尾", isOn: waterfallBoolBinding(idx, "trail"))
                    Toggle("随机下落角度", isOn: waterfallBoolBinding(idx, "randomAngle"))
                    if editWidgets[idx].waterfallRandomAngle ?? false {
                        HStack {
                            Text("角度").frame(width: 40, alignment: .leading)
                            TextField("", value: dblBinding(idx, key: "angleMin", def: -45), format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 56)
                            Text("~").foregroundColor(.secondary)
                            TextField("", value: dblBinding(idx, key: "angleMax", def: 45), format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 56)
                        }
                    }
                    Toggle("底部淡出", isOn: waterfallBoolBinding(idx, "fade"))
                    Toggle("背景透明度", isOn: backgroundBrightnessOnBinding(idx))
                    if editWidgets[idx].backgroundBrightnessOn ?? false {
                        HStack {
                            Text("透明度").frame(width: 60, alignment: .leading)
                            Slider(value: backgroundBrightnessBinding(idx), in: 0...1.0)
                            Text("\(Int((editWidgets[idx].backgroundBrightness ?? 1.0) * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                if w.type == .sequence {
                    Picker("方向", selection: strBinding(idx, def: "h")) {
                        Text("横向").tag("h")
                        Text("横向反转").tag("hr")
                        Text("纵向").tag("v")
                        Text("纵向反转").tag("vr")
                    }
                    HStack {
                        Text("文字大小").frame(width: 60, alignment: .leading)
                        TextField("", value: dblBinding(idx, key: "fontSize", def: 14), format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 56)
                        Text("8~100").font(.caption).foregroundColor(.secondary)
                    }
                    ColorPicker("文字颜色", selection: colorBinding(idx))
                    Toggle("居中", isOn: sequenceCenteredBinding(idx))
                    HStack {
                        Text("停留").frame(width: 40, alignment: .leading)
                        Slider(value: dblBinding(idx, key: "dwell", def: 3), in: 0.5...10)
                        Text(String(format: "%.1f", editWidgets[idx].dwell ?? 3)).font(.caption.monospacedDigit()).frame(width: 36, alignment: .trailing)
                    }
                    Toggle("背景透明度", isOn: backgroundBrightnessOnBinding(idx))
                    if editWidgets[idx].backgroundBrightnessOn ?? false {
                        HStack {
                            Text("透明度").frame(width: 60, alignment: .leading)
                            Slider(value: backgroundBrightnessBinding(idx), in: 0...1.0)
                            Text("\(Int((editWidgets[idx].backgroundBrightness ?? 1.0) * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                if w.type == .text {
                    HStack {
                        Text("内容").frame(width: 40, alignment: .leading)
                        TextField("文本内容", text: textBinding(idx))
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("字号").frame(width: 40, alignment: .leading)
                        Slider(value: fontBinding(idx), in: 8...120)
                        Text(String(Int(editWidgets[idx].fontSize ?? 24))).font(.caption.monospacedDigit()).frame(width: 32, alignment: .trailing)
                    }
                    Picker("对齐", selection: alignBinding(idx)) {
                        Text("左对齐").tag("left")
                        Text("居中").tag("center")
                        Text("右对齐").tag("right")
                    }.pickerStyle(.segmented)
                    ColorPicker("颜色", selection: colorBinding(idx))
                }
            }
        }
    }

    private func strBinding(_ i: Int, def: String) -> Binding<String> {
        Binding(
            get: { editWidgets[i].direction ?? def },
            set: { editWidgets[i].direction = $0; commitWidgets() }
        )
    }

    private func sequenceCenteredBinding(_ i: Int) -> Binding<Bool> {
        Binding(
            get: { editWidgets[i].sequenceCentered ?? false },
            set: { editWidgets[i].sequenceCentered = $0; commitWidgets() }
        )
    }

    private func backgroundBrightnessOnBinding(_ i: Int) -> Binding<Bool> {
        Binding(
            get: { editWidgets[i].backgroundBrightnessOn ?? false },
            set: { editWidgets[i].backgroundBrightnessOn = $0; commitWidgets() }
        )
    }

    private func backgroundBrightnessBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { editWidgets[i].backgroundBrightness ?? 1.0 },
            set: { editWidgets[i].backgroundBrightness = max(0, min(1, $0)); commitWidgets() }
        )
    }

    private func dblBinding(_ i: Int, key: String, def: Double) -> Binding<Double> {
        Binding(
            get: {
                switch key {
                case "speed": return editWidgets[i].speed ?? def
                case "speedMin": return editWidgets[i].waterfallSpeedMin ?? def
                case "speedMax": return editWidgets[i].waterfallSpeedMax ?? def
                case "angleMin": return editWidgets[i].waterfallAngleMin ?? def
                case "angleMax": return editWidgets[i].waterfallAngleMax ?? def
                case "fontSize": return editWidgets[i].fontSize ?? def
                default: return editWidgets[i].dwell ?? def
                }
            },
            set: {
                switch key {
                case "speed": editWidgets[i].speed = $0
                case "speedMin": editWidgets[i].waterfallSpeedMin = $0
                case "speedMax": editWidgets[i].waterfallSpeedMax = $0
                case "angleMin": editWidgets[i].waterfallAngleMin = $0
                case "angleMax": editWidgets[i].waterfallAngleMax = $0
                case "fontSize": editWidgets[i].fontSize = min(100, max(8, $0))
                default: editWidgets[i].dwell = $0
                }
                commitWidgets()
            }
        )
    }

    private func waterfallBoolBinding(_ i: Int, _ key: String) -> Binding<Bool> {
        Binding(
            get: {
                switch key {
                case "random": return editWidgets[i].waterfallRandom ?? false
                case "trail": return editWidgets[i].waterfallTrail ?? false
                case "fade": return editWidgets[i].waterfallFade ?? false
                case "randomSize": return editWidgets[i].waterfallRandomSize ?? false
                case "randomAngle": return editWidgets[i].waterfallRandomAngle ?? false
                default: return editWidgets[i].waterfallRandomSpeed ?? false
                }
            },
            set: { v in
                switch key {
                case "random": editWidgets[i].waterfallRandom = v
                case "trail": editWidgets[i].waterfallTrail = v
                case "fade": editWidgets[i].waterfallFade = v
                case "randomSize": editWidgets[i].waterfallRandomSize = v
                case "randomAngle": editWidgets[i].waterfallRandomAngle = v
                default: editWidgets[i].waterfallRandomSpeed = v
                }
                commitWidgets()
            }
        )
    }

    private func waterfallAngleBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { editWidgets[i].waterfallAngle ?? 0 },
            set: { editWidgets[i].waterfallAngle = max(-45, min(45, $0)); commitWidgets() }
        )
    }

    private func widgetOpacityBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { editWidgets[i].opacity ?? 1.0 },
            set: { editWidgets[i].opacity = $0; commitWidgets() }
        )
    }

    private func coordBinding(_ i: Int, _ key: String) -> Binding<Double> {
        Binding(
            get: {
                switch key {
                case "x": return editWidgets[i].x
                case "y": return editWidgets[i].y
                case "w": return editWidgets[i].w
                case "h": return editWidgets[i].h
                default: return 0
                }
            },
            set: { v in
                switch key {
                case "x": editWidgets[i].x = max(0, min(100000, v))
                case "y": editWidgets[i].y = max(0, min(100000, v))
                case "w": editWidgets[i].w = max(24, min(100000, v))
                case "h": editWidgets[i].h = max(24, min(100000, v))
                default: break
                }
                commitWidgets()
            }
        )
    }

    private func textBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { editWidgets[i].label ?? "" },
            set: { editWidgets[i].label = $0; commitWidgets() }
        )
    }

    private func faceLayoutBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { editWidgets[i].gamepadFaceLayout ?? "auto" },
            set: { editWidgets[i].gamepadFaceLayout = $0; commitWidgets() }
        )
    }

    private func gamepadDeviceBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { editWidgets[i].gamepadDevice == nil ? "any" : String(editWidgets[i].gamepadDevice!) },
            set: { v in
                if v == "any" { editWidgets[i].gamepadDevice = nil }
                else { editWidgets[i].gamepadDevice = Int(v) }
                commitWidgets()
            }
        )
    }

    private func gamepadButtonBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { editWidgets[i].gamepadButton ?? "a" },
            set: { editWidgets[i].gamepadButton = $0; commitWidgets() }
        )
    }

    private func fontBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { editWidgets[i].fontSize ?? 24 },
            set: { editWidgets[i].fontSize = $0; commitWidgets() }
        )
    }

    private func alignBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { editWidgets[i].textAlign ?? "left" },
            set: { editWidgets[i].textAlign = $0; commitWidgets() }
        )
    }

    private func colorBinding(_ i: Int) -> Binding<Color> {
        Binding(
            get: { Color(hex: editWidgets[i].textColorHex ?? "#FFFFFF") },
            set: { editWidgets[i].textColorHex = $0.toHex(); commitWidgets() }
        )
    }
}

struct SectionCard<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1))
    }
}

struct GlobalSettingsView: View {
    @EnvironmentObject var state: AppState
    var onProfileLoaded: () -> Void
    @State private var selectedProfile = ""
    @State private var newProfileName = ""
    @State private var isSavingName = false
    @State private var launchAtLogin = false

    private let presets: [AccentPreset] = [
        AccentPreset(name: "蓝", hex: "#4C8BF5"),
        AccentPreset(name: "青", hex: "#2FC6C6"),
        AccentPreset(name: "绿", hex: "#34C759"),
        AccentPreset(name: "橙", hex: "#FF9500"),
        AccentPreset(name: "红", hex: "#FF3B30"),
        AccentPreset(name: "紫", hex: "#AF52DE"),
        AccentPreset(name: "粉", hex: "#FF2D55"),
        AccentPreset(name: "灰", hex: "#8E8E93"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                profileSection()

                SectionCard(icon: "macwindow", title: L("ui.overlay")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("锁定覆盖层（点击穿透）", isOn: $state.locked)
                        Toggle("显示覆盖层", isOn: $state.overlayVisible)
                        Toggle("置顶显示", isOn: $state.alwaysOnTop)
                        Toggle("全屏应用之上显示", isOn: $state.showOverFullscreen)
                        HStack {
                            Text("不透明度").frame(width: 72, alignment: .leading)
                            Slider(value: $state.opacity, in: 0.1...1.0)
                            Text(percent(state.opacity)).frame(width: 44, alignment: .trailing).font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("背景透明度").frame(width: 72, alignment: .leading)
                            Slider(value: $state.globalBackgroundBrightness, in: 0...1.0)
                            Text("\(Int(state.globalBackgroundBrightness * 100))%").frame(width: 44, alignment: .trailing).font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("整体缩放").frame(width: 72, alignment: .leading)
                            Slider(value: $state.scale, in: 0.5...3.0)
                            Text(String(format: "%.1f", state.scale)).frame(width: 44, alignment: .trailing).font(.caption.monospacedDigit())
                        }
                    }
                }

                SectionCard(icon: "paintpalette", title: L("ui.appearance")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("主题", selection: $state.theme) {
                            Text("深色").tag("dark")
                            Text("浅色").tag("light")
                            Text("跟随系统").tag("system")
                        }.pickerStyle(.segmented)
                        HStack {
                            Text("主题色")
                            Spacer()
                            ForEach(presets) { p in
                                Circle()
                                    .fill(Color(hex: p.hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                    .overlay(Circle().stroke(state.accentHex == p.hex ? Color.accentColor : Color.clear, lineWidth: 2))
                                    .onTapGesture { state.accentHex = p.hex }
                            }
                        }
                        Picker("按键形状", selection: $state.keycapShape) {
                            Text("圆角").tag("rounded")
                            Text("圆形").tag("circle")
                        }.pickerStyle(.segmented)
                        Picker("键内特效", selection: $state.pressEffect) {
                            Text("简化").tag("simple")
                            Text("内缩").tag("shrink")
                            Text("脉冲").tag("pulse")
                            Text("回弹").tag("bounce")
                            Text("果冻").tag("jelly")
                        }.pickerStyle(.menu)
                        Picker("键外特效", selection: $state.keyOutEffect) {
                            Text("无").tag("none")
                            Text("光晕").tag("glow")
                            Text("涟漪").tag("ripple")
                            Text("火花").tag("spark")
                        }.pickerStyle(.menu)
                    }
                }

                SectionCard(icon: "gamecontroller", title: L("ui.gamepad")) {
                    Picker("手柄布局", selection: $state.gamepadLayout) {
                        Text("自动").tag("auto")
                        Text("Xbox").tag("xbox")
                        Text("PlayStation").tag("ps")
                        Text("Switch").tag("switch")
                    }.pickerStyle(.segmented)
                }

                SectionCard(icon: "gear", title: L("ui.system")) {
                    Picker("语言", selection: $state.language) {
                        ForEach(AppLang.allCases) { l in Text(l.label).tag(l.rawValue) }
                    }.pickerStyle(.menu)
                    PermissionRow()
                    Divider()
                    Toggle("开机自启", isOn: $launchAtLogin)
                        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
                        .onChange(of: launchAtLogin) { newValue in setLaunchAtLogin(newValue) }
                }

            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileSection() -> some View {
        SectionCard(icon: "square.stack", title: L("ui.config")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("", selection: $selectedProfile) {
                        ForEach(state.profiles.keys.sorted(), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    Button("载入") {
                        guard !selectedProfile.isEmpty else { return }
                        state.loadProfile(selectedProfile)
                        onProfileLoaded()
                    }
                    Button("删除") {
                        guard !selectedProfile.isEmpty else { return }
                        state.deleteProfile(selectedProfile)
                        selectedProfile = ""
                    }
                }
                if isSavingName {
                    HStack {
                        TextField("配置名", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        Button("确认保存") {
                            let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            state.saveProfile(name)
                            newProfileName = ""
                            isSavingName = false
                        }
                        Button("取消") { isSavingName = false }
                    }
                } else {
                    Button("保存为…") { isSavingName = true }
                }
                Divider()
                HStack {
                    Button("导出预设…") { exportPreset() }
                    Button("导入预设…") { importPreset() }
                }
            }
        }
    }

    private func percent(_ v: Double) -> String {
        String(Int(round(v * 100))) + "%"
    }

    private func exportPreset() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "KeyCast预设.json"
        if panel.runModal() == .OK, let url = panel.url {
            state.exportConfig(to: url)
        }
    }

    private func importPreset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.importConfig(from: url)
            onProfileLoaded()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("launch at login error: %@", String(describing: error))
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct CanvasWidgetNode: View {
    let widget: Widget
    let isSelected: Bool
    let accentHex: String
    let previewScale: CGFloat
    let onMove: (CGSize) -> Void
    let onResize: (CGSize) -> Void
    let onResizeEnd: () -> Void
    let baseX: CGFloat
    let baseY: CGFloat
    let onSelect: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var resizeOffset: CGSize = .zero

    private var baseSize: CGSize {
        CGSize(width: CGFloat(widget.w) * previewScale, height: CGFloat(widget.h) * previewScale)
    }

    var body: some View {
        let bw = baseSize.width
        let bh = baseSize.height
        return ZStack(alignment: .bottomTrailing) {
            WidgetNodeView(widget: widget, selected: isSelected, accentHex: accentHex, previewScale: previewScale,
                           sizeOverride: CGSize(width: max(28, bw + resizeOffset.width),
                                                height: max(28, bh + resizeOffset.height)))
        }
        .contentShape(Rectangle())
        .offset(x: baseX + dragOffset.width, y: baseY + dragOffset.height)
        .gesture(combinedGesture(baseW: bw, baseH: bh, baseX: baseX, baseY: baseY))
    }

    private func combinedGesture(baseW: CGFloat, baseH: CGFloat, baseX: CGFloat, baseY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragOffset) { value, state, _ in
                if !isResize(value.startLocation, baseW: baseW, baseH: baseH, baseX: baseX, baseY: baseY) { state = value.translation }
            }
            .updating($resizeOffset) { value, state, _ in
                if isResize(value.startLocation, baseW: baseW, baseH: baseH, baseX: baseX, baseY: baseY) { state = value.translation }
            }
            .onEnded { value in
                if isResize(value.startLocation, baseW: baseW, baseH: baseH, baseX: baseX, baseY: baseY) {
                    onResize(value.translation)
                    onResizeEnd()
                } else if abs(value.translation.width) < 2 && abs(value.translation.height) < 2 {
                    onSelect()
                } else {
                    onMove(value.translation)
                }
            }
    }

    private func isResize(_ p: CGPoint, baseW: CGFloat, baseH: CGFloat, baseX: CGFloat, baseY: CGFloat) -> Bool {
        let localX = p.x - baseX
        let localY = p.y - baseY
        let hx: CGFloat = 12
        let hy: CGFloat = 12
        return localX >= baseW - hx && localY >= baseH - hy
    }
}

struct CanvasPanel: View {
    @EnvironmentObject var state: AppState
    @Binding var widgets: [Widget]
    @Binding var selectedID: UUID?
    let grid: CGFloat
    let accentHex: String
    let snapEnabled: Bool
    let canvasSize: CGSize
    var onCommit: () -> Void
    var onDelete: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onCopy: () -> Void
    var onCut: () -> Void
    var onPaste: () -> Void
    var onNudge: (Double, Double) -> Void
    var fitOnAppear: Bool = true

    @State private var guides: [Guide] = []
    @State private var dragStarts: [UUID: CGPoint] = [:]
    @State private var resizeStarts: [UUID: CGSize] = [:]
    @State private var zoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var viewportSize: CGSize = .zero
    @State private var mouseLoc: CGPoint = .zero
    @State private var eventMonitor: Any?
    @State private var hoverState = HoverState()
    @State private var resizeCommitTimer: Timer?
    @State private var scrollLocked = false
    @State private var scrollLockTarget: UUID?
    @State private var scrollLockTimer: Timer?
    @State private var selectedSet: Set<UUID> = []
    @State private var boxSelecting = false
    @State private var boxStart: CGPoint = .zero
    @State private var boxCurrent: CGPoint = .zero
    @State private var ctrlHeld = false
    @State private var didInitialFit = false

    private var fitValue: CGFloat {
        min(viewportSize.width / max(canvasSize.width, 1), viewportSize.height / max(canvasSize.height, 1), 1.0)
    }

    private var zoomPercentLabel: String {
        "\(Int(zoom * 100))%"
    }

    var body: some View {
        GeometryReader { geo in
            let fit = min(geo.size.width / max(canvasSize.width, 1), geo.size.height / max(canvasSize.height, 1), 1.0)
            let s = fit * zoom
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: canvasSize.width * s, height: canvasSize.height * s)
                    .position(x: canvasSize.width * s / 2 + pan.width, y: canvasSize.height * s / 2 + pan.height)
                CanvasGrid(grid: max(grid * s, 4), size: geo.size, offset: pan)
                Color.clear.contentShape(Rectangle()).onTapGesture {
                    selectedID = nil
                    selectedSet = []
                }

                ForEach(widgets) { w in
                    node(w, s)
                }

                ForEach(guides) { g in
                    if g.isVertical {
                        Rectangle().fill(Color(hex: accentHex)).frame(width: 1).frame(height: geo.size.height)
                            .position(x: g.position * s + pan.width, y: geo.size.height / 2)
                    } else {
                        Rectangle().fill(Color(hex: accentHex)).frame(height: 1).frame(width: geo.size.width)
                            .position(x: geo.size.width / 2, y: g.position * s + pan.height)
                    }
                }
                if boxSelecting {
                    Rectangle()
                        .fill(Color(hex: accentHex).opacity(0.15))
                        .frame(width: max(boxRect.width, 1), height: max(boxRect.height, 1))
                        .overlay(Rectangle().stroke(Color(hex: accentHex), lineWidth: 1))
                        .position(x: boxRect.midX, y: boxRect.midY)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.28)))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Button { zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                    Text(zoomPercentLabel).font(.caption).monospacedDigit().frame(width: 44)
                    Button { zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                    Button("重置") { resetZoom() }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.55)))
                .padding(8)
            }
            .clipped()
            .onContinuousHover { phase in
                if case .active(let location) = phase { mouseLoc = location }
            }
            .onAppear {
                viewportSize = geo.size
                installMonitor()
                if fitOnAppear && !didInitialFit {
                    didInitialFit = true
                    DispatchQueue.main.async { fitToContent(geo.size) }
                }
            }
            .onChange(of: geo.size) { viewportSize = $0 }
            .onChange(of: canvasSize) { _ in zoom = 1; pan = .zero }
            .onDisappear { removeMonitor() }
        }
    }

    @ViewBuilder
    private func node(_ w: Widget, _ s: CGFloat) -> some View {
        CanvasWidgetNode(
            widget: w,
            isSelected: isSelected(w.id),
            accentHex: accentHex,
            previewScale: s,
            onMove: { (translation: CGSize) in moveWidgets(w.id, translation: translation, s: s) },
            onResize: { (translation: CGSize) in resizeDragTick(w.id, translation: translation, s: s) },
            onResizeEnd: { resizeDragEnd(w.id) },
            baseX: CGFloat(w.x) * s + pan.width,
            baseY: CGFloat(w.y) * s + pan.height,
            onSelect: { selectWidget(w.id) }
        )
        .onHover { (inside: Bool) in
            if inside { hoverState.hoveredID = w.id }
            else if hoverState.hoveredID == w.id { hoverState.hoveredID = nil }
        }
    }

    private func moveWidget(_ id: UUID, translation: CGSize, s: CGFloat) {
        var arr = widgets
        guard let idx = arr.firstIndex(where: { $0.id == id }) else { return }
        let size = CGSize(width: CGFloat(arr[idx].w), height: CGFloat(arr[idx].h))
        let ux = CGFloat(arr[idx].x) + translation.width / s
        let uy = CGFloat(arr[idx].y) + translation.height / s

        arr[idx].x = Double(max(0, min(100000, ux)))
        arr[idx].y = Double(max(0, min(100000, uy)))
        widgets = arr

        var tx = ux, ty = uy
        if snapEnabled {
            let r = snapPoint(x: ux, y: uy, size: size, excluding: id)
            tx = r.0.x; ty = r.0.y
        }
        let fx = Double(max(0, min(100000, tx)))
        let fy = Double(max(0, min(100000, ty)))
        withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
            var arr2 = widgets
            arr2[idx].x = fx
            arr2[idx].y = fy
            widgets = arr2
        }
        onCommit()
    }

    private func detectGuides(x: CGFloat, y: CGFloat, size: CGSize, excluding id: UUID) -> [Guide] {
        var gs: [Guide] = []
        let f = CGRect(x: x, y: y, width: size.width, height: size.height)
        let threshold: CGFloat = 5
        var bestV: (delta: CGFloat, pos: CGFloat)?
        var bestH: (delta: CGFloat, pos: CGFloat)?
        for o in widgets where o.id != id {
            let r = CGRect(x: CGFloat(o.x), y: CGFloat(o.y), width: CGFloat(o.w), height: CGFloat(o.h))
            for a in [f.minX, f.midX, f.maxX] {
                for b in [r.minX, r.midX, r.maxX] {
                    let d = b - a
                    if abs(d) < threshold && (bestV == nil || abs(d) < abs(bestV!.delta)) { bestV = (d, b) }
                }
            }
            for a in [f.minY, f.midY, f.maxY] {
                for b in [r.minY, r.midY, r.maxY] {
                    let d = b - a
                    if abs(d) < threshold && (bestH == nil || abs(d) < abs(bestH!.delta)) { bestH = (d, b) }
                }
            }
        }
        if let bv = bestV { gs.append(Guide(isVertical: true, position: bv.pos)) }
        if let bh = bestH { gs.append(Guide(isVertical: false, position: bh.pos)) }
        return gs
    }

    private func resizeDragTick(_ id: UUID, translation: CGSize, s: CGFloat) {
        var arr = widgets
        guard let idx = arr.firstIndex(where: { $0.id == id }) else { return }
        let start = resizeStarts[id] ?? CGSize(width: CGFloat(arr[idx].w), height: CGFloat(arr[idx].h))
        if resizeStarts[id] == nil { resizeStarts[id] = start }
        var nw = start.width + translation.width / s
        var nh = start.height + translation.height / s
        if snapEnabled {
            nw = (nw / grid).rounded() * grid
            nh = (nh / grid).rounded() * grid
        }
        arr[idx].w = Double(max(24, min(100000, nw)))
        arr[idx].h = Double(max(24, min(100000, nh)))
        widgets = arr
    }

    private func resizeDragEnd(_ id: UUID) {
        resizeStarts[id] = nil
        onCommit()
    }

    private func snapPoint(x: CGFloat, y: CGFloat, size: CGSize, excluding id: UUID) -> (CGPoint, [Guide]) {
        var nx = (x / grid).rounded() * grid
        var ny = (y / grid).rounded() * grid
        var gs: [Guide] = []
        let f = CGRect(x: nx, y: ny, width: size.width, height: size.height)
        let threshold: CGFloat = 5
        var bestV: (delta: CGFloat, pos: CGFloat)?
        var bestH: (delta: CGFloat, pos: CGFloat)?
        for o in widgets where o.id != id {
            let r = CGRect(x: CGFloat(o.x), y: CGFloat(o.y), width: CGFloat(o.w), height: CGFloat(o.h))
            for a in [f.minX, f.midX, f.maxX] {
                for b in [r.minX, r.midX, r.maxX] {
                    let d = b - a
                    if abs(d) < threshold && (bestV == nil || abs(d) < abs(bestV!.delta)) { bestV = (d, b) }
                }
            }
            for a in [f.minY, f.midY, f.maxY] {
                for b in [r.minY, r.midY, r.maxY] {
                    let d = b - a
                    if abs(d) < threshold && (bestH == nil || abs(d) < abs(bestH!.delta)) { bestH = (d, b) }
                }
            }
        }
        if let bv = bestV { nx += bv.delta; gs.append(Guide(isVertical: true, position: bv.pos)) }
        if let bh = bestH { ny += bh.delta; gs.append(Guide(isVertical: false, position: bh.pos)) }
        return (CGPoint(x: nx, y: ny), gs)
    }

    private func applyZoom(_ factor: CGFloat, around anchor: CGPoint) {
        let oldS = fitValue * zoom
        zoom = min(max(zoom * factor, 1.0), 8)
        let newS = fitValue * zoom
        let ratio = newS / max(oldS, 0.0001)
        pan.width = anchor.x - (anchor.x - pan.width) * ratio
        pan.height = anchor.y - (anchor.y - pan.height) * ratio
        clampPan()
    }

    private func zoomIn() { applyZoom(1.25, around: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)) }
    private func zoomOut() { applyZoom(1 / 1.25, around: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)) }
    private func resetZoom() { zoom = 1; pan = .zero }

    private func isSelected(_ id: UUID) -> Bool {
        selectedID == id || selectedSet.contains(id)
    }

    private var boxRect: CGRect {
        CGRect(x: min(boxStart.x, boxCurrent.x), y: min(boxStart.y, boxCurrent.y),
               width: abs(boxCurrent.x - boxStart.x), height: abs(boxCurrent.y - boxStart.y))
    }

    private func selectWidget(_ id: UUID) {
        if ctrlHeld {
            if selectedSet.contains(id) {
                selectedSet.remove(id)
                if selectedID == id { selectedID = selectedSet.first }
            } else {
                selectedSet.insert(id)
                selectedID = id
            }
        } else {
            selectedID = id
            selectedSet = [id]
        }
    }

    private func moveWidgets(_ id: UUID, translation: CGSize, s: CGFloat) {
        if selectedSet.count <= 1 || !selectedSet.contains(id) {
            moveWidget(id, translation: translation, s: s)
            return
        }
        var arr = widgets
        guard let pi = arr.firstIndex(where: { $0.id == id }) else { return }
        let bx = CGFloat(arr[pi].x), by = CGFloat(arr[pi].y)
        let ux = bx + translation.width / s, uy = by + translation.height / s
        var tx = ux, ty = uy
        if snapEnabled {
            let r = snapPoint(x: ux, y: uy, size: CGSize(width: CGFloat(arr[pi].w), height: CGFloat(arr[pi].h)), excluding: id)
            tx = r.0.x; ty = r.0.y
        }
        let dx = tx - bx, dy = ty - by
        for i in arr.indices where selectedSet.contains(arr[i].id) {
            arr[i].x = Double(max(0, min(100000, CGFloat(arr[i].x) + dx)))
            arr[i].y = Double(max(0, min(100000, CGFloat(arr[i].y) + dy)))
        }
        widgets = arr
        onCommit()
    }

    private func deleteSelectedWidgets() {
        let ids = selectedSet.isEmpty ? Set([selectedID].compactMap { $0 }) : selectedSet
        guard !ids.isEmpty else { return }
        var arr = widgets
        arr.removeAll { ids.contains($0.id) }
        widgets = arr
        selectedID = nil
        selectedSet = []
        onCommit()
    }

    private func resizeGroup(_ delta: CGFloat) {
        var arr = widgets
        let f = max(0.5, min(2.0, 1 + delta * 0.02))
        for i in arr.indices where selectedSet.contains(arr[i].id) {
            arr[i].w = Double(max(24, min(100000, CGFloat(arr[i].w) * f)))
            arr[i].h = Double(max(24, min(100000, CGFloat(arr[i].h) * f)))
        }
        widgets = arr
    }

    private func updateBoxSelection() {
        let s = fitValue * zoom
        let minX = min(boxStart.x, boxCurrent.x)
        let maxX = max(boxStart.x, boxCurrent.x)
        let minY = min(boxStart.y, boxCurrent.y)
        let maxY = max(boxStart.y, boxCurrent.y)
        selectedSet = Set(widgets.filter { w in
            let rx = CGFloat(w.x) * s + pan.width
            let ry = CGFloat(w.y) * s + pan.height
            let rw = CGFloat(w.w) * s
            let rh = CGFloat(w.h) * s
            return rx < maxX && rx + rw > minX && ry < maxY && ry + rh > minY
        }.map { $0.id })
    }

    private func resizeWidget(_ id: UUID, delta: CGFloat) {
        var arr = widgets
        guard let idx = arr.firstIndex(where: { $0.id == id }) else { return }
        let f = max(0.5, min(2.0, 1 + delta * 0.02))
        arr[idx].w = Double(max(24, min(100000, CGFloat(arr[idx].w) * f)))
        arr[idx].h = Double(max(24, min(100000, CGFloat(arr[idx].h) * f)))
        widgets = arr
    }

    private func scheduleResizeCommit() {
        resizeCommitTimer?.invalidate()
        let t = Timer(timeInterval: 0.2, repeats: false) { _ in onCommit() }
        RunLoop.main.add(t, forMode: .common)
        resizeCommitTimer = t
    }

    private func scheduleScrollUnlock() {
        scrollLockTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: false) { _ in
            scrollLocked = false
            scrollLockTarget = nil
        }
        RunLoop.main.add(t, forMode: .common)
        scrollLockTimer = t
    }

    private func clampPan() {
        let cw = canvasSize.width * fitValue * zoom
        let ch = canvasSize.height * fitValue * zoom
        pan.width = max(viewportSize.width - cw, min(0, pan.width))
        pan.height = max(viewportSize.height - ch, min(0, pan.height))
    }

    private func fitToContent(_ viewport: CGSize) {
        guard !widgets.isEmpty else { zoom = 1; pan = .zero; return }
        var minX = CGFloat.greatestFiniteMagnitude, minY = minX, maxX = -minX, maxY = -minX
        for w in widgets {
            minX = min(minX, CGFloat(w.x)); minY = min(minY, CGFloat(w.y))
            maxX = max(maxX, CGFloat(w.x + w.w)); maxY = max(maxY, CGFloat(w.y + w.h))
        }
        let pad: CGFloat = 48
        let bw = maxX - minX + pad * 2
        let bh = maxY - minY + pad * 2
        guard bw > 1, bh > 1 else { return }
        let fit = min(viewport.width / max(canvasSize.width, 1), viewport.height / max(canvasSize.height, 1), 1.0)
        let target = min(viewport.width / bw, viewport.height / bh)
        let s = max(fit, min(target, fit * 8))
        zoom = max(1, min(8, s / fit))
        let sFinal = fit * zoom
        let bcx = (minX + maxX) / 2, bcy = (minY + maxY) / 2
        pan.width = viewport.width / 2 - bcx * sFinal
        pan.height = viewport.height / 2 - bcy * sFinal
        clampPan()
    }

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .rightMouseDragged, .rightMouseUp, .scrollWheel, .keyDown, .flagsChanged]) { event in
            switch event.type {
            case .leftMouseDown, .rightMouseDown:
                if event.modifierFlags.contains(.control) {
                    boxSelecting = true
                    boxStart = mouseLoc
                    boxCurrent = mouseLoc
                    return nil
                }
                return event
            case .leftMouseUp, .rightMouseUp:
                if event.modifierFlags.contains(.control) {
                    if boxSelecting {
                        boxSelecting = false
                        if boxRect.width < 6 && boxRect.height < 6 {
                            if let hid = hoverState.hoveredID {
                                if selectedSet.contains(hid) {
                                    selectedSet.remove(hid)
                                    if selectedID == hid { selectedID = selectedSet.first }
                                } else {
                                    selectedSet.insert(hid)
                                    selectedID = hid
                                }
                            } else {
                                selectedID = nil
                                selectedSet = []
                            }
                        }
                    }
                    return nil
                }
                return event
            case .leftMouseDragged, .rightMouseDragged:
                if event.modifierFlags.contains(.control) {
                    if boxSelecting {
                        boxCurrent.x += event.deltaX
                        boxCurrent.y += event.deltaY
                        updateBoxSelection()
                    }
                    return nil
                }
                if event.type == .rightMouseDragged {
                    pan.width += event.deltaX
                    pan.height += event.deltaY
                    clampPan()
                }
                return event
            case .scrollWheel:
                if event.modifierFlags.contains(.control) {
                    if !scrollLocked {
                        scrollLocked = true
                        scrollLockTarget = hoverState.hoveredID
                    }
                    if let tid = scrollLockTarget {
                        if selectedSet.count > 1 && selectedSet.contains(tid) {
                            resizeGroup(event.scrollingDeltaY)
                        } else {
                            resizeWidget(tid, delta: event.scrollingDeltaY)
                        }
                        scheduleResizeCommit()
                    } else {
                        applyZoom(exp(event.scrollingDeltaY * 0.01), around: mouseLoc)
                    }
                    scheduleScrollUnlock()
                    return nil
                }
                scrollLocked = false
                scrollLockTarget = nil
                return event
            case .flagsChanged:
                ctrlHeld = event.modifierFlags.contains(.control)
                if !ctrlHeld {
                    scrollLocked = false
                    scrollLockTarget = nil
                    scrollLockTimer?.invalidate()
                    scrollLockTimer = nil
                }
                return event
            case .keyDown:
                let editingText = event.window?.firstResponder is NSTextView

                if event.keyCode == 53 {
                    if event.window?.styleMask.contains(.fullScreen) == true {
                        return nil
                    }
                    return event
                }

                if event.keyCode == 51 || event.keyCode == 117 {
                    if !editingText {
                        deleteSelectedWidgets()
                        return nil
                    }
                    return event
                }

                if !editingText {
                    let shift = event.modifierFlags.contains(.shift)
                    let step = shift ? 10.0 : 1.0
                    switch event.keyCode {
                    case 123: onNudge(-step, 0); return nil
                    case 124: onNudge(step, 0); return nil
                    case 125: onNudge(0, step); return nil
                    case 126: onNudge(0, -step); return nil
                    default: break
                    }
                }

                if event.modifierFlags.contains(.command) {
                    if !editingText {
                        switch event.charactersIgnoringModifiers {
                        case "c": onCopy(); return nil
                        case "x": onCut(); return nil
                        case "v": onPaste(); return nil
                        default: break
                        }
                    }
                    switch event.charactersIgnoringModifiers {
                    case "=": zoomIn(); clampPan(); return nil
                    case "-": zoomOut(); clampPan(); return nil
                    case "0": resetZoom(); return nil
                    default: break
                    }
                }
                if event.modifierFlags.contains(.control) {
                    switch event.charactersIgnoringModifiers {
                    case "z": onUndo(); return nil
                    case "y": onRedo(); return nil
                    default: break
                    }
                }
                return event
            default:
                return event
            }
        }
    }

    private func removeMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        resizeCommitTimer?.invalidate()
        resizeCommitTimer = nil
        scrollLockTimer?.invalidate()
        scrollLockTimer = nil
    }
}

struct CanvasGrid: View {
    let grid: CGFloat
    let size: CGSize
    var offset: CGSize = .zero

    var body: some View {
        Path { p in
            var x = offset.width.truncatingRemainder(dividingBy: grid)
            while x < size.width {
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += grid
            }
            var y = offset.height.truncatingRemainder(dividingBy: grid)
            while y < size.height {
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += grid
            }
        }
        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
    }
}

struct WidgetNodeView: View {
    let widget: Widget
    let selected: Bool
    let accentHex: String
    let previewScale: CGFloat
    var sizeOverride: CGSize? = nil

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 14))
            Text(label).font(.caption2).lineLimit(1)
        }
        .frame(width: sizeOverride?.width ?? CGFloat(widget.w) * previewScale,
               height: sizeOverride?.height ?? CGFloat(widget.h) * previewScale)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color(hex: accentHex) : Color.white.opacity(0.25), lineWidth: selected ? 2 : 1))
    }

    private var icon: String {
        switch widget.type {
        case .keycap: return "keyboard"
        case .mouse: return "cursorarrow"
        case .gamepad: return "gamecontroller"
        case .gamepadButton: return "gamecontroller"
        case .sequence: return "list.bullet"
        case .waterfall: return "drop"
        case .displacement: return "scope"
        case .wheel: return "dial"
        case .text: return "text.alignleft"
        }
    }

    private var label: String {
        if widget.type == .keycap { return widget.displayName ?? "未绑定" }
        return widget.type.title
    }
}

struct DoubleField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField("", value: $value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)
        }
    }
}

struct KeyRecorderView: View {
    var onCapture: (Int, String) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("录制按键").font(.headline)
            Text("请按下要绑定的按键").foregroundColor(.secondary)
            Button("取消") { onCancel() }
        }
        .padding(24)
        .frame(width: 260, height: 170)
        .onAppear {
            AppDelegate.shared.onKeyForRecording = { code, name in onCapture(code, name) }
        }
        .onDisappear {
            AppDelegate.shared.onKeyForRecording = nil
        }
    }
}

struct PermissionRow: View {
    @State private var imGranted = false
    @State private var axGranted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            permRow("输入监控（键盘）", granted: imGranted)
            permRow("辅助功能（鼠标）", granted: axGranted)
            HStack {
                Button("重新检测") { refresh() }
                Button("重启应用") { AppDelegate.shared.relaunch() }
                Button("打开系统设置") {
                    if !imGranted, let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(u)
                    }
                    if !axGranted, let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(u)
                    }
                }
            }
            if !imGranted {
                Text("⚠️ 键盘不响应：输入监控未授权。请在系统设置中开启后，点“重启应用”。").font(.caption).foregroundColor(.red)
            } else {
                Text("✅ 授权正常").font(.caption).foregroundColor(.secondary)
            }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        imGranted = CGPreflightListenEventAccess()
        axGranted = AXIsProcessTrusted()
    }

    private func permRow(_ name: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
            Text(name)
            Spacer()
            Text(granted ? "已授权" : "未授权").font(.caption).foregroundColor(.secondary)
        }
    }
}
