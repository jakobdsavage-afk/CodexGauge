import SwiftUI

struct GaugeRow: View {
    @EnvironmentObject private var preferences: UserPreferences

    let label: String
    let percent: Double?
    let phase: Double
    let labelSize: CGFloat
    let valueSize: CGFloat
    let barHeight: CGFloat

    var body: some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .notebookFont(size: labelSize, weight: .semibold, handwritten: preferences.useHandwrittenFont)
                    .foregroundStyle(palette.brightInk.opacity(0.96))

                Spacer()

                Text(percentText)
                    .font(.system(size: valueSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.brightInk)
                    .contentTransition(.numericText(value: percent ?? 0))
                    .shadow(color: palette.ink.opacity(0.18), radius: 5)
            }

            SketchProgressBar(value: percent ?? 0, phase: phase, height: barHeight)
                .opacity(percent == nil ? 0.28 : 1)
        }
    }

    private var percentText: String {
        guard let percent else {
            return "--"
        }

        return "\(Int(percent.rounded()))%"
    }
}
