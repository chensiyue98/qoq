import Foundation

@main
enum UpdateCheckerTests {
    static func main() {
        guard UpdateChecker.isNewer("v1.2.0", than: "1.1.9"),
              UpdateChecker.isNewer("2.0", than: "1.9.9"),
              !UpdateChecker.isNewer("v1.0.0", than: "1.0"),
              !UpdateChecker.isNewer("0.9.9", than: "1.0") else {
            fputs("FAILED: 更新检查器没有正确比较版本号\n", stderr)
            exit(1)
        }
        print("UpdateChecker tests passed")
    }
}
