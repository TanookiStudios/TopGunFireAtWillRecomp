// make_icon.swift - draws the app icon: original pixel art (a jet seen from behind,
// banking over the ocean at dusk, afterburners lit), no artwork from the game.
//
//   swift tools/make_icon.swift <out.png> <size> [--full]
//
// Default: macOS icon layout (artwork inset in a rounded square, transparent
// margin). --full: artwork fills the square (Windows .ico).
import AppKit

let args = CommandLine.arguments
let outPath = args[1]
let size = Int(args[2])!
let full = args.contains("--full")

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

// 32 x 32 grid. Back to front: dusk sky bands, sun on the horizon, ocean, then the jet.
var grid = [[UInt32?]](repeating: [UInt32?](repeating: nil, count: 32), count: 32)
func fillRows(_ a: Int, _ b: Int, _ color: UInt32) { for r in a...b { for c in 0..<32 { grid[r][c] = color } } }

// Sky: deep blue at the top through purple and red to orange at the horizon.
let sky: [UInt32] = [0x141A4A, 0x141A4A, 0x1E1E5A, 0x1E1E5A, 0x2E2268, 0x2E2268, 0x46286E, 0x46286E,
                     0x642C6C, 0x642C6C, 0x862E62, 0xA43458, 0xC24050, 0xD8543E, 0xEA7034, 0xF48C2C,
                     0xFAAA30, 0xFCC444, 0xFCC444, 0xFCC444]
for (r, color) in sky.enumerated() { fillRows(r, r, color) }
// Sun: a half disc sitting on the horizon (rows 15-19).
for r in 13...19 { for c in 0..<32 {
    let dx = Double(c) + 0.5 - 7, dy = Double(r) + 0.5 - 20
    if dx * dx + dy * dy <= 30 { grid[r][c] = dx * dx + dy * dy <= 14 ? 0xFFF4C0 : 0xFFE07A }
} }
// Ocean (rows 20-31): dark teal with a column of sun glints.
fillRows(20, 31, 0x123A5C)
fillRows(20, 21, 0x1C5070)
fillRows(27, 31, 0x0C2A46)
for r in 20...31 {
    let half = max(1, 5 - (r - 20) / 3)
    for c in max(0, 7 - half)..<(7 + half) where (c + r) % 3 != 0 { grid[r][c] = r < 24 ? 0xFCC444 : 0xEA7034 }
}

// The jet, seen from behind and banking left. Built from simple shapes in an
// upright frame, then rotated; each grid cell samples the rotated frame.
func inEllipse(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
    let dx = (x - cx) / rx, dy = (y - cy) / ry
    return dx * dx + dy * dy <= 1
}
// Point inside the quad a-b-c-d (convex, in order).
func inQuad(_ x: Double, _ y: Double, _ q: [(Double, Double)]) -> Bool {
    var sign = 0.0
    for i in 0..<4 {
        let (ax, ay) = q[i], (bx, by) = q[(i + 1) % 4]
        let cross = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
        if cross != 0 { if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false } }
    }
    return true
}
// Part ids: 0 none, 1 body/wings, 2 canopy, 3 nozzle ring, 4 flame, 5 flame core, 6 tail.
func shape(_ x: Double, _ y: Double) -> Int {
    for ex in [14.3, 17.7] {
        if inEllipse(x, y, ex, 17.6, 0.9, 0.9) { return 5 }
        if inEllipse(x, y, ex, 17.6, 1.5, 1.5) { return 4 }
        if inEllipse(x, y, ex, 17.6, 2.0, 2.0) { return 3 }
    }
    if inEllipse(x, y, 16, 13.4, 1.6, 1.3) { return 2 }
    for s in [-1.0, 1.0] {
        let tail = [(16 + s * 1.2, 15.0), (16 + s * 3.4, 9.6), (16 + s * 5.2, 9.6), (16 + s * 3.4, 15.6)]
        if inQuad(x, y, tail.map { ($0.0, $0.1) }) { return 6 }
        let wing = [(16 + s * 2.5, 15.0), (16 + s * 10.2, 16.8), (16 + s * 10.2, 18.6), (16 + s * 2.5, 18.4)]
        if inQuad(x, y, wing.map { ($0.0, $0.1) }) { return 1 }
        let stab = [(16 + s * 2.5, 18.6), (16 + s * 6.6, 20.0), (16 + s * 6.6, 21.4), (16 + s * 2.5, 20.4)]
        if inQuad(x, y, stab.map { ($0.0, $0.1) }) { return 1 }
    }
    if inEllipse(x, y, 16, 16.4, 4.4, 3.1) { return 1 }
    return 0
}
let bank = -12.0 * Double.pi / 180
var parts = [[Int]](repeating: [Int](repeating: 0, count: 32), count: 32)
for r in 0..<32 { for c in 0..<32 {
    // Jet centered at column 17, row 11.5 of the icon, drawn 1.3x its frame size.
    let x = (Double(c) + 0.5 - 17) / 1.3, y = (Double(r) + 0.5 - 11.5) / 1.3
    let ux = x * cos(bank) + y * sin(bank) + 16, uy = -x * sin(bank) + y * cos(bank) + 16
    parts[r][c] = shape(ux, uy)
} }
func at(_ c: Int, _ r: Int) -> Int { (0..<32).contains(c) && (0..<32).contains(r) ? parts[r][c] : 0 }

let ink: UInt32 = 0x0E1024
let grayLight: UInt32 = 0xC8D0DC, gray: UInt32 = 0x8C96A8, grayShade: UInt32 = 0x5A6478
let glass: UInt32 = 0x7AD0F4, nozzle: UInt32 = 0x3A3E4C, flame: UInt32 = 0xFF8A20, core: UInt32 = 0xFFF6C8
for r in 0..<32 {
    for c in 0..<32 {
        let p = parts[r][c]
        if p == 0 { continue }
        if [at(c - 1, r), at(c + 1, r), at(c, r - 1), at(c, r + 1)].contains(0) && p != 5 && p != 4 {
            grid[r][c] = ink; continue
        }
        switch p {
        case 2: grid[r][c] = glass
        case 3: grid[r][c] = nozzle
        case 4: grid[r][c] = flame
        case 5: grid[r][c] = core
        default:
            // Light from the sunset below: lower cells lighter, upper ones in shade.
            let below = at(c, r + 1) == 0, above = at(c, r - 1) == 0
            grid[r][c] = below ? grayShade : (above ? grayLight : (p == 6 ? grayShade : gray))
        }
    }
}

// Render: whole pixels only, so the art stays crisp.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .none
ctx.shouldAntialias = false

let art = full ? CGFloat(size) : CGFloat(size) * 832 / 1024   // Apple's grid: 824-ish content in 1024
let cell = art / 32
let origin = (CGFloat(size) - art) / 2
let radius = art * (full ? 0.18 : 0.225)
let frame = NSRect(x: origin, y: origin, width: art, height: art)
ctx.shouldAntialias = true
NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
ctx.shouldAntialias = false
for r in 0..<32 {
    for c in 0..<32 {
        guard let color = grid[r][c] else { continue }
        rgb(color).setFill()
        // AppKit's y axis points up; row 0 is the top.
        let x = (origin + CGFloat(c) * cell).rounded(.down)
        let y = (origin + art - CGFloat(r + 1) * cell).rounded(.down)
        let x2 = (origin + CGFloat(c + 1) * cell).rounded(.down)
        let y2 = (origin + art - CGFloat(r) * cell).rounded(.down)
        NSRect(x: x, y: y, width: x2 - x, height: y2 - y).fill()
    }
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
