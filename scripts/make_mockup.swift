// Composites the timeline snapshot onto the user's wallpaper for a mockup.
// Usage: xcrun swift scripts/make_mockup.swift <wallpaper> <widget.png> <out.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: make_mockup.swift <wallpaper> <widget.png> <out.png>\n".data(using: .utf8)!)
    exit(2)
}

let (wallpaperPath, widgetPath, outPath) = (args[1], args[2], args[3])

guard
    let wallpaper = NSImage(contentsOfFile: wallpaperPath),
    let widget = NSImage(contentsOfFile: widgetPath)
else {
    FileHandle.standardError.write("could not load input images\n".data(using: .utf8)!)
    exit(1)
}

// Canvas: wallpaper upscaled to 2048-wide for a crisp mockup.
let scale: CGFloat = 2048 / wallpaper.size.width
let canvasSize = NSSize(width: 2048, height: wallpaper.size.height * scale)

let output = NSImage(size: canvasSize)
output.lockFocus()

// Wallpaper, stretched to fill.
wallpaper.draw(in: NSRect(origin: .zero, size: canvasSize))

// Widget rendered at its native 329x345pt @2x = 658x690px, then scaled to the
// canvas so it looks like a real desktop widget (~14% of screen width).
let widgetW: CGFloat = 300 * (canvasSize.width / 1512) // ~a 1512pt-wide desktop
let widgetH = widgetW * (345.0 / 329.0)
let margin: CGFloat = canvasSize.width * 0.045
let widgetRect = NSRect(
    x: canvasSize.width - widgetW - margin,
    y: canvasSize.height * 0.46,
    width: widgetW, height: widgetH
)

// Soft drop shadow behind the widget.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.set()
NSBezierPath(roundedRect: widgetRect, xRadius: widgetW * 0.065, yRadius: widgetW * 0.065).fill()
NSGraphicsContext.restoreGraphicsState()

// Widget image clipped to widget-like rounded corners.
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: widgetRect, xRadius: widgetW * 0.065, yRadius: widgetW * 0.065).addClip()
widget.draw(
    in: widgetRect,
    from: NSRect(origin: .zero, size: widget.size),
    operation: .sourceOver,
    fraction: 1
)
NSGraphicsContext.restoreGraphicsState()

output.unlockFocus()

guard
    let tiff = output.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("failed to encode png\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
