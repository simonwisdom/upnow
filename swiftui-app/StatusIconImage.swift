import AppKit

enum StatusIconImage {
    static func make(for state: OnlineState, size points: CGFloat = 18) -> NSImage {
        let size = NSSize(width: points, height: points)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        rect.fill()

        switch state {
        case .online:
            // Green filled circle
            let circleRect = rect.insetBy(dx: 2.5, dy: 2.5)
            let path = NSBezierPath(ovalIn: circleRect)
            NSColor.systemGreen.setFill()
            path.fill()

        case .offline:
            // Red rounded square
            let squareRect = rect.insetBy(dx: 2.5, dy: 2.5)
            let path = NSBezierPath(roundedRect: squareRect, xRadius: 3, yRadius: 3)
            NSColor.systemRed.setFill()
            path.fill()

        case .captive:
            // Orange triangle
            let inset: CGFloat = 3
            let p = NSBezierPath()
            p.move(to: NSPoint(x: rect.midX, y: rect.maxY - inset))
            p.line(to: NSPoint(x: rect.maxX - inset, y: rect.minY + inset))
            p.line(to: NSPoint(x: rect.minX + inset, y: rect.minY + inset))
            p.close()
            NSColor.systemOrange.setFill()
            p.fill()

        case .checking:
            // Yellow ring with orange arc
            let ringRect = rect.insetBy(dx: 3, dy: 3)
            let ringPath = NSBezierPath(ovalIn: ringRect)
            ringPath.lineWidth = 2.5
            NSColor.systemYellow.setStroke()
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
            NSColor.systemOrange.setStroke()
            arcPath.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false // preserve our colors; avoid system tinting
        return image
    }
}
