import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = UserPreferences()
    private let refreshService = UsageRefreshService(provider: CodexProvider())
    private let loginItemManager = LoginItemManager()
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

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide Codex Gauge", action: #selector(togglePanel), keyEquivalent: "g"))
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        let topItem = NSMenuItem(title: "Always On Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "t")
        topItem.state = preferences.alwaysOnTop ? .on : .off
        menu.addItem(topItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "l")
        loginItem.state = preferences.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
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

    @objc private func statusItemClicked() {
        togglePanel()
    }

    @objc private func togglePanel() {
        panelController?.toggleVisibility()
    }

    @objc private func refreshNow() {
        Task { await refreshService.refreshNow() }
    }

    @objc private func toggleAlwaysOnTop() {
        preferences.alwaysOnTop.toggle()
        refreshMenuStates()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
        refreshMenuStates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refreshMenuStates() {
        guard let menu = statusItem?.menu else {
            return
        }

        menu.items.first(where: { $0.title == "Always On Top" })?.state = preferences.alwaysOnTop ? .on : .off
        menu.items.first(where: { $0.title == "Launch at Login" })?.state = preferences.launchAtLogin ? .on : .off
    }
}
