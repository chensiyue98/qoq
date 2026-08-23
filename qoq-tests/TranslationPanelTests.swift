import AppKit
import SwiftUI

@main
@MainActor
enum TranslationPanelTests {
    static func main() {
        let controller = TranslationPanelController(model: TranslationModel())
        guard controller.window?.hidesOnDeactivate == false else {
            fputs("FAILED: 固定窗口必须禁止 NSPanel 在应用失活时自行隐藏\n", stderr)
            exit(1)
        }
        guard controller.window?.isOpaque == false,
              controller.window?.backgroundColor == .clear else {
            fputs("FAILED: 翻译窗口必须使用透明底层，才能单独控制背景材质\n", stderr)
            exit(1)
        }
        guard let titlebarControls = controller.window?.titlebarAccessoryViewControllers.first?.view,
              titlebarControls.frame.width > 74 else {
            fputs("FAILED: 右上角标题栏控件必须按实际内容测量，不能被旧的固定宽度裁切\n", stderr)
            exit(1)
        }
        guard let contentView = controller.window?.contentView,
              contentView.subviews.contains(where: { $0 is NSVisualEffectView }),
              contentView.subviews.contains(where: { $0 is NSHostingView<TranslationPanelView> }) else {
            fputs("FAILED: 毛玻璃层必须与 SwiftUI 内容并列放在窗口根容器中\n", stderr)
            exit(1)
        }
        guard TranslationAppearanceMode.automatic.colorScheme == nil,
              TranslationAppearanceMode.light.colorScheme == .light,
              TranslationAppearanceMode.dark.colorScheme == .dark else {
            fputs("FAILED: 外观模式没有映射到正确的颜色方案\n", stderr)
            exit(1)
        }
        guard TranslationBackgroundStyle.opacity(for: 0.35) == 0.35,
              TranslationBackgroundStyle.opacity(for: 0.8) == 0.8,
              TranslationBackgroundStyle.opacity(for: 1.0) == 1.0 else {
            fputs("FAILED: 背景组合层必须直接响应不透明度设置\n", stderr)
            exit(1)
        }
        let effectView = NSVisualEffectView()
        TranslationBackgroundStyle.configure(effectView, blur: .standard, opacity: 0.65)
        guard effectView.blendingMode == .behindWindow,
              effectView.state == .active,
              effectView.isHidden == false,
              effectView.alphaValue == 0.65 else {
            fputs("FAILED: 毛玻璃必须使用持续激活的 behindWindow 原生材质\n", stderr)
            exit(1)
        }
        let visibleFrame = NSRect(x: 100, y: 50, width: 1200, height: 800)
        let size = NSSize(width: 520, height: 390)
        let center = TranslationWindowPositioner.origin(
            for: .screenCenter,
            visibleFrame: visibleFrame,
            windowSize: size,
            pointer: NSPoint(x: 120, y: 80)
        )
        guard center == NSPoint(x: 440, y: 255) else {
            fputs("FAILED: 翻译窗口默认位置应为当前屏幕可用区域中央\n", stderr)
            exit(1)
        }
        let nearPointer = TranslationWindowPositioner.origin(
            for: .nearPointer,
            visibleFrame: visibleFrame,
            windowSize: size,
            pointer: NSPoint(x: 120, y: 80)
        )
        guard nearPointer == NSPoint(x: 100, y: 50) else {
            fputs("FAILED: 鼠标附近模式应确保窗口完整位于屏幕内\n", stderr)
            exit(1)
        }
        print("TranslationPanel tests passed")
    }
}
