import SwiftUI

struct SketchProgressBar: View {
    let value: Double
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 5)
            let progressWidth = rect.width * min(1, max(0, value / 100))

            for line in 0..<2 {
                var border = Path()
                let yOffset = CGFloat(line) * 0.9
                border.addRoundedRect(in: rect.offsetBy(dx: 0, dy: yOffset), cornerSize: CGSize(width: 5, height: 5))
                context.stroke(border, with: .color(NotebookTheme.ink.opacity(0.42)), lineWidth: 0.85)
            }

            guard progressWidth > 1 else {
                return
            }

            var fill = Path()
            let fillRect = CGRect(x: rect.minX + 2, y: rect.minY + 3, width: max(0, progressWidth - 4), height: rect.height - 6)

            for index in stride(from: fillRect.minY, through: fillRect.maxY, by: 3) {
                let jitter = sin(Double(index) * 0.9 + phase * 4) * 1.4
                fill.move(to: CGPoint(x: fillRect.minX, y: index + jitter))
                fill.addLine(to: CGPoint(x: fillRect.maxX, y: index - jitter * 0.4))
            }

            context.stroke(fill, with: .color(NotebookTheme.brightInk.opacity(0.82)), lineWidth: 1.25)
        }
        .frame(height: 20)
    }
}
