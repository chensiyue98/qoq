import AppKit

@main
enum ScreenSelectionControllerTests {
    static func main() {
        let window = SelectionOverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        guard window.canBecomeKey else {
            fputs("FAILED: 框选覆盖窗口必须能取得键盘焦点以接收 Esc\n", stderr)
            exit(1)
        }
        print("ScreenSelectionController tests passed")
    }
}
