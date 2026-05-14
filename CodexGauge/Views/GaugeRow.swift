import SwiftUI

struct GaugeRow: View {
    let label: String
    let percent: Double?
    let phase: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .notebookFont(size: 20, weight: .semibold)
                    .foregroundStyle(NotebookTheme.brightInk.opacity(0.96))

                Spacer()

                Text(percentText)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(NotebookTheme.brightInk)
                    .contentTransition(.numericText(value: percent ?? 0))
                    .shadow(color: NotebookTheme.ink.opacity(0.18), radius: 5)
            }

            SketchProgressBar(value: percent ?? 0, phase: phase)
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
