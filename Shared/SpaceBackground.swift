import SwiftUI

/// Deep-space backdrop: indigo→void gradient, deterministic sparse star field,
/// fine grain, and one thin luminous orbital arc sweeping the lower right.
struct SpaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.deepIndigo, Palette.voidBlack],
                startPoint: .top, endPoint: .bottom
            )
            Canvas { context, size in
                var rng = SeededGenerator(seed: 0x54494D454C49)
                for _ in 0..<72 {
                    let x = rng.next01() * size.width
                    let y = rng.next01() * size.height
                    let bright = rng.next01()
                    let r = 0.5 + rng.next01() * 0.7
                    let opacity = bright > 0.93
                        ? rng.next(in: 0.55...0.85)
                        : rng.next(in: 0.10...0.34)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Palette.starlight.opacity(opacity))
                    )
                }
            }
            Canvas { context, size in
                // One thin luminous orbital arc, lower right — ember to earthlight.
                let center = CGPoint(x: size.width * 1.15, y: size.height * 1.02)
                let rx = size.width * 0.95
                let ry = size.height * 0.60
                var path = Path()
                var first = true
                for step in 0...90 {
                    let t = (190.0 + Double(step) * (110.0 / 90.0)) * .pi / 180
                    let p = CGPoint(
                        x: center.x + rx * cos(t),
                        y: center.y + ry * sin(t)
                    )
                    if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                }
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Palette.ember.opacity(0.55),
                            Palette.starlight.opacity(0.0),
                            Palette.earthlight.opacity(0.4),
                        ]),
                        startPoint: CGPoint(x: size.width * 0.15, y: size.height),
                        endPoint: CGPoint(x: size.width, y: size.height * 0.45)
                    ),
                    lineWidth: 0.75
                )
            }
            // Fine grain — two sparse speckle fields, barely-there.
            Canvas { context, size in
                var rng = SeededGenerator(seed: 0x47524149)
                for _ in 0..<300 {
                    let x = rng.next01() * size.width
                    let y = rng.next01() * size.height
                    let light = rng.next01() > 0.5
                    let rect = CGRect(x: x, y: y, width: 0.5, height: 0.5)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color((light ? Palette.starlight : Palette.voidBlack).opacity(0.04))
                    )
                }
            }
        }
    }
}
