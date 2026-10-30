import SwiftUI
import AppKit

// 可拖动的悬浮面板：拖到屏幕边自动吸附；点“−”隐藏成小标签；点标签再展开
struct FloatingPanel<Content: View>: View {
    let title: String
    let screenSize: CGSize
    @Binding var origin: CGPoint
    @Binding var collapsed: Bool
    let width: CGFloat
    @ViewBuilder let content: (Bool) -> Content

    private enum Edge { case top, bottom, left, right }
    @State private var edge: Edge = .top
    @GestureState private var dragOffset: CGSize = .zero

    private var isVertical: Bool { edge == .left || edge == .right }

    var body: some View {
        if collapsed {
            tab
        } else {
            panel
        }
    }

    private var tab: some View {
        Button { collapsed = false } label: {
            Group {
                if edge == .top || edge == .bottom {
                    HStack(spacing: 5) {
                        Image(systemName: "square.on.circle")
                        Text(title)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "square.on.circle")
                        Text(title)
                    }
                    .font(.caption)
                    .padding(.horizontal, 7).padding(.vertical, 12)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .offset(x: origin.x, y: origin.y)
    }

    private var panel: some View {
        let w = isVertical ? 130.0 : width
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { collapsed = true } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless)
                    .highPriorityGesture(TapGesture().onEnded { collapsed = true })
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            content(isVertical).padding(10)
        }
        .frame(width: w)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 1))
        .shadow(radius: 6)
        .offset(x: origin.x + dragOffset.width, y: origin.y + dragOffset.height)
        .gesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragOffset) { v, state, _ in state = v.translation }
            .onEnded { v in
                origin = CGPoint(x: origin.x + v.translation.width, y: origin.y + v.translation.height)
                snap()
            }
    }

    private func snap() {
        let threshold: CGFloat = 60
        var o = origin
        var nearestDist = threshold
        var nearest = edge

        func consider(_ d: CGFloat, _ e: Edge) {
            if d < nearestDist { nearestDist = d; nearest = e }
        }
        consider(o.y, .top)
        consider(o.x, .left)
        consider(screenSize.width - o.x - width, .right)
        consider(screenSize.height - o.y - 88, .bottom)

        if nearestDist < threshold {
            edge = nearest
            switch nearest {
            case .top: o.y = 8
            case .bottom: o.y = max(8, screenSize.height - 96)
            case .left: o.x = 8
            case .right: o.x = max(8, screenSize.width - width - 8)
            }
        }
        origin = o
    }
}

// 全屏画布编辑视图
struct FullscreenCanvasView: View {
    @EnvironmentObject var state: AppState
    @State private var editWidgets: [Widget] = []
    @State private var selectedID: UUID?
    @Binding var snapEnabled: Bool
    @State private var copiedWidget: Widget?
    @State private var isRecordingKey = false

    @State private var toolbarOrigin = CGPoint(x: 400, y: 16)
    @State private var editorOrigin = CGPoint(x: 900, y: 120)
    @State private var toolbarCollapsed = false
    @State private var editorCollapsed = false

    private let grid: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

