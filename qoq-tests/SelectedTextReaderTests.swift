import XCTest
@testable import QoQ

final class SelectedTextReaderTests: XCTestCase {
    func testWaitsForDelayedPasteboardText() {
        var poll = 0
        let text = SelectedTextReader.waitForCopiedText(
            clearedChangeCount: 10,
            timeout: 0.1,
            changeCount: {
                poll += 1
                return poll >= 3 ? 11 : 10
            },
            string: { poll >= 6 ? "  Safari selection  " : nil },
            pumpEvents: { _ in }
        )

        XCTAssertEqual(text, "Safari selection")
    }
}
