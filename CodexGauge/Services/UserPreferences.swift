import AppKit
import Combine
import Foundation

@MainActor
final class UserPreferences: ObservableObject {
    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    @Published var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        self.panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? 0.92
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }

    func loadFrame() -> CGRect? {
        guard let string = defaults.string(forKey: Keys.windowFrame) else {
            return nil
        }

        return NSRectFromString(string)
    }

    func saveFrame(_ frame: CGRect) {
        defaults.set(NSStringFromRect(frame), forKey: Keys.windowFrame)
    }
}

private enum Keys {
    static let alwaysOnTop = "alwaysOnTop"
    static let panelOpacity = "panelOpacity"
    static let launchAtLogin = "launchAtLogin"
    static let windowFrame = "windowFrame"
}