                CanvasPanel(widgets: $editWidgets, selectedID: $selectedID, grid: grid,
                            accentHex: state.accentHex, snapEnabled: snapEnabled,
                            canvasSize: Canvas.size(for: state.canvasSize),
                            onCommit: { commitWidgets() },
                            onDelete: deleteSelected,
                            onUndo: undo, onRedo: redo,
                            onCopy: copySelected, onCut: cutSelected, onPaste: pasteWidget,
                            onNudge: { dx, dy in nudge(dx, dy) },
                            fitOnAppear: false)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                FloatingPanel(title: "工具栏", screenSize: geo.size, origin: $toolbarOrigin, collapsed: $toolbarCollapsed, width: 600) { isVertical in
                    toolbar(isVertical: isVertical)
                }
                FloatingPanel(title: "控件", screenSize: geo.size, origin: $editorOrigin, collapsed: $editorCollapsed, width: 300) { _ in
                    if let idx = selectedIndex { editor(idx) } else { Text("未选中控件").font(.caption).foregroundColor(.secondary) }
                }
            }
        }
        .onAppear { editWidgets = state.widgets }
        .sheet(isPresented: $isRecordingKey) {
            KeyRecorderView(onCapture: { code, name in
                addKeycap(code: code, name: name)
                isRecordingKey = false
            }, onCancel: { isRecordingKey = false })
        }
    }

    @ViewBuilder private func toolbar(isVertical: Bool) -> some View {
        if isVertical {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) { toolbarButtons }
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
                    toolbarButtons
                }
            }
        }
    }

    @ViewBuilder private var toolbarButtons: some View {
        Button { isRecordingKey = true } label: { Label("按键", systemImage: "keyboard") }
            .buttonStyle(.bordered).controlSize(.small)
        ForEach(nonKeycapTypes, id: \.self) { t in
            Button { addWidget(t) } label: { Label(t.title, systemImage: typeIcon(t)) }
                .buttonStyle(.bordered).controlSize(.small)
        }
        Button { undo() } label: { Label("撤回", systemImage: "arrow.uturn.backward") }
            .buttonStyle(.bordered).controlSize(.small)
        Button { redo() } label: { Label("重做", systemImage: "arrow.uturn.forward") }
            .buttonStyle(.bordered).controlSize(.small)
        Toggle("吸附", isOn: $snapEnabled).controlSize(.small)
        Button { AppDelegate.shared.toggleSettingsFullscreen() } label: { Label("退出全屏", systemImage: "xmark.circle") }
            .buttonStyle(.bordered).controlSize(.small)
    }

    private var nonKeycapTypes: [WidgetType] {
        WidgetType.allCases.filter { $0 != .keycap && $0 != .gamepadButton }
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

    private var selectedIndex: Int? {
        selectedID.flatMap { id in editWidgets.firstIndex(where: { $0.id == id }) }
    }

    private func addWidget(_ type: WidgetType) {
        let o = nextOrigin()
        let sz = type.defaultSize
        var w = Widget(id: UUID(), type: type, x: o.x, y: o.y, w: sz.w, h: sz.h, keyCode: nil, displayName: nil)
        if type == .waterfall { w.direction = "down"; w.speed = 140 }
        if type == .sequence { w.direction = "h"; w.dwell = 3 }
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private func addKeycap(code: Int, name: String) {
        let o = nextOrigin()
        let w = Widget(id: UUID(), type: .keycap, x: o.x, y: o.y, w: 64, h: 64, keyCode: code, displayName: name)
        editWidgets.append(w)
        selectedID = w.id
        commitWidgets()
    }

    private func nextOrigin() -> (x: Double, y: Double) {
        let n = editWidgets.count
        return (24 + Double(n % 5) * 96, 24 + Double(n / 5) * 96)
    }

    private func deleteSelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        editWidgets.remove(at: idx); selectedID = nil; commitWidgets()
    }
    private func copySelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        var w = editWidgets[idx]; w.id = UUID(); copiedWidget = w
    }
    private func cutSelected() {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        var w = editWidgets[idx]; w.id = UUID(); copiedWidget = w
        editWidgets.remove(at: idx); selectedID = nil; commitWidgets()
    }
    private func pasteWidget() {
        guard var w = copiedWidget else { return }
        w.id = UUID(); w.x += 16; w.y += 16
        editWidgets.append(w); selectedID = w.id; commitWidgets()
    }
    private func nudge(_ dx: Double, _ dy: Double) {
        guard let id = selectedID, let idx = editWidgets.firstIndex(where: { $0.id == id }) else { return }
        editWidgets[idx].x = max(0, min(100000, editWidgets[idx].x + dx))
        editWidgets[idx].y = max(0, min(100000, editWidgets[idx].y + dy))
        commitWidgets()
    }
    private func undo() {
        if state.undo() { editWidgets = state.widgets }
    }
    private func redo() {
        if state.redo() { editWidgets = state.widgets }
    }

    private func commitWidgets() {
        if editWidgets != state.widgets {
            state.recordUndo(oldWidgets: state.widgets)
            state.widgets = editWidgets
        }
    }

    private func editor(_ idx: Int) -> some View {
        let w = editWidgets[idx]
        return VStack(alignment: .leading, spacing: 8) {
            Label(w.type.title, systemImage: typeIcon(w.type)).bold()
            HStack(spacing: 6) {
                DoubleField(label: "X", value: coordBinding(idx, "x"))
                DoubleField(label: "Y", value: coordBinding(idx, "y"))
                DoubleField(label: "W", value: coordBinding(idx, "w"))
                DoubleField(label: "H", value: coordBinding(idx, "h"))
            }
            if w.type == .keycap {
                Button(w.keyCode == nil ? "绑定按键" : (w.displayName ?? "绑定按键")) { isRecordingKey = true }
            }
            HStack {
                Button("复制") { copySelected() }
                Button("剪切") { cutSelected() }
                Button("粘贴") { pasteWidget() }
                Button("删除") { deleteSelected() }
            }
        }
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
}
