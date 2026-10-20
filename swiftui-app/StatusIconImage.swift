import AppKit

// Colours for each state. The colorblind palette swaps red/green for
// blue/orange (the pair most kinds of colour blindness can tell apart); the
// shapes already differ, so the colour is only a second cue.
enum StatusPalette {
    static let colorblindDefaultsKey = "colorblindFriendly"

    static func color(for state: OnlineState, colorblind: Bool) -> NSColor {
        switch state {
        case .online: return colorblind ? .systemBlue : .systemGreen
        case .offline: return colorblind ? .systemOrange : .systemRed
        case .captive: return colorblind ? .systemYellow : .systemOrange
        case .checking: return colorblind ? .systemGray : .systemYellow
        }
    }

    // The checking ring's arc.
    static func accent(colorblind: Bool) -> NSColor {
        colorblind ? .systemBlue : .systemOrange
    }

    static func emoji(for state: OnlineState, colorblind: Bool) -> String {
        switch state {
        case .online: return colorblind ? "🔵" : "🟢"
        case .offline: return colorblind ? "🟧" : "🟥"
        case .checking: return colorblind ? "⚪️" : "🟡"
        case .captive: return "⚠️"
        }
    }
}

enum StatusIconImage {
    static func make(for state: OnlineState, metered: Bool = false, colorblind: Bool = false,
                     size points: CGFloat = 18) -> NSImage {
        let size = NSSize(width: points, height: points)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        rect.fill()

        switch state {
        case .online:
            // Filled circle
            let circleRect = rect.insetBy(dx: 2.5, dy: 2.5)
            let path = NSBezierPath(ovalIn: circleRect)
            StatusPalette.color(for: state, colorblind: colorblind).setFill()
            path.fill()

        case .offline:
            // Rounded square
            let squareRect = rect.insetBy(dx: 2.5, dy: 2.5)
            let path = NSBezierPath(roundedRect: squareRect, xRadius: 3, yRadius: 3)
            StatusPalette.color(for: state, colorblind: colorblind).setFill()
            path.fill()

        case .captive:
            // Triangle
            let inset: CGFloat = 3
            let p = NSBezierPath()
            p.move(to: NSPoint(x: rect.midX, y: rect.maxY - inset))
            p.line(to: NSPoint(x: rect.maxX - inset, y: rect.minY + inset))
            p.line(to: NSPoint(x: rect.minX + inset, y: rect.minY + inset))
            p.close()
            StatusPalette.color(for: state, colorblind: colorblind).setFill()
            p.fill()

        case .checking:
            // Ring with an accent arc
            let ringRect = rect.insetBy(dx: 3, dy: 3)
            let ringPath = NSBezierPath(ovalIn: ringRect)
            ringPath.lineWidth = 2.5
            StatusPalette.color(for: state, colorblind: colorblind).setStroke()
            ringPath.stroke()

            // Arc (approx 220 degrees)
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = min(ringRect.width, ringRect.height) / 2
            let arcPath = NSBezierPath()
            arcPath.lineWidth = 2.5
            arcPath.lineCapStyle = .round
            let startAngle: CGFloat = -90 // top
            let endAngle: CGFloat = 130
            arcPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
            StatusPalette.accent(colorblind: colorblind).setStroke()
            arcPath.stroke()
        }

        // Hotspot/metered badge: small orange dot (orange stands out against
        // both palettes' online colour) at bottom-right, with a
        // punched-out gap so it reads against any of the state glyphs.
        if metered, let cg = NSGraphicsContext.current?.cgContext {
            let diameter: CGFloat = 7
            let badge = CGRect(x: size.width - diameter, y: 0, width: diameter, height: diameter)
            cg.setBlendMode(.clear)
            cg.fillEllipse(in: badge.insetBy(dx: -1.5, dy: -1.5))
            cg.setBlendMode(.normal)
            cg.setFillColor(NSColor.systemOrange.cgColor)
            cg.fillEllipse(in: badge)
        }

        image.unlockFocus()
        image.isTemplate = false // preserve our colors; avoid system tinting
        return image
    }
}
