import Foundation

protocol UsageProvider: Sendable {
    func fetchUsage() async -> UsageSnapshot
}
