import Translation
import XCTest
@testable import QoQ

final class OfflineLanguageManagerTests: XCTestCase {
    func testUsesLowLatencyLanguageModelStrategy() {
        XCTAssertEqual(OfflineLanguageManager.strategy, .lowLatency)
    }
}
