import XCTest
@testable import QoQ

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("v1.2.0", than: "1.1.9"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0", than: "1.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("v1.0.0", than: "1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.9.9", than: "1.0"))
    }
}
