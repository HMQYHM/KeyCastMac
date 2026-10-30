import SwiftUI
import AppKit
import CoreGraphics

enum KeyNameResolver {
    static func name(forCode code: Int, event: CGEvent?) -> String {
        if let special = KeyCodes.specialNames[code] { return special }
        if let event, let nse = NSEvent(cgEvent: event), let chars = nse.charactersIgnoringModifiers {
            let first = String(chars.prefix(1))
            if !first.isEmpty {
                let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let scalar = trimmed.unicodeScalars.first.map { $0.value } ?? 0
                    if scalar != 0x1B {
                        return trimmed.uppercased()
                    }
                }
            }
        }
        return "Key \(code)"
    }
}

enum Canvas {
    static func size(for setting: String) -> CGSize {
        let screen = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
        let f: CGFloat
        switch setting {
        case "full": f = 1.0
        case "quarter": f = 0.25
        default: f = 0.5
        }
        return CGSize(width: screen.width * f, height: screen.height * f)
    }
}

enum Helpers {
    static func rgba(hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        if h.count == 6 {
            return (CGFloat((n >> 16) & 0xFF) / 255,
                    CGFloat((n >> 8) & 0xFF) / 255,
                    CGFloat(n & 0xFF) / 255,
                    1)
        }
        return (CGFloat((n >> 24) & 0xFF) / 255,
                CGFloat((n >> 16) & 0xFF) / 255,
                CGFloat((n >> 8) & 0xFF) / 255,
                CGFloat(n & 0xFF) / 255)
    }

    static func nsColor(hex: String) -> NSColor {
        let c = rgba(hex: hex)
        return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }
}

extension Color {
    init(hex: String) {
        let c = Helpers.rgba(hex: hex)
        self.init(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a))
    }

    func toHex() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
