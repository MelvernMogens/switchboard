import AppKit

/// Menu-bar glyph: solid rounded tile with a vertical switch slot cut out, knob up.
/// Drawn in code as a template image so macOS tints it for light/dark/highlighted bars.
enum StatusIcon {
    static func make() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { b in
            NSColor.black.setFill()
            let tile = NSBezierPath(roundedRect: b.insetBy(dx: 1.5, dy: 1.5), xRadius: 4.5, yRadius: 4.5)
            let slot = NSBezierPath(roundedRect: NSRect(x: b.midX - 3, y: b.minY + 4.5, width: 6, height: 9),
                                    xRadius: 3, yRadius: 3)
            tile.append(slot.reversed)
            tile.fill()
            NSBezierPath(ovalIn: NSRect(x: b.midX - 2, y: b.minY + 8.5, width: 4, height: 4)).fill()
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Switchboard"
        return img
    }
}
