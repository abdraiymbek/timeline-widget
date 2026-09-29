import SwiftUI

// MARK: - Orb palettes

struct OrbColors {
    let light: Color
    let mid: Color
    let deep: Color
    let band: Color
}

extension OrbPalette {
    var colors: OrbColors {
        switch self {
        case .mars:
            return OrbColors(
                light: Color(hex: 0xEFA46F), mid: Palette.ember,
                deep: Color(hex: 0x53240F), band: Color(hex: 0x8A3B1E)
            )
        case .earth:
            return OrbColors(
                light: Color(hex: 0xA5D8EE), mid: Palette.earthlight,
                deep: Color(hex: 0x16344C), band: Color(hex: 0x3E7EA8)
            )
        case .gold:
            return OrbColors(
                light: Color(hex: 0xF6DCBE), mid: Palette.dustRose,
                deep: Color(hex: 0x7C4E2B), band: Color(hex: 0xC08A58)
            )
        case .graphite:
            return OrbColors(
                light: Color(hex: 0xBCB9C4), mid: Palette.muted,
                deep: Color(hex: 0x1E1D26), band: Color(hex: 0x565362)
            )
        }
    }
}

/// Small marbled "planet orb" node — radial base, tilted swirl bands,
/// specular highlight top-left, dark terminator bottom-right.
struct PlanetOrb: View {
    var palette: OrbPalette
    var size: Double
    var halo: Bool = false
    var glow: Bool = false

    var body: some View {
        let c = palette.colors
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [c.light, c.mid, c.deep],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: size * 0.05,
                    endRadius: size * 0.85
                ))
            Ellipse()
                .stroke(c.band.opacity(0.55), lineWidth: size * 0.13)
                .frame(width: size * 1.6, height: size * 0.60)
                .rotationEffect(.degrees(-22))
                .offset(y: size * 0.05)
                .blur(radius: size * 0.05)
            Ellipse()
                .stroke(c.deep.opacity(0.45), lineWidth: size * 0.09)
                .frame(width: size * 1.45, height: size * 0.40)
                .rotationEffect(.degrees(-22))
                .offset(y: size * 0.26)
                .blur(radius: size * 0.04)
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.26, height: size * 0.15)
                .rotationEffect(.degrees(-30))
                .offset(x: -size * 0.24, y: -size * 0.27)
                .blur(radius: size * 0.06)
            Circle()
                .fill(RadialGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    center: UnitPoint(x: 0.74, y: 0.78),
                    startRadius: size * 0.08,
                    endRadius: size * 0.62
                ))
        }
        .clipShape(Circle())
        .frame(width: size, height: size)
        .overlay {
            if halo {
                Circle()
                    .stroke(Palette.dustRose.opacity(0.4), lineWidth: 0.75)
                    .frame(width: size + 7, height: size + 7)
            }
        }
        .shadow(color: glow ? Palette.ember.opacity(0.55) : .clear, radius: size * 0.35)
    }
}
