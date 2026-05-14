import SwiftUI

enum NotebookTheme {
    static let ink = Color(red: 0.48, green: 1.0, blue: 0.42)
    static let brightInk = Color(red: 0.66, green: 1.0, blue: 0.58)
    static let dimInk = Color(red: 0.21, green: 0.67, blue: 0.28)
    static let paper = Color(red: 0.018, green: 0.024, blue: 0.021)
    static let paperLift = Color(red: 0.042, green: 0.055, blue: 0.048)
    static let paperGroove = Color(red: 0.008, green: 0.012, blue: 0.011)
    static let shadow = Color.black.opacity(0.52)
}

extension View {
    func notebookFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.custom("Noteworthy", size: size).weight(weight))
    }
}
