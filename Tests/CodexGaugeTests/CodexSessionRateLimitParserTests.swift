import XCTest
@testable import CodexGauge

final class CodexSessionRateLimitParserTests: XCTestCase {
    func testParsesRateLimitSnapshotFromCodexSessionLine() throws {
        let parser = CodexSessionRateLimitParser()
        let line = """
        {"timestamp":"2026-05-14T19:09:55.330Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":1778803784},"secondary":{"used_percent":73.0,"window_minutes":10080,"resets_at":1778793145}}}}
        """

        let observation = try XCTUnwrap(parser.observation(fromJSONLine: line))

        XCTAssertEqual(observation.primaryUsedPercent, 12.5)
        XCTAssertEqual(observation.secondaryUsedPercent, 73.0)
        XCTAssertEqual(observation.primaryWindowMinutes, 300)
        XCTAssertEqual(observation.secondaryWindowMinutes, 10080)
    }

    func testParsesRateLimitSnapshotFromLogBody() throws {
        let parser = CodexSessionRateLimitParser()
        let body = #"websocket event: {"type":"codex.rate_limits","plan_type":"prolite","rate_limits":{"allowed":true,"limit_reached":false,"primary":{"used_percent":9,"window_minutes":300,"reset_after_seconds":16121,"reset_at":1778803787},"secondary":{"used_percent":74,"window_minutes":10080,"reset_after_seconds":5479,"reset_at":1778793145}}}"#

        let observation = try XCTUnwrap(parser.observation(fromLogBody: body, timestamp: Date(timeIntervalSince1970: 1_778_787_666)))

        XCTAssertEqual(observation.primaryUsedPercent, 9)
        XCTAssertEqual(observation.secondaryUsedPercent, 74)
        XCTAssertEqual(observation.primaryWindowMinutes, 300)
        XCTAssertEqual(observation.secondaryWindowMinutes, 10080)
    }

    func testIgnoresNonTokenCountLines() {
        let parser = CodexSessionRateLimitParser()
        let line = #"{"timestamp":"2026-05-14T19:09:55.330Z","type":"event_msg","payload":{"type":"agent_message","message":"hello"}}"#

        XCTAssertNil(parser.observation(fromJSONLine: line))
    }
}
