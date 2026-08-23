import AppKit

@main
@MainActor
enum TranslationPanelTests {
    static func main() {
        let controller = TranslationPanelController(model: TranslationModel())
        guard controller.window?.hidesOnDeactivate == false else {
            fputs("FAILED: 固定窗口必须禁止 NSPanel 在应用失活时自行隐藏\n", stderr)
            exit(1)
        }
        print("TranslationPanel tests passed")
    }
}
