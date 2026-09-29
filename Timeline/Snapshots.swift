import SwiftUI
import AppKit

/// Renders widget snapshots to PNG via `--render-snapshots <dir>`.
/// Used by scripts/render_snapshots.sh.
enum SnapshotRenderer {
    @MainActor
    static func renderAll(to dir: URL) async throws {
        Cormorant.registerFonts()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let size = CGSize(width: 329, height: 345)
        let cases: [(String, TimelineModel)] = [
            ("timeline", DemoData.model()),
            ("detail", DemoData.model(selected: true)),
            ("no-permission", .unavailable),
            ("empty-today", DemoData.emptyToday()),
        ]
        for (name, model) in cases {
            let view = StandaloneWidgetView(model: model)
                .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.proposedSize = .init(size)
            guard
                let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiff),
                let png = rep.representation(using: .png, properties: [:])
            else {
                throw SnapshotError.renderFailed(name)
            }
            let file = dir.appendingPathComponent("\(name).png")
            try png.write(to: file)
            print("wrote \(file.path)")
        }
    }

    enum SnapshotError: Error {
        case renderFailed(String)
    }
}
