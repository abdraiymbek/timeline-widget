import SwiftUI
import CoreText

// MARK: - Palette

enum Palette {
    static let voidBlack = Color(hex: 0x04060A)
    static let deepIndigo = Color(hex: 0x0C1020)
    static let ember = Color(hex: 0xD9733F)
    static let dustRose = Color(hex: 0xEDB891)
    static let earthlight = Color(hex: 0x6FB8D8)
    static let starlight = Color(hex: 0xF2EDE6)
    static let muted = Color(hex: 0x8D8A93)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Cormorant Garamond

enum Cormorant {
    enum Weight {
        case light, regular, medium, semibold, bold
    }

    /// Verified PostScript names from the bundled TTFs (Shared/Fonts).
    static func postScriptName(weight: Weight, italic: Bool) -> String {
        switch (weight, italic) {
        case (.light, false):    return "CormorantGaramond-Light"
        case (.light, true):     return "CormorantGaramond-Italic" // no LightItalic bundled
        case (.regular, false):  return "CormorantGaramond-Regular"
        case (.regular, true):   return "CormorantGaramond-Italic"
        case (.medium, false):   return "CormorantGaramond-Medium"
        case (.medium, true):    return "CormorantGaramond-MediumItalic"
        case (.semibold, false): return "CormorantGaramond-SemiBold"
        case (.semibold, true):  return "CormorantGaramond-SemiBoldItalic"
        case (.bold, _):         return "CormorantGaramond-Bold"   // no BoldItalic bundled
        }
    }

    /// Registers every bundled TTF with CoreText. `ATSApplicationFontsPath`
    /// already loads them; this is a safety net for contexts where it is ignored.
    static func registerFonts() {
        guard
            let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true),
            let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in urls where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static func cormorant(_ size: CGFloat, _ weight: Cormorant.Weight = .regular, italic: Bool = false) -> Font {
        .custom(Cormorant.postScriptName(weight: weight, italic: italic), size: size)
    }
}

// MARK: - Deterministic RNG (star field, marbling)

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next01() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next01() * (range.upperBound - range.lowerBound)
    }
}
