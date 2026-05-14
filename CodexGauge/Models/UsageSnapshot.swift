import Foundation

enum ProviderStatus: Equatable {
    case loading
    case exact(String)
    case unavailable(String)

    var message: String {
        switch self {
        case .loading:
            "Looking for local Codex signals..."
        case .exact(let message), .unavailable(let message):
            message
        }
    }
}

struct UsageSnapshot: Equatable {
    /// Percent used in the active Codex primary bucket.
    ///
    /// The UI displays the inverse as remaining percent because Codex local
    /// session telemetry reports `used_percent`, not remaining percent.
    let dailyUsagePercent: Double?

    /// Percent used in the active Codex secondary bucket.
    ///
    /// In current Codex local telemetry this usually corresponds to the
    /// longer 10,080 minute window, so the widget labels it as weekly.
    let weeklyUsagePercent: Double?

    let primaryWindowMinutes: Int?
    let secondaryWindowMinutes: Int?
    let lastUpdated: Date
    let providerStatus: ProviderStatus

    var hasUsageValues: Bool {
        dailyUsagePercent != nil && weeklyUsagePercent != nil
    }

    var dailyRemainingPercent: Double? {
        dailyUsagePercent.map { Self.clampPercent(100 - $0) }
    }

    var weeklyRemainingPercent: Double? {
        weeklyUsagePercent.map { Self.clampPercent(100 - $0) }
    }

    var primaryWindowLabel: String {
        Self.windowLabel(for: primaryWindowMinutes, fallback: "5h")
    }

    var secondaryWindowLabel: String {
        Self.windowLabel(for: secondaryWindowMinutes, fallback: "Weekly")
    }

    static let loading = UsageSnapshot(
        dailyUsagePercent: nil,
        weeklyUsagePercent: nil,
        primaryWindowMinutes: nil,
        secondaryWindowMinutes: nil,
        lastUpdated: Date(),
        providerStatus: .loading
    )

    static func clampPercent(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    static func windowLabel(for minutes: Int?, fallback: String) -> String {
        guard let minutes else {
            return fallback
        }

        switch minutes {
        case 300:
            return "5h"
        case 10_080:
            return "Weekly"
        case let value where value >= 1_440 && value % 1_440 == 0:
            return "\(value / 1_440)d"
        case let value where value >= 60 && value % 60 == 0:
            return "\(value / 60)h"
        default:
            return "\(minutes)m"
        }
    }
}
