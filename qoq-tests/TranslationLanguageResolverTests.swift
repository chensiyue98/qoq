import Foundation

@main
enum TranslationLanguageResolverTests {
    static func main() {
        assertEqual(
            TranslationLanguageResolver.target(
                sourceLanguage: "nl",
                preferredTargetLanguage: "zh-Hans",
                fallbackLanguage: "en"
            ),
            "zh-Hans",
            "检测语言不同时应使用默认目标语言"
        )
        assertEqual(
            TranslationLanguageResolver.target(
                sourceLanguage: "zh-Hans",
                preferredTargetLanguage: "zh-Hans",
                fallbackLanguage: "en"
            ),
            "en",
            "检测语言与目标语言一致时应使用候选语言"
        )
        assertEqual(
            TranslationLanguageResolver.target(
                sourceLanguage: "en",
                preferredTargetLanguage: "en",
                fallbackLanguage: "en"
            ),
            "zh-Hans",
            "候选语言仍相同时应选择另一种语言"
        )
        print("TranslationLanguageResolver tests passed")
    }

    private static func assertEqual(_ actual: String, _ expected: String, _ message: String) {
        guard actual == expected else {
            fputs("FAILED: \(message)\nexpected: \(expected)\nactual:   \(actual)\n", stderr)
            exit(1)
        }
    }
}
