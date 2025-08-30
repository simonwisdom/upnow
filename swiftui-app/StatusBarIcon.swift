import SwiftUI

struct StatusBarIcon: View {
    let state: OnlineState

    private let size: CGFloat = 18

    var body: some View {
        ZStack {
            switch state {
            case .online:
                // Solid circle = online (green)
                Circle()
                    .fill(Color.green)
            case .offline:
                // Solid square = offline (red)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.red)
            case .captive:
                // Orange triangle = captive portal/login required
                Triangle()
                    .fill(Color.orange)
            case .checking:
                // Ring = checking (yellow)
                Circle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.6)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(90))
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        // Render original colors (avoid template tinting in status bar)
        .compositingGroup()
        .drawingGroup()
    }
}

#if DEBUG
struct StatusBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatusBarIcon(state: .online)
            StatusBarIcon(state: .offline)
            StatusBarIcon(state: .captive)
            StatusBarIcon(state: .checking)
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + 2))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
        p.closeSubpath()
        return p
    }
}
