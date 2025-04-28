import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Zentrale Color(hex:) Extension für das gesamte Projekt
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        let length = hexSanitized.count
        let scanner = Scanner(string: hexSanitized)
        guard scanner.scanHexInt64(&rgb) else {
            self = Color.gray // fallback
            return
        }
        if length == 6 {
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self = Color(red: r, green: g, blue: b)
        } else if length == 8 {
            let a = Double((rgb & 0xFF000000) >> 24) / 255.0
            let r = Double((rgb & 0x00FF0000) >> 16) / 255.0
            let g = Double((rgb & 0x0000FF00) >> 8) / 255.0
            let b = Double(rgb & 0x000000FF) / 255.0
            self = Color(red: r, green: g, blue: b, opacity: a)
        } else {
            self = Color.gray // fallback
        }
    }

    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
        #else
        return nil
        #endif
    }
}
