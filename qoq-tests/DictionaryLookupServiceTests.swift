import Foundation

@main
@MainActor
enum DictionaryLookupServiceTests {
    static func main() {
        guard DictionaryLookupService.isEligible("serendipity") else {
            fail("短词应允许词典查询")
        }
        guard !DictionaryLookupService.isEligible(String(repeating: "a", count: 41)) else {
            fail("超过 40 个字符不应触发词典查询")
        }
        guard !DictionaryLookupService.isEligible("first line\nsecond line") else {
            fail("多行文本不应触发词典查询")
        }
        guard !DictionaryLookupService.isEligible("12345 !?") else {
            fail("纯数字和符号不应触发词典查询")
        }

        let model = TranslationModel(dictionaryLookup: { _ in "意外发现美好事物的能力或运气" })
        guard model.useDictionaryFallbackIfAvailable(for: "serendipity"),
              model.translatedText == "意外发现美好事物的能力或运气",
              model.outputTitle == "词典释义" else {
            fail("词典命中后应显示释义并明确标注结果类型")
        }

        model.dictionaryFallbackMode = DictionaryFallbackMode.disabled.rawValue
        guard !model.useDictionaryFallbackIfAvailable(for: "serendipity") else {
            fail("关闭备用词典后不应执行词典查询")
        }
        print("DictionaryLookupService tests passed")
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAILED: \(message)\n", stderr)
        exit(1)
    }
}
