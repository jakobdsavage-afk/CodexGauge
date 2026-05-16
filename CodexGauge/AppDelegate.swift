import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = UserPreferences()
    private let refreshService = UsageRefreshService(provider: CodexProvider())
    private let loginItemManager = LoginItemManager()
    private let updaterService = UpdaterService()
    private var panelController: FloatingPanelController?
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = FloatingPanelController(
            preferences: preferences,
            refreshService: refreshService
        )
        panelController = controller

        configureStatusItem()
        bindLoginPreference()
        bindMenuPreferences()
        refreshService.start()
        controller.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshService.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent", accessibilityDescription: "Codex Gauge")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.menu = makeStatusMenu()

        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide Codex Gauge", action: #selector(togglePanel), keyEquivalent: "g"))
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())

        let pinMenu = NSMenu()
        for mode in GaugePinMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(setPinMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.state = preferences.pinMode == mode ? .on : .off
            pinMenu.addItem(item)
        }
        let pinItem = NSMenuItem(title: "Pin Mode", action: nil, keyEquivalent: "")
        pinItem.submenu = pinMenu
        menu.addItem(pinItem)

        let appearanceMenu = NSMenu()
        let themeMenu = NSMenu()
        for theme in GaugeTheme.allCases {
            let item = NSMenuItem(title: theme.title, action: #selector(setTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.rawValue
            item.state = preferences.theme == theme ? .on : .off
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        appearanceMenu.addItem(themeItem)

        let sizeMenu = NSMenu()
        for mode in GaugeWidgetSizeMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(setWidgetSize(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.state = preferences.widgetSizeMode == mode ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Widget Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        appearanceMenu.addItem(sizeItem)

        let textItem = NSMenuItem(title: preferences.useHandwrittenFont ? "Use Clean Font" : "Use Handwritten Font", action: #selector(toggleTextStyle), keyEquivalent: "f")
        appearanceMenu.addItem(textItem)
        appearanceMenu.addItem(NSMenuItem(title: "About Data Source", action: #selector(showDataSourceInfo), keyEquivalent: "i"))

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "l")
        loginItem.state = preferences.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    private func bindLoginPreference() {
        preferences.$launchAtLogin
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else {
                    return
                }

                let success = self.loginItemManager.setEnabled(enabled)
                if !success {
                    self.preferences.launchAtLogin = false
                }
                self.refreshMenuStates()
            }
            .store(in: &cancellables)
    }

    private func bindMenuPreferences() {
        preferences.$theme
            .dropFirst()
            .sink { [weak self] _ in self?.refreshMenuStates() }
            .store(in: &cancellables)

        preferences.$widgetSizeMode
            .dropFirst()
            .sink { [weak self] _ in self?.refreshMenuStates() }
            .store(in: &cancellables)

        preferences.$pinMode
            .dropFirst()
            .sink { [weak self] _ in self?.refreshMenuStates() }
            .store(in: &cancellables)

        preferences.$useHandwrittenFont
            .dropFirst()
            .sink { [weak self] _ in self?.refreshMenuStates() }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    @objc private func togglePanel() {
        panelController?.toggleVisibility()
    }

    @objc private func refreshNow() {
        Task { await refreshService.refreshNow() }
    }

    @objc private func checkForUpdates() {
        updaterService.checkForUpdates()
    }

    @objc private func toggleAlwaysOnTop() {
        preferences.alwaysOnTop.toggle()
        refreshMenuStates()
    }

    @objc private func setPinMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = GaugePinMode(rawValue: rawValue)
        else {
            return
        }

        preferences.pinMode = mode
        refreshMenuStates()
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let theme = GaugeTheme(rawValue: rawValue)
        else {
            return
        }

        preferences.theme = theme
        refreshMenuStates()
    }

    @objc private func setWidgetSize(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = GaugeWidgetSizeMode(rawValue: rawValue)
        else {
            return
        }

        preferences.widgetSizeMode = mode
        refreshMenuStates()
    }

    @objc private func toggleTextStyle() {
        preferences.useHandwrittenFont.toggle()
        refreshMenuStates()
    }

    @objc private func showDataSourceInfo() {
        preferences.hasSeenIntro = false
        panelController?.show()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
        refreshMenuStates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refreshMenuStates() {
        statusItem?.menu = makeStatusMenu()
    }
}
