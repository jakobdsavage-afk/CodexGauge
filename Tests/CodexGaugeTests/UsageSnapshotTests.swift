import XCTest
@testable import CodexGauge

final class UsageSnapshotTests: XCTestCase {
    func testUsesCodexWindowLabels() {
        XCTAssertEqual(UsageSnapshot.windowLabel(for: 300, fallback: "Primary"), "5h")
        XCTAssertEqual(UsageSnapshot.windowLabel(for: 10_080, fallback: "Secondary"), "Weekly")
        XCTAssertEqual(UsageSnapshot.windowLabel(for: 120, fallback: "Primary"), "2h")
        XCTAssertEqual(UsageSnapshot.windowLabel(for: 2_880, fallback: "Primary"), "2d")
        XCTAssertEqual(UsageSnapshot.windowLabel(for: 45, fallback: "Primary"), "45m")
        XCTAssertEqual(UsageSnapshot.windowLabel(for: nil, fallback: "Primary"), "Primary")
    }
}
