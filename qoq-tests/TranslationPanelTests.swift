import AppKit
import SwiftUI
import XCTest
@testable import QoQ

@MainActor
final class TranslationPanelTests: XCTestCase {
    func testWindowAppearanceAndBehavior() throws {
        let controller = TranslationPanelController(model: TranslationModel())
        let window = try XCTUnwrap(controller.window)

        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertEqual(TranslationPanelController.defaultSize, NSSize(width: 520, height: 480))
        XCTAssertEqual(window.minSize, TranslationPanelController.minimumSize)
        XCTAssertGreaterThan(try XCTUnwrap(window.titlebarAccessoryViewControllers.first?.view).frame.width, 74)

        let contentView = try XCTUnwrap(window.contentView)
        XCTAssertTrue(contentView.subviews.contains { $0 is NSVisualEffectView })
        XCTAssertTrue(contentView.subviews.contains { $0 is NSHostingView<TranslationPanelView> })
    }

    func testAppearanceModeColorSchemes() {
        XCTAssertNil(TranslationAppearanceMode.automatic.colorScheme)
        XCTAssertEqual(TranslationAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(TranslationAppearanceMode.dark.colorScheme, .dark)
    }

    func testBackgroundStyle() {
        XCTAssertEqual(TranslationBackgroundStyle.opacity(for: 0.35), 0.35)
        XCTAssertEqual(TranslationBackgroundStyle.opacity(for: 0.8), 0.8)
        XCTAssertEqual(TranslationBackgroundStyle.opacity(for: 1.0), 1.0)

        let effectView = NSVisualEffectView()
        TranslationBackgroundStyle.configure(effectView, blur: .standard, opacity: 0.65)
        XCTAssertEqual(effectView.blendingMode, .behindWindow)
        XCTAssertEqual(effectView.state, .active)
        XCTAssertFalse(effectView.isHidden)
        XCTAssertEqual(effectView.alphaValue, 0.65)
    }

    func testWindowPositioning() {
        let visibleFrame = NSRect(x: 100, y: 50, width: 1200, height: 800)
        let size = NSSize(width: 520, height: 390)

        XCTAssertEqual(
            TranslationWindowPositioner.origin(for: .screenCenter, visibleFrame: visibleFrame, windowSize: size, pointer: NSPoint(x: 120, y: 80)),
            NSPoint(x: 440, y: 255)
        )
        XCTAssertEqual(
            TranslationWindowPositioner.origin(for: .nearPointer, visibleFrame: visibleFrame, windowSize: size, pointer: NSPoint(x: 120, y: 80)),
            NSPoint(x: 100, y: 50)
        )
    }
}
