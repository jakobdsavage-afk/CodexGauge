import SwiftUI

struct GaugeRow: View {
    let label: String
    let percent: Double?
    let phase: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .notebookFont(size: 22, weight: .semibold)
                    .foregroundStyle(NotebookTheme.ink)

                Spacer()

                Text(percentText)
                    .notebookFont(size: 25, weight: .bold)
                    .foregroundStyle(NotebookTheme.ink)
                    .contentTransition(.numericText(value: percent ?? 0))
                    .shadow(color: NotebookTheme.ink.opacity(0.15), radius: 5)
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
