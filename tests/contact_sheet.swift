// Glue several screenshots into one labeled picture so a route can be checked at a glance.
//
//   swift tests/contact_sheet.swift out.png [columns] a.png b.png ...
//
// Each tile is 320x240 (PS1 pictures are scaled to fit), with the file name under it.
import AppKit

var args = Array(CommandLine.arguments.dropFirst())
let out = args.removeFirst()
let cols = Int(args.first ?? "") .map { _ in Int(args.removeFirst())! } ?? 5
let tw = 320, th = 240, label = 16
let rows = (args.count + cols - 1) / cols
let W = cols * tw, H = rows * (th + label)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                                            .foregroundColor: NSColor.white]
for (i, path) in args.enumerated() {
    let x = (i % cols) * tw, top = (i / cols) * (th + label)
    let y = H - top - th   // AppKit's y axis points up
    if let img = NSImage(contentsOfFile: path) {
        img.draw(in: NSRect(x: x, y: y, width: tw, height: th))
    } else {
        ("missing" as NSString).draw(at: NSPoint(x: x + 4, y: y + th / 2), withAttributes: attrs)
    }
    ((path as NSString).lastPathComponent as NSString).draw(at: NSPoint(x: x + 4, y: y - label + 2), withAttributes: attrs)
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
