import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Hardware colourways (body / rubber pads / legends).
struct Colorway: Identifiable, Equatable {
    let id: String
    let name: String
    let body: Color
    let bodyHighlight: Color
    let rubber: Color          // keys + buttons
    let well: Color            // recessed trays
    let silkscreen: Color      // printed labels on the body
    let legendOff: Color       // unlit button legend
    let legendOn: Color
    let stripeOff: Color       // LED stripe in keys when off
    let swatch: Color

    static let black = Colorway(id: "black", name: "Black",
        body: Color(hex: 0x3f4040), bodyHighlight: Color(hex: 0x575858),
        rubber: Color(hex: 0x2a2a2a), well: Color(hex: 0x333535),
        silkscreen: Color(hex: 0xd2d2d2), legendOff: Color(hex: 0x6a6a6a), legendOn: .white,
        stripeOff: Color(hex: 0x8a8a8a), swatch: Color(hex: 0x3f4040))

    static let cream = Colorway(id: "cream", name: "Cream / Blue",
        body: Color(hex: 0xeeebe6), bodyHighlight: Color(hex: 0xfaf8f4),
        rubber: Color(hex: 0x577694), well: Color(hex: 0x4f6f8d),
        silkscreen: Color(hex: 0x2d2926), legendOff: Color(hex: 0xc9d6e2), legendOn: .white,
        stripeOff: Color(hex: 0x3b5570), swatch: Color(hex: 0x577694))

    static let lilac = Colorway(id: "lilac", name: "Lilac",
        body: Color(hex: 0xbc93cd), bodyHighlight: Color(hex: 0xcaa5d9),
        rubber: Color(hex: 0x776ba6), well: Color(hex: 0x7469ad),
        silkscreen: Color(hex: 0xffffff), legendOff: Color(hex: 0xe6e0f6), legendOn: .white,
        stripeOff: Color(hex: 0x3e365f), swatch: Color(hex: 0xbc93cd))

    static let orange = Colorway(id: "orange", name: "Orange",
        body: Color(hex: 0xe0662c), bodyHighlight: Color(hex: 0xec7a42),
        rubber: Color(hex: 0x8b4c40), well: Color(hex: 0x7f4438),
        silkscreen: Color(hex: 0x2b1a14), legendOff: Color(hex: 0xf1d5cc), legendOn: .white,
        stripeOff: Color(hex: 0x4c2820), swatch: Color(hex: 0xe0662c))

    static let mint = Colorway(id: "mint", name: "Black / Mint",
        body: Color(hex: 0x37363b), bodyHighlight: Color(hex: 0x48474d),
        rubber: Color(hex: 0x65c7b9), well: Color(hex: 0x5cb3a7),
        silkscreen: Color(hex: 0xd8d8d8), legendOff: Color(hex: 0x2a5650), legendOn: Color(hex: 0x0d2420),
        stripeOff: Color(hex: 0x2f6a62), swatch: Color(hex: 0x65c7b9))

    static let charcoal = Colorway(id: "charcoal", name: "Cream / Charcoal",
        body: Color(hex: 0xd3c8c0), bodyHighlight: Color(hex: 0xe2d9d2),
        rubber: Color(hex: 0x363a3d), well: Color(hex: 0x3a3e41),
        silkscreen: Color(hex: 0x2d2926), legendOff: Color(hex: 0x7c8084), legendOn: .white,
        stripeOff: Color(hex: 0x8a8d90), swatch: Color(hex: 0x363a3d))

    static let all: [Colorway] = [.black, .cream, .lilac, .orange, .mint, .charcoal]
}

/// On-device TFT palette (real-device look).
enum ScreenPalette {
    static let background = Color(hex: 0xa9dcf2)
    static let backgroundBottom = Color(hex: 0x9ed4ee)
    static let tile = Color(hex: 0x7fd5f2)
    static let tileHighlight = Color(hex: 0xc4f0ff)
    static let tileOutline = Color(hex: 0x3a7fa0)
    static let text = Color(hex: 0x1e3446)
    static let header = Color(hex: 0x2a3a48)
    static let divider = Color(hex: 0x6aa6c2)
    static let opBox = Color(hex: 0x78eef5)
    static let red = Color(hex: 0xd75f51)
    static let oscBackground = Color(hex: 0x24505f)
    static let oscBackground2 = Color(hex: 0x2f5a5e)
    static let oscTrace = Color(hex: 0xb4d27a)
    static let dialog = Color(hex: 0x24313a)
}

enum PanelFont {
    /// Variable-font helper (wght axis).
    static func variable(_ name: String, size: CGFloat, weight: CGFloat) -> Font {
        let wghtAxis = 0x77676874 // 'wght'
        let desc = UIFontDescriptor(fontAttributes: [
            .name: name,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [wghtAxis: weight],
        ])
        return Font(UIFont(descriptor: desc, size: size) as CTFont)
    }
    /// Squarish "techno" silkscreen font for panel labels.
    static func silkscreen(_ size: CGFloat) -> Font { .custom("Aldrich", size: size) }
    /// Bold squared legends on rubber buttons.
    static func legend(_ size: CGFloat) -> Font { variable("Orbitron", size: size, weight: 800) }
    /// Humanist sans used on the TFT.
    static func screen(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let w: CGFloat
        switch weight {
        case .bold, .heavy, .black: w = 750
        case .semibold: w = 650
        case .medium: w = 560
        default: w = 450
        }
        return variable("Nunito", size: size, weight: w)
    }
}
