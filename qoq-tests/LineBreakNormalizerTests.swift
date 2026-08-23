import Foundation

@main
enum LineBreakNormalizerTests {
    static func main() {
        assertEqual(
            LineBreakNormalizer.normalize("这是第一行\n这是第二行", targetLanguage: "zh-Hans"),
            "这是第一行这是第二行",
            "CJK 单换行应直接合并"
        )
        assertEqual(
            LineBreakNormalizer.normalize("First line\nsecond line", targetLanguage: "en"),
            "First line second line",
            "拉丁语系单换行应以空格合并"
        )
        assertEqual(
            LineBreakNormalizer.normalize("第一段\n\n\n第二段", targetLanguage: "zh-Hans"),
            "第一段\n\n第二段",
            "多个空行应规范为一个段落间空行"
        )
        assertEqual(
            LineBreakNormalizer.normalize(
                "关于能源的更多信息\n\n动态能源\n\n可变能源合同\n\n防止回供成本",
                sourceText: "Meer over energie\nDynamische energie\nVariabel energiecontract\nTerugleverkosten voorkomen",
                targetLanguage: "zh-Hans"
            ),
            "关于能源的更多信息\n动态能源\n可变能源合同\n防止回供成本",
            "逐行原文的译文不应在每行之间插入空行"
        )
        assertEqual(
            LineBreakNormalizer.normalize(
                "第一段\n\n第二段",
                sourceText: "First paragraph\n\nSecond paragraph",
                targetLanguage: "zh-Hans"
            ),
            "第一段\n\n第二段",
            "原文中的段落空行应保留"
        )
        print("LineBreakNormalizer tests passed")
    }

    private static func assertEqual(_ actual: String, _ expected: String, _ message: String) {
        guard actual == expected else {
            fputs("FAILED: \(message)\nexpected: \(expected.debugDescription)\nactual:   \(actual.debugDescription)\n", stderr)
            exit(1)
        }
    }
}
