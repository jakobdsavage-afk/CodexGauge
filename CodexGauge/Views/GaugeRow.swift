import SwiftUI

struct GaugeRow: View {
    let label: String
    let percent: Double
    let phase: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .notebookFont(size: 22, weight: .semibold)
                    .foregroundStyle(NotebookTheme.ink)

                Spacer()

                Text("\(Int(percent.rounded()))%")
                    .notebookFont(size: 25, weight: .bold)
                    .foregroundStyle(NotebookTheme.ink)
                    .contentTransition(.numericText(value: percent))
                    .shadow(color: NotebookTheme.ink.opacity(0.15), radius: 5)
            }

            SketchProgressBar(value: percent, phase: phase)
        }
    }
}
