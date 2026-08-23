import Foundation

@main
enum SelectedTextReaderTests {
    static func main() {
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

        guard text == "Safari selection" else {
            fputs("FAILED: 剪贴板已变化但文本延迟出现时仍应读取成功\n", stderr)
            exit(1)
        }
        print("SelectedTextReader tests passed")
    }
}
