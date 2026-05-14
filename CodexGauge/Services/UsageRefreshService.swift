import Foundation
import SwiftUI

@MainActor
final class UsageRefreshService: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot = .loading
    @Published private(set) var isRefreshing = false

    private let provider: UsageProvider
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration = .seconds(15)

    init(provider: UsageProvider) {
        self.provider = provider
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            await refreshNow()

            while !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)
                await refreshNow()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow() async {
        isRefreshing = true
        let newSnapshot = await provider.fetchUsage()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            snapshot = newSnapshot
            isRefreshing = false
        }
    }
}
