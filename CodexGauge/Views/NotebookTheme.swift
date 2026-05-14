import SwiftUI

enum NotebookTheme {
    static let ink = Color(red: 0.48, green: 1.0, blue: 0.42)
    static let dimInk = Color(red: 0.21, green: 0.67, blue: 0.28)
    static let paper = Color(red: 0.025, green: 0.032, blue: 0.028)
    static let shadow = Color.black.opacity(0.52)
}

extension View {
    func notebookFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.custom("Noteworthy", size: size).weight(weight))
    }
}
