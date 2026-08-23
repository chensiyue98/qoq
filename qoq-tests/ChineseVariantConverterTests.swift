import XCTest
@testable import QoQ

final class ChineseVariantConverterTests: XCTestCase {
    func testTraditionalToSimplified() {
        XCTAssertEqual(
            ChineseVariantConverter.convert("繁體中文無法翻譯，軟體與網路", sourceLanguage: "zh-Hant", targetLanguage: "zh-Hans"),
            "繁体中文无法翻译，软体与网路"
        )
    }

    func testSimplifiedToTraditional() {
        XCTAssertEqual(
            ChineseVariantConverter.convert("简体中文无法翻译，软件与网络", sourceLanguage: "zh-Hans", targetLanguage: "zh-Hant"),
            "簡體中文無法翻譯，軟件與網絡"
        )
    }

    func testUnrelatedLanguagesReturnNil() {
        XCTAssertNil(ChineseVariantConverter.convert("Hello", sourceLanguage: "en", targetLanguage: "zh-Hans"))
    }
}
