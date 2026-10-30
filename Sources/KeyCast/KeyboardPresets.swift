import Foundation

struct KeyDef {
    let label: String
    let code: Int
    let row: Int
    let col: Double
    let width: Double
    let height: Double
}

struct KeyboardPreset {
    let name: String
    let keys: [KeyDef]

    func makeWidgets(originX: Double, originY: Double) -> [Widget] {
        let keySize = 48.0
        let gap = 4.0
        return keys.map { kd in
            let x = originX + kd.col * (keySize + gap)
            let y = originY + Double(kd.row) * (keySize + gap)
            let w = keySize * kd.width + (kd.width - 1) * gap
            let h = keySize * kd.height + (kd.height - 1) * gap
            return Widget(id: UUID(), type: .keycap, x: x, y: y, w: w, h: h, keyCode: kd.code, displayName: kd.label)
        }
    }
}

private func key(_ label: String, _ code: Int, _ w: Double = 1, _ h: Double = 1) -> (String, Int, Double, Double) { (label, code, w, h) }
private func gap(_ w: Double) -> (String, Int, Double, Double) { ("", -1, w, 1) }

private func buildRows(_ rows: [[(String, Int, Double, Double)]]) -> [KeyDef] {
    var out: [KeyDef] = []
    for (r, row) in rows.enumerated() {
        var col = 0.0
        for (label, code, w, h) in row {
            if code >= 0 { out.append(KeyDef(label: label, code: code, row: r, col: col, width: w, height: h)) }
            col += w
        }
    }
    return out
}

enum KeyboardPresets {
    static let all: [KeyboardPreset] = [full, num108, num98, numpad, wasd, moba]

    // 全键盘 104键（主键区 + 功能键 + 方向键 + 数字区）
    static let full = KeyboardPreset(name: "全键盘 104键", keys: buildRows([
        [key("Esc", 53), key("F1", 122), key("F2", 120), key("F3", 99), key("F4", 118), key("F5", 96), key("F6", 97), key("F7", 98), key("F8", 100), key("F9", 101), key("F10", 109), key("F11", 103), key("F12", 111), gap(0.5), key("PrtSc", 105), key("ScrLk", 107), key("Pause", 113)],
        [key("~", 50), key("1", 18), key("2", 19), key("3", 20), key("4", 21), key("5", 23), key("6", 22), key("7", 26), key("8", 28), key("9", 25), key("0", 29), key("-", 27), key("=", 24), key("⌫", 51, 2), gap(0.5), key("Ins", 114), key("Home", 115), key("PgUp", 116), gap(0.5), key("Num", 71), key("/", 75), key("*", 67), key("-", 78)],
        [key("Tab", 48, 1.5), key("Q", 12), key("W", 13), key("E", 14), key("R", 15), key("T", 17), key("Y", 16), key("U", 32), key("I", 34), key("O", 31), key("P", 35), key("[", 33), key("]", 30), key("\\", 42, 1.5), gap(0.5), key("Del", 117), key("End", 119), key("PgDn", 121), gap(0.5), key("7", 89), key("8", 91), key("9", 92), key("+", 69, 1, 2)],
        [key("Caps", 57, 1.75), key("A", 0), key("S", 1), key("D", 2), key("F", 3), key("G", 5), key("H", 4), key("J", 38), key("K", 40), key("L", 37), key(";", 41), key("'", 39), key("Enter", 36, 2.25), gap(4), key("4", 86), key("5", 87), key("6", 88)],
        [key("Shift", 56, 2.25), key("Z", 6), key("X", 7), key("C", 8), key("V", 9), key("B", 11), key("N", 45), key("M", 46), key(",", 43), key(".", 47), key("/", 44), key("Shift", 60, 2.75), gap(1.5), key("↑", 126), gap(1.5), key("1", 83), key("2", 84), key("3", 85), key("Enter", 76, 1, 2)],
        [key("Ctrl", 59, 1.25), key("Cmd", 55, 1.25), key("Opt", 58, 1.25), key("Space", 49, 6.25), key("Opt", 61, 1.25), key("Cmd", 54, 1.25), key("Fn", 63, 1.25), key("Ctrl", 62, 1.25), gap(0.5), key("←", 123), key("↓", 125), key("→", 124), gap(0.5), key("0", 82, 2), key(".", 65)]
    ]))

