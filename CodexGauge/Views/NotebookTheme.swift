import SwiftUI

enum NotebookTheme {
    static let shadow = Color.black.opacity(0.52)

    static func palette(for theme: GaugeTheme) -> NotebookPalette {
        switch theme {
        case .notebookGreen:
            return NotebookPalette(
                ink: Color(red: 0.48, green: 1.0, blue: 0.42),
                brightInk: Color(red: 0.66, green: 1.0, blue: 0.58),
                dimInk: Color(red: 0.21, green: 0.67, blue: 0.28),
                paper: Color(red: 0.018, green: 0.024, blue: 0.021),
                paperLift: Color(red: 0.042, green: 0.055, blue: 0.048),
                paperGroove: Color(red: 0.008, green: 0.012, blue: 0.011)
            )
        case .amberTerminal:
            return NotebookPalette(
                ink: Color(red: 1.0, green: 0.70, blue: 0.22),
                brightInk: Color(red: 1.0, green: 0.86, blue: 0.42),
                dimInk: Color(red: 0.73, green: 0.42, blue: 0.12),
                paper: Color(red: 0.035, green: 0.025, blue: 0.014),
                paperLift: Color(red: 0.073, green: 0.050, blue: 0.026),
                paperGroove: Color(red: 0.018, green: 0.012, blue: 0.008)
            )
        case .blueLab:
            return NotebookPalette(
                ink: Color(red: 0.36, green: 0.86, blue: 1.0),
                brightInk: Color(red: 0.62, green: 0.96, blue: 1.0),
                dimInk: Color(red: 0.18, green: 0.56, blue: 0.72),
                paper: Color(red: 0.014, green: 0.026, blue: 0.037),
                paperLift: Color(red: 0.031, green: 0.058, blue: 0.077),
                paperGroove: Color(red: 0.006, green: 0.013, blue: 0.020)
            )
        case .redAlert:
            return NotebookPalette(
                ink: Color(red: 1.0, green: 0.36, blue: 0.42),
                brightInk: Color(red: 1.0, green: 0.62, blue: 0.66),
                dimInk: Color(red: 0.72, green: 0.20, blue: 0.25),
                paper: Color(red: 0.033, green: 0.016, blue: 0.018),
                paperLift: Color(red: 0.068, green: 0.033, blue: 0.038),
                paperGroove: Color(red: 0.015, green: 0.007, blue: 0.009)
            )
        }
    }
}

struct NotebookPalette {
    let ink: Color
    let brightInk: Color
    let dimInk: Color
    let paper: Color
    let paperLift: Color
    let paperGroove: Color
}

extension View {
    func notebookFont(size: CGFloat, weight: Font.Weight = .regular, handwritten: Bool = true) -> some View {
        if handwritten {
            return self.font(.custom("Noteworthy", size: size).weight(weight))
        }

        return self.font(.system(size: size, weight: weight, design: .rounded))
    }
}
