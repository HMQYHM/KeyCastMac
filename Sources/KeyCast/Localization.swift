import Foundation

enum AppLang: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

var currentLanguage: String = "zh-Hans"

func L(_ key: String) -> String {
    let table: [String: [String: String]] = [
        "type.keycap": ["zh-Hans": "按键", "zh-Hant": "按鍵", "en": "Key", "ja": "キー"],
        "type.mouse": ["zh-Hans": "鼠标", "zh-Hant": "滑鼠", "en": "Mouse", "ja": "マウス"],
        "type.gamepad": ["zh-Hans": "手柄", "zh-Hant": "手把", "en": "Gamepad", "ja": "ゲームパッド"],
        "type.gamepadButton": ["zh-Hans": "手柄按键", "zh-Hant": "手把按鍵", "en": "Pad Button", "ja": "パッドボタン"],
        "type.sequence": ["zh-Hans": "序列", "zh-Hant": "序列", "en": "Sequence", "ja": "シーケンス"],
        "type.waterfall": ["zh-Hans": "瀑布流", "zh-Hant": "瀑布流", "en": "Waterfall", "ja": "ウォーターフォール"],
        "type.displacement": ["zh-Hans": "位移", "zh-Hant": "位移", "en": "Displacement", "ja": "変位"],
        "type.wheel": ["zh-Hans": "滚轮", "zh-Hant": "滾輪", "en": "Wheel", "ja": "ホイール"],
        "type.text": ["zh-Hans": "文本输入框", "zh-Hant": "文字輸入框", "en": "Text Box", "ja": "テキストボックス"],
        "btn.left": ["zh-Hans": "左键", "zh-Hant": "左鍵", "en": "Left", "ja": "左ボタン"],
        "btn.right": ["zh-Hans": "右键", "zh-Hant": "右鍵", "en": "Right", "ja": "右ボタン"],
        "btn.middle": ["zh-Hans": "中键", "zh-Hant": "中鍵", "en": "Middle", "ja": "中ボタン"],
        "btn.side1": ["zh-Hans": "侧1", "zh-Hant": "側1", "en": "Side 1", "ja": "サイド1"],
        "btn.side2": ["zh-Hans": "侧2", "zh-Hant": "側2", "en": "Side 2", "ja": "サイド2"],
        "ui.canvas": ["zh-Hans": "画布", "zh-Hant": "畫布", "en": "Canvas", "ja": "キャンバス"],
        "ui.undo": ["zh-Hans": "撤回", "zh-Hant": "復原", "en": "Undo", "ja": "元に戻す"],
        "ui.clear": ["zh-Hans": "清空", "zh-Hant": "清除", "en": "Clear", "ja": "クリア"],
        "ui.fullscreen": ["zh-Hans": "全屏", "zh-Hant": "全螢幕", "en": "Fullscreen", "ja": "全画面"],
        "ui.snap": ["zh-Hans": "吸附对齐", "zh-Hant": "吸附對齊", "en": "Snap", "ja": "スナップ"],
        "ui.addKey": ["zh-Hans": "按键", "zh-Hant": "按鍵", "en": "Key", "ja": "キー"],
        "ui.presets": ["zh-Hans": "键盘配列", "zh-Hant": "鍵盤配列", "en": "Presets", "ja": "プリセット"],
        "ui.gamepad": ["zh-Hans": "手柄", "zh-Hant": "手把", "en": "Gamepad", "ja": "ゲームパッド"],
        "ui.widgetList": ["zh-Hans": "画布按键", "zh-Hant": "畫布按鍵", "en": "Canvas Keys", "ja": "キャンバスキー"],
        "ui.inspector": ["zh-Hans": "控件", "zh-Hant": "控件", "en": "Widget", "ja": "コントロール"],
        "ui.overlay": ["zh-Hans": "覆盖层", "zh-Hant": "覆蓋層", "en": "Overlay", "ja": "オーバーレイ"],
        "ui.appearance": ["zh-Hans": "外观", "zh-Hant": "外觀", "en": "Appearance", "ja": "外観"],
        "ui.system": ["zh-Hans": "系统", "zh-Hant": "系統", "en": "System", "ja": "システム"],
        "ui.config": ["zh-Hans": "配置", "zh-Hant": "配置", "en": "Profiles", "ja": "プロファイル"],
    ]
    return table[key]?[currentLanguage] ?? key
}