    // 108键 = 全键盘 + 4颗多媒体键
    static let num108 = KeyboardPreset(name: "108键", keys: full.keys + buildRows([
        [gap(17), key("静音", 74), key("音量-", 73), key("音量+", 72), key("Fn", 63)]
    ]))

    // 98键紧凑
    static let num98 = KeyboardPreset(name: "98键", keys: buildRows([
        [key("Esc", 53), key("F1", 122), key("F2", 120), key("F3", 99), key("F4", 118), key("F5", 96), key("F6", 97), key("F7", 98), key("F8", 100), key("F9", 101), key("F10", 109), key("F11", 103), key("F12", 111), gap(2.5), key("PrtSc", 105), key("Del", 117)],
        [key("~", 50), key("1", 18), key("2", 19), key("3", 20), key("4", 21), key("5", 23), key("6", 22), key("7", 26), key("8", 28), key("9", 25), key("0", 29), key("-", 27), key("=", 24), key("⌫", 51, 2), gap(4), key("Num", 71), key("/", 75), key("*", 67), key("-", 78)],
        [key("Tab", 48, 1.5), key("Q", 12), key("W", 13), key("E", 14), key("R", 15), key("T", 17), key("Y", 16), key("U", 32), key("I", 34), key("O", 31), key("P", 35), key("[", 33), key("]", 30), key("\\", 42, 1.5), gap(4), key("7", 89), key("8", 91), key("9", 92), key("+", 69, 1, 2)],
        [key("Caps", 57, 1.75), key("A", 0), key("S", 1), key("D", 2), key("F", 3), key("G", 5), key("H", 4), key("J", 38), key("K", 40), key("L", 37), key(";", 41), key("'", 39), key("Enter", 36, 2.25), gap(4), key("4", 86), key("5", 87), key("6", 88)],
        [key("Shift", 56, 2.25), key("Z", 6), key("X", 7), key("C", 8), key("V", 9), key("B", 11), key("N", 45), key("M", 46), key(",", 43), key(".", 47), key("/", 44), key("Shift", 60, 2.75), gap(1.5), key("↑", 126), gap(1.5), key("1", 83), key("2", 84), key("3", 85), key("Enter", 76, 1, 2)],
        [key("Ctrl", 59, 1.25), key("Cmd", 55, 1.25), key("Opt", 58, 1.25), key("Space", 49, 6.25), key("Opt", 61, 1.25), key("Cmd", 54, 1.25), key("Fn", 63, 1.25), key("Ctrl", 62, 1.25), gap(0.5), key("←", 123), key("↓", 125), key("→", 124), gap(0.5), key("0", 82, 2), key(".", 65)]
    ]))

    // 数字小键盘
    static let numpad = KeyboardPreset(name: "数字小键盘", keys: buildRows([
        [key("Num", 71), key("/", 75), key("*", 67), key("-", 78)],
        [key("7", 89), key("8", 91), key("9", 92), key("+", 69, 1, 2)],
        [key("4", 86), key("5", 87), key("6", 88)],
        [key("1", 83), key("2", 84), key("3", 85), key("Enter", 76, 1, 2)],
        [key("0", 82, 2), key(".", 65)]
    ]))

    // WASD 游戏区
    static let wasd = KeyboardPreset(name: "WASD 游戏区", keys: buildRows([
        [key("1", 18), key("2", 19), key("3", 20), key("4", 21), key("5", 23)],
        [key("Tab", 48, 1.5), key("Q", 12), key("W", 13), key("E", 14), key("R", 15)],
        [key("Caps", 57, 1.5), key("A", 0), key("S", 1), key("D", 2), key("F", 3), key("G", 5)],
        [key("Shift", 56, 2.5), key("Z", 6), key("X", 7), key("C", 8), key("V", 9)],
        [key("Ctrl", 59, 1.5), key("Space", 49, 4), key("Alt", 58, 1.5)]
    ]))

    // MOBA（QWER + 召唤师技能 + 装备）
    static let moba = KeyboardPreset(name: "MOBA", keys: buildRows([
        [key("1", 18), key("2", 19), key("3", 20), key("4", 21), key("5", 23), key("6", 22)],
        [key("Q", 12), key("W", 13), key("E", 14), key("R", 15), key("D", 2), key("F", 3)],
        [key("A", 0), key("S", 1), key("G", 5), key("B", 11), key("T", 17)],
        [key("Ctrl", 59, 1.5), key("Alt", 58, 1.5), key("Space", 49, 4)]
    ]))
}
