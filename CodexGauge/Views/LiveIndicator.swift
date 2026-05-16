import AppKit
import SwiftUI

struct LiveIndicator: View {
    @EnvironmentObject private var preferences: UserPreferences

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = (sin(timeline.date.timeIntervalSinceReferenceDate * 3.1) + 1) / 2
            let palette = NotebookTheme.palette(for: preferences.theme)
            let dotColor = palette.dimInk.mix(with: palette.brightInk, by: pulse)

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.35 + pulse * 0.35), radius: 5 + pulse * 4)

                Text("Live")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.82))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(palette.paperGroove.opacity(0.72))
                    .overlay {
                        Capsule()
                            .stroke(palette.ink.opacity(0.22), lineWidth: 0.8)
                    }
            }
        }
    }
}

private extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let amount = min(1, max(0, amount))
        guard let left = NSColor(self).usingColorSpace(.deviceRGB),
              let right = NSColor(other).usingColorSpace(.deviceRGB)
        else {
            return amount < 0.5 ? self : other
        }

        return Color(
            red: left.redComponent + (right.redComponent - left.redComponent) * amount,
            green: left.greenComponent + (right.greenComponent - left.greenComponent) * amount,
            blue: left.blueComponent + (right.blueComponent - left.blueComponent) * amount,
            opacity: left.alphaComponent + (right.alphaComponent - left.alphaComponent) * amount
        )
    }
}
