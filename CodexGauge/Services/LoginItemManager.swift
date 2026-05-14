import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Codex Gauge login item update failed: \(error.localizedDescription)")
            return false
        }
    }
}
