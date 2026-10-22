// Renders Resources/AppIcon.icns: dark rounded square with two toggle pills.
// Run: swift scripts/make-icon.swift
import AppKit

func render(_ size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024
    let inset = 100 * s
    let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let bg = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.21, alpha: 1),
                        NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)])!.draw(in: bg, angle: -90)

    func pill(y: CGFloat, on: Bool) {
        let w = 560 * s, h = 230 * s
        let r = NSRect(x: (size - w) / 2, y: y, width: w, height: h)
        (on ? NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.45, alpha: 1)
            : NSColor(calibratedWhite: 0.32, alpha: 1)).setFill()
        NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill()
        let k = h - 36 * s
        let kx = on ? r.maxX - k - 18 * s : r.minX + 18 * s
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: kx, y: y + 18 * s, width: k, height: k)).fill()
    }
    pill(y: 545 * s, on: true)
    pill(y: 250 * s, on: false)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let set = root.appendingPathComponent("build/AppIcon.iconset")
try? fm.removeItem(at: set)
try! fm.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(CGFloat(base)).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(CGFloat(base * 2)).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
