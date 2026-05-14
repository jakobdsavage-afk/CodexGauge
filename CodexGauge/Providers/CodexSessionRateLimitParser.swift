import Foundation

struct CodexRateLimitObservation: Equatable {
    let timestamp: Date
    let primaryUsedPercent: Double
    let secondaryUsedPercent: Double
    let primaryWindowMinutes: Int?
    let secondaryWindowMinutes: Int?
}

struct CodexSessionRateLimitParser: @unchecked Sendable {
    private let decoder: JSONDecoder
    private let fractionalFormatter: ISO8601DateFormatter
    private let plainFormatter: ISO8601DateFormatter

    init() {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.fractionalFormatter = fractionalFormatter

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        self.plainFormatter = plainFormatter

        self.decoder = JSONDecoder()
    }

    func observation(fromJSONLine line: String) -> CodexRateLimitObservation? {
        guard line.contains("\"rate_limits\""),
              let data = line.data(using: .utf8),
              let event = try? decoder.decode(CodexSessionEvent.self, from: data),
              event.payload?.type == "token_count",
              let info = event.payload?.info,
              let rateLimits = info.rateLimits,
              let primaryUsed = rateLimits.primary?.usedPercent,
              let secondaryUsed = rateLimits.secondary?.usedPercent,
              let timestamp = parseDate(event.timestamp)
        else {
            return nil
        }

        return CodexRateLimitObservation(
            timestamp: timestamp,
            primaryUsedPercent: primaryUsed,
            secondaryUsedPercent: secondaryUsed,
            primaryWindowMinutes: rateLimits.primary?.windowMinutes,
            secondaryWindowMinutes: rateLimits.secondary?.windowMinutes
        )
    }

    private func parseDate(_ value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? plainFormatter.date(from: value)
    }
}

private struct CodexSessionEvent: Decodable {
    let timestamp: String
    let type: String
    let payload: CodexSessionPayload?
}

private struct CodexSessionPayload: Decodable {
    let type: String?
    let info: CodexTokenInfo?
}

private struct CodexTokenInfo: Decodable {
    let rateLimits: CodexRateLimits?

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct CodexRateLimits: Decodable {
    let primary: CodexRateLimitBucket?
    let secondary: CodexRateLimitBucket?
}

private struct CodexRateLimitBucket: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
    }
}
