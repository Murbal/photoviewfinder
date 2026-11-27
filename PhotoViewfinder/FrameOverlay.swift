import SwiftUI

/// Darkens everything outside `rect` and draws frame lines, corner marks and an optional grid.
struct FrameOverlay: View {
    let rect: CGRect
    let maskOpacity: Double
    let showGrid: Bool

    var body: some View {
        Canvas { context, size in
            var mask = Path(CGRect(origin: .zero, size: size))
            mask.addRect(rect)
            context.fill(mask, with: .color(.black.opacity(maskOpacity)), style: FillStyle(eoFill: true))

            context.stroke(Path(rect), with: .color(.white.opacity(0.85)), lineWidth: 1)

            if showGrid {
                var grid = Path()
                for i in 1...2 {
                    let x = rect.minX + rect.width * CGFloat(i) / 3
                    let y = rect.minY + rect.height * CGFloat(i) / 3
                    grid.move(to: CGPoint(x: x, y: rect.minY))
                    grid.addLine(to: CGPoint(x: x, y: rect.maxY))
                    grid.move(to: CGPoint(x: rect.minX, y: y))
                    grid.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.35)), lineWidth: 0.75)
            }

            let arm = max(10, min(rect.width, rect.height) * 0.08)
            var corners = Path()
            for (corner, dx, dy) in [
                (CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0),
            ] {
                corners.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
                corners.addLine(to: corner)
                corners.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            }
            context.stroke(corners, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .square))

            let c = CGPoint(x: rect.midX, y: rect.midY)
            var cross = Path()
            cross.move(to: CGPoint(x: c.x - 8, y: c.y))
            cross.addLine(to: CGPoint(x: c.x + 8, y: c.y))
            cross.move(to: CGPoint(x: c.x, y: c.y - 8))
            cross.addLine(to: CGPoint(x: c.x, y: c.y + 8))
            context.stroke(cross, with: .color(.white.opacity(0.7)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
