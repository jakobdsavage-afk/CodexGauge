import SwiftUI

struct SketchBackground: View {
    @EnvironmentObject private var preferences: UserPreferences

    let phase: Double

    var body: some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 11, dy: 11)

            let paper = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    palette.paperLift.opacity(0.98),
                    palette.paper.opacity(0.98),
                    palette.paperGroove.opacity(0.98)
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )

            context.fill(
                Path(roundedRect: rect, cornerRadius: 16),
                with: paper
            )

            var leftBinding = Path()
            leftBinding.move(to: CGPoint(x: rect.minX + 10, y: rect.minY + 18))
            leftBinding.addLine(to: CGPoint(x: rect.minX + 10 + wobble(4, phase), y: rect.maxY - 18))
            context.stroke(
                leftBinding,
                with: .color(palette.ink.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )

            for layer in 0..<3 {
                var path = Path()
                roughRoundedRect(
                    rect: rect.insetBy(dx: CGFloat(layer) * 1.4, dy: CGFloat(layer) * 1.1),
                    radius: 16,
                    phase: phase + Double(layer) * 0.43,
                    into: &path
                )

                context.stroke(
                    path,
                    with: .color(palette.ink.opacity(layer == 0 ? 0.82 : 0.26)),
                    style: StrokeStyle(lineWidth: layer == 0 ? 1.55 : 0.8, lineCap: .round, lineJoin: .round)
                )
            }

            for y in stride(from: rect.minY + 46, through: rect.maxY - 22, by: 33) {
                var line = Path()
                line.move(to: CGPoint(x: rect.minX + 20, y: y + wobble(y, phase) * 0.6))
                line.addLine(to: CGPoint(x: rect.maxX - 12, y: y + wobble(y + 8, phase) * 0.6))
                context.stroke(line, with: .color(palette.dimInk.opacity(0.08)), lineWidth: 0.7)
            }
        }
    }

    private func roughRoundedRect(rect: CGRect, radius: CGFloat, phase: Double, into path: inout Path) {
        let points = 18
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: CGPoint(x: minX + radius, y: minY + wobble(1, phase)))

        for index in 0...points {
            let t = CGFloat(index) / CGFloat(points)
            path.addLine(to: CGPoint(x: minX + radius + (maxX - minX - radius * 2) * t, y: minY + wobble(Double(index), phase)))
        }

        addCorner(center: CGPoint(x: maxX - radius, y: minY + radius), start: -.pi / 2, end: 0, phase: phase, path: &path)

        for index in 0...points {
            let t = CGFloat(index) / CGFloat(points)
            path.addLine(to: CGPoint(x: maxX + wobble(Double(index + 20), phase), y: minY + radius + (maxY - minY - radius * 2) * t))
        }

        addCorner(center: CGPoint(x: maxX - radius, y: maxY - radius), start: 0, end: .pi / 2, phase: phase, path: &path)

        for index in 0...points {
            let t = CGFloat(index) / CGFloat(points)
            path.addLine(to: CGPoint(x: maxX - radius - (maxX - minX - radius * 2) * t, y: maxY + wobble(Double(index + 40), phase)))
        }

        addCorner(center: CGPoint(x: minX + radius, y: maxY - radius), start: .pi / 2, end: .pi, phase: phase, path: &path)

        for index in 0...points {
            let t = CGFloat(index) / CGFloat(points)
            path.addLine(to: CGPoint(x: minX + wobble(Double(index + 60), phase), y: maxY - radius - (maxY - minY - radius * 2) * t))
        }

        addCorner(center: CGPoint(x: minX + radius, y: minY + radius), start: .pi, end: .pi * 1.5, phase: phase, path: &path)
    }

    private func addCorner(center: CGPoint, start: CGFloat, end: CGFloat, phase: Double, path: inout Path) {
        let steps = 8
        let radius: CGFloat = 16

        for index in 0...steps {
            let t = CGFloat(index) / CGFloat(steps)
            let angle = start + (end - start) * t
            let jitter = wobble(Double(index) + Double(angle), phase)
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * (radius + jitter),
                y: center.y + sin(angle) * (radius + jitter)
            ))
        }
    }

    private func wobble(_ seed: Double, _ phase: Double) -> CGFloat {
        CGFloat(sin(seed * 1.73 + phase * 3.1) * 0.9 + cos(seed * 0.73 + phase) * 0.45)
    }
}
