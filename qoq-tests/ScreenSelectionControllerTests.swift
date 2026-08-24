import AppKit
import XCTest
@testable import QoQ

@MainActor
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

    func testScreenOperationAllowsOnlyOneActiveCapture() {
        let operation = ScreenOperationGate()

        XCTAssertTrue(operation.acquire())
        XCTAssertFalse(operation.acquire(), "重复快捷键触发不得启动第二个截图流程")

        operation.release()
        XCTAssertTrue(operation.acquire(), "截图和 OCR 完成后应允许再次触发")
    }
}
