import Foundation

@main
enum ChineseVariantConverterTests {
    static func main() {
        assertEqual(
            ChineseVariantConverter.convert(
                "繁體中文無法翻譯，軟體與網路",
                sourceLanguage: "zh-Hant",
                targetLanguage: "zh-Hans"
            ),
            "繁体中文无法翻译，软体与网路",
            "繁体中文应转换为简体中文"
        )
        assertEqual(
            ChineseVariantConverter.convert(
                "简体中文无法翻译，软件与网络",
                sourceLanguage: "zh-Hans",
                targetLanguage: "zh-Hant"
            ),
            "簡體中文無法翻譯，軟件與網絡",
            "简体中文应转换为繁体中文"
        )
        guard ChineseVariantConverter.convert(
            "Hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        ) == nil else {
            fputs("FAILED: 非繁简互转应继续使用 Translation framework\n", stderr)
            exit(1)
        }
        print("ChineseVariantConverter tests passed")
    }

    private static func assertEqual(_ actual: String?, _ expected: String, _ message: String) {
        guard actual == expected else {
            fputs("FAILED: \(message)\nexpected: \(expected)\nactual:   \(actual ?? "nil")\n", stderr)
            exit(1)
        }
    }
}
