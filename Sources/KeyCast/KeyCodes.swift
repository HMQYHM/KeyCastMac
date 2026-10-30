import Foundation

enum KeyCodes {
    static let returnKey = 36
    static let tab = 48
    static let space = 49
    static let delete = 51
    static let escape = 53
    static let rightCommand = 54
    static let command = 55
    static let shift = 56
    static let capsLock = 57
    static let option = 58
    static let control = 59
    static let rightShift = 60
    static let rightOption = 61
    static let rightControl = 62
    static let function = 63
    static let f17 = 64
    static let volumeUp = 72
    static let volumeDown = 73
    static let mute = 74
    static let f18 = 79
    static let f19 = 80
    static let f20 = 90
    static let f1 = 122
    static let f2 = 120
    static let f3 = 99
    static let f4 = 118
    static let f5 = 96
    static let f6 = 97
    static let f7 = 98
    static let f8 = 100
    static let f9 = 101
    static let f10 = 109
    static let f11 = 103
    static let f12 = 111
    static let f13 = 105
    static let f14 = 107
    static let f15 = 113
    static let f16 = 106
    static let forwardDelete = 117
    static let home = 115
    static let end = 119
    static let pageUp = 116
    static let pageDown = 121
    static let leftArrow = 123
    static let rightArrow = 124
    static let downArrow = 125
    static let upArrow = 126
    static let keypad0 = 82
    static let keypad1 = 83
    static let keypad2 = 84
    static let keypad3 = 85
    static let keypad4 = 86
    static let keypad5 = 87
    static let keypad6 = 88
    static let keypad7 = 89
    static let keypad8 = 91
    static let keypad9 = 92
    static let keypadMultiply = 67
    static let keypadPlus = 69
    static let keypadClear = 71
    static let keypadDivide = 75
    static let keypadEnter = 76
    static let keypadMinus = 78
    static let keypadEquals = 81
    static let keypadDecimal = 65

    static let modifierCodes: Set<Int> = [command, rightCommand, shift, rightShift, option, rightOption, control, rightControl, capsLock, function]

    static let specialNames: [Int: String] = [
        returnKey: "Return",
        tab: "Tab",
        space: "Space",
        delete: "Delete",
        escape: "Esc",
        rightCommand: "Cmd",
        command: "Cmd",
        shift: "Shift",
        capsLock: "Caps",
        option: "Opt",
        control: "Ctrl",
        rightShift: "Shift",
        rightOption: "Opt",
        rightControl: "Ctrl",
        function: "Fn",
        f1: "F1", f2: "F2", f3: "F3", f4: "F4", f5: "F5", f6: "F6",
        f7: "F7", f8: "F8", f9: "F9", f10: "F10", f11: "F11", f12: "F12",
        f13: "F13", f14: "F14", f15: "F15", f16: "F16", f17: "F17", f18: "F18", f19: "F19", f20: "F20",
        forwardDelete: "Del",
        home: "Home", end: "End", pageUp: "PgUp", pageDown: "PgDn",
        leftArrow: "←", rightArrow: "→", downArrow: "↓", upArrow: "↑",
        keypad0: "Num0", keypad1: "Num1", keypad2: "Num2", keypad3: "Num3", keypad4: "Num4",
        keypad5: "Num5", keypad6: "Num6", keypad7: "Num7", keypad8: "Num8", keypad9: "Num9",
        keypadMultiply: "Num*", keypadPlus: "Num+", keypadClear: "Clear", keypadDivide: "Num/",
        keypadEnter: "NumEnter", keypadMinus: "Num-", keypadEquals: "Num=", keypadDecimal: "Num.",
        volumeUp: "Vol+", volumeDown: "Vol-", mute: "Mute",
    ]
}
