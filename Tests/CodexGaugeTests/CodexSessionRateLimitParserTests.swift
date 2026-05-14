import XCTest
@testable import CodexGauge

final class CodexSessionRateLimitParserTests: XCTestCase {
    func testParsesRateLimitSnapshotFromCodexSessionLine() throws {
        let parser = CodexSessionRateLimitParser()
        let line = """
        {"timestamp":"2026-05-14T19:09:55.330Z","type":"event_msg","payload":{"type":"token_count","info":{"rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":1778803784},"secondary":{"used_percent":73.0,"window_minutes":10080,"resets_at":1778793145}}}}}
        """

        let observation = try XCTUnwrap(parser.observation(fromJSONLine: line))

        XCTAssertEqual(observation.primaryUsedPercent, 12.5)
        XCTAssertEqual(observation.secondaryUsedPercent, 73.0)
        XCTAssertEqual(observation.primaryWindowMinutes, 300)
        XCTAssertEqual(observation.secondaryWindowMinutes, 10080)
    }

    func testIgnoresNonTokenCountLines() {
        let parser = CodexSessionRateLimitParser()
        let line = #"{"timestamp":"2026-05-14T19:09:55.330Z","type":"event_msg","payload":{"type":"agent_message","message":"hello"}}"#

        XCTAssertNil(parser.observation(fromJSONLine: line))
    }
}
