import Foundation

enum ProviderStatus: Equatable {
    case loading
    case exact(String)
    case estimated(String)
    case unavailable(String)

    var message: String {
        switch self {
        case .loading:
            "Looking for local Codex signals..."
        case .exact(let message), .estimated(let message), .unavailable(let message):
            message
        }
    }
}

struct UsageSnapshot: Equatable {
    /// Percent used in the active Codex primary bucket.
    ///
    /// The UI displays the inverse as "Daily remaining" because Codex local
    /// session telemetry reports `used_percent`, not remaining percent.
    let dailyUsagePercent: Double

    /// Percent used in the active Codex secondary bucket.
    ///
    /// In current Codex local telemetry this usually corresponds to the
    /// longer 10,080 minute window, so the widget labels it as weekly.
    let weeklyUsagePercent: Double

    let lastUpdated: Date
    let providerStatus: ProviderStatus
    let isEstimated: Bool

    var dailyRemainingPercent: Double {
        Self.clampPercent(100 - dailyUsagePercent)
    }

    var weeklyRemainingPercent: Double {
        Self.clampPercent(100 - weeklyUsagePercent)
    }

    static let loading = UsageSnapshot(
        dailyUsagePercent: 0,
        weeklyUsagePercent: 0,
        lastUpdated: Date(),
        providerStatus: .loading,
        isEstimated: true
    )

    static func clampPercent(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}
