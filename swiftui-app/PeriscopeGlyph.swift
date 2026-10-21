import AppKit

// A small periscope (the app icon's mascot) drawn in code, for the menu bar
// and menu. The tube follows the menu bar's text colour; the lens is green.
enum PeriscopeGlyph {
    static func make(size points: CGFloat = 18, colorblind: Bool = false) -> NSImage {
        let lensColor = StatusPalette.color(for: .online, colorblind: colorblind)
        let image = NSImage(size: NSSize(width: points, height: points), flipped: false) { rect in
            let u = rect.width / 18
            let tube = NSColor.labelColor.withAlphaComponent(0.85)
            tube.setFill()
            // Stem rising out of the water, then the head turning right.
            NSBezierPath(roundedRect: NSRect(x: 4 * u, y: 3 * u, width: 4.5 * u, height: 10 * u),
                         xRadius: 1.5 * u, yRadius: 1.5 * u).fill()
            NSBezierPath(roundedRect: NSRect(x: 4 * u, y: 9.5 * u, width: 9 * u, height: 6.5 * u),
                         xRadius: 2.5 * u, yRadius: 2.5 * u).fill()
            // The lens: a green disc set into the end of the head.
            let lens = NSRect(x: 10.5 * u, y: 9 * u, width: 7.5 * u, height: 7.5 * u)
            tube.setFill()
            NSBezierPath(ovalIn: lens).fill()
            lensColor.setFill()
            NSBezierPath(ovalIn: lens.insetBy(dx: 1.4 * u, dy: 1.4 * u)).fill()
            // One wave along the bottom, as in the app icon.
            let wave = NSBezierPath()
            wave.move(to: NSPoint(x: 0.5 * u, y: 2.5 * u))
            wave.curve(to: NSPoint(x: 9 * u, y: 2.5 * u),
                       controlPoint1: NSPoint(x: 3 * u, y: 5 * u), controlPoint2: NSPoint(x: 6.5 * u, y: 0))
            wave.curve(to: NSPoint(x: 17.5 * u, y: 2.5 * u),
                       controlPoint1: NSPoint(x: 11.5 * u, y: 5 * u), controlPoint2: NSPoint(x: 15 * u, y: 0))
            wave.lineWidth = 1.6 * u
            wave.lineCapStyle = .round
            NSColor.systemBlue.setStroke()
            wave.stroke()
            return true
        }
        return image
    }
}
