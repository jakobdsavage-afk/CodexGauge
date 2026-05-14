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
              let rateLimits = event.payload?.rateLimits ?? event.payload?.info?.rateLimits,
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

    func observation(fromLogBody body: String, timestamp: Date) -> CodexRateLimitObservation? {
        guard body.contains("\"type\":\"codex.rate_limits\""),
              let jsonStart = body.range(of: "{\"type\":\"codex.rate_limits\"")?.lowerBound
        else {
            return nil
        }

        let json = extractJSONObject(from: body, startingAt: jsonStart)
        guard let data = json.data(using: .utf8),
              let event = try? decoder.decode(CodexRateLimitLogEvent.self, from: data),
              let primaryUsed = event.rateLimits.primary?.usedPercent,
              let secondaryUsed = event.rateLimits.secondary?.usedPercent
        else {
            return nil
        }

        return CodexRateLimitObservation(
            timestamp: timestamp,
            primaryUsedPercent: primaryUsed,
            secondaryUsedPercent: secondaryUsed,
            primaryWindowMinutes: event.rateLimits.primary?.windowMinutes,
            secondaryWindowMinutes: event.rateLimits.secondary?.windowMinutes
        )
    }

    private func parseDate(_ value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? plainFormatter.date(from: value)
    }

    private func extractJSONObject(from body: String, startingAt start: String.Index) -> String {
        var depth = 0
        var isEscaped = false
        var isInsideString = false
        var end = start

        for index in body[start...].indices {
            let character = body[index]
            end = index

            if isEscaped {
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == "\"" {
                isInsideString.toggle()
                continue
            }

            guard !isInsideString else {
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1

                if depth == 0 {
                    break
                }
            }
        }

        return String(body[start...end])
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
    let rateLimits: CodexRateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case info
        case rateLimits = "rate_limits"
    }
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

private struct CodexRateLimitLogEvent: Decodable {
    let type: String
    let rateLimits: CodexRateLimits

    enum CodingKeys: String, CodingKey {
        case type
        case rateLimits = "rate_limits"
    }
}

private struct CodexRateLimitBucket: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
    }
}
