import Translation
import XCTest
@testable import QoQ

final class OfflineLanguageManagerTests: XCTestCase {
    @MainActor
    @available(macOS 26.4, *)
    func testUsesLowLatencyLanguageModelStrategy() {
        let strategy = OfflineLanguageManager.strategy
        XCTAssertEqual(strategy, .lowLatency)
    }
}
