import Foundation
import Translation

@main
enum OfflineLanguageManagerTests {
    static func main() {
        guard OfflineLanguageManager.strategy == .lowLatency else {
            fputs("FAILED: 离线语言管理必须检查逐语言下载的传统模型，而不是 Apple Intelligence 模型\n", stderr)
            exit(1)
        }
        print("OfflineLanguageManager tests passed")
    }
}
