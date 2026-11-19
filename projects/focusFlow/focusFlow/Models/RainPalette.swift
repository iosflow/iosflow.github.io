import SwiftUI

struct RainPalette {
    let blue: Color
    let highlight: Color
    let depth: Color
    let opacity: Double
    static func forTexture(_ name: String) -> RainPalette {
        switch name {
        case "Soft": return .init(blue: Color(red: 0.08, green: 0.26, blue: 0.48), highlight: Color(red: 0.48, green: 0.70, blue: 0.90), depth: Color(red: 0.02, green: 0.08, blue: 0.18), opacity: 0.48)
        case "Heavy": return .init(blue: Color(red: 0.035, green: 0.09, blue: 0.28), highlight: Color(red: 0.38, green: 0.52, blue: 0.82), depth: Color(red: 0.008, green: 0.02, blue: 0.08), opacity: 0.62)
        default: return .init(blue: Color(red: 0.05, green: 0.17, blue: 0.42), highlight: Color(red: 0.42, green: 0.64, blue: 0.90), depth: Color(red: 0.012, green: 0.05, blue: 0.16), opacity: 0.54)
        }
    }
}
