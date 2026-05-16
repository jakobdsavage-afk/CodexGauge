import AppKit
import Combine
import Foundation

@MainActor
final class UserPreferences: ObservableObject {
    @Published var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var theme: GaugeTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var widgetSizeMode: GaugeWidgetSizeMode {
        didSet { defaults.set(widgetSizeMode.rawValue, forKey: Keys.widgetSizeMode) }
    }

    @Published var pinMode: GaugePinMode {
        didSet { defaults.set(pinMode.rawValue, forKey: Keys.pinMode) }
    }

    @Published var useHandwrittenFont: Bool {
        didSet { defaults.set(useHandwrittenFont, forKey: Keys.useHandwrittenFont) }
    }

    @Published var hasSeenIntro: Bool {
        didSet { defaults.set(hasSeenIntro, forKey: Keys.hasSeenIntro) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? 0.92
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.theme = GaugeTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .notebookGreen
        self.widgetSizeMode = GaugeWidgetSizeMode(rawValue: defaults.string(forKey: Keys.widgetSizeMode) ?? "") ?? .regular
        self.useHandwrittenFont = defaults.object(forKey: Keys.useHandwrittenFont) as? Bool ?? true
        self.hasSeenIntro = defaults.object(forKey: Keys.hasSeenIntro) as? Bool ?? false

        if let storedPinMode = GaugePinMode(rawValue: defaults.string(forKey: Keys.pinMode) ?? "") {
            self.pinMode = storedPinMode
        } else {
            let legacyAlwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
            self.pinMode = legacyAlwaysOnTop ? .floating : .desktop
        }
    }

    var alwaysOnTop: Bool {
        get { pinMode == .floating }
        set { pinMode = newValue ? .floating : .desktop }
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

enum GaugeTheme: String, CaseIterable, Identifiable {
    case notebookGreen
    case amberTerminal
    case blueLab
    case redAlert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notebookGreen:
            return "Notebook Green"
        case .amberTerminal:
            return "Amber Terminal"
        case .blueLab:
            return "Blue Lab"
        case .redAlert:
            return "Red Alert"
        }
    }
}

enum GaugeWidgetSizeMode: String, CaseIterable, Identifiable {
    case tiny
    case regular
    case expanded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .regular:
            return "Normal"
        case .expanded:
            return "Expanded"
        }
    }

    var size: CGSize {
        switch self {
        case .tiny:
            return CGSize(width: 328, height: 218)
        case .regular:
            return CGSize(width: 372, height: 248)
        case .expanded:
            return CGSize(width: 438, height: 292)
        }
    }
}

enum GaugePinMode: String, CaseIterable, Identifiable {
    case floating
    case desktop
    case menuBarOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .floating:
            return "Floating"
        case .desktop:
            return "Desktop"
        case .menuBarOnly:
            return "Menu Bar Only"
        }
    }

    var iconName: String {
        switch self {
        case .floating:
            return "pin.fill"
        case .desktop:
            return "macwindow"
        case .menuBarOnly:
            return "menubar.rectangle"
        }
    }
}

private enum Keys {
    static let alwaysOnTop = "alwaysOnTop"
    static let panelOpacity = "panelOpacity"
    static let launchAtLogin = "launchAtLogin"
    static let windowFrame = "windowFrame"
    static let theme = "theme"
    static let widgetSizeMode = "widgetSizeMode"
    static let pinMode = "pinMode"
    static let useHandwrittenFont = "useHandwrittenFont"
    static let hasSeenIntro = "hasSeenIntro"
}
