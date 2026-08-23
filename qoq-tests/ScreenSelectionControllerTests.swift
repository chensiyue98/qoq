import AppKit
import XCTest
@testable import QoQ

final class ScreenSelectionControllerTests: XCTestCase {
    func testOverlayWindowCanBecomeKey() {
        let window = SelectionOverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        XCTAssertTrue(window.canBecomeKey, "框选覆盖窗口必须能取得键盘焦点以接收 Esc")
    }
}
