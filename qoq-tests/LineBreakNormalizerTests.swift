import XCTest
@testable import QoQ

final class LineBreakNormalizerTests: XCTestCase {
    func testCJKSingleLineBreakIsRemoved() {
        XCTAssertEqual(LineBreakNormalizer.normalize("这是第一行\n这是第二行", targetLanguage: "zh-Hans"), "这是第一行这是第二行")
    }

    func testLatinSingleLineBreakBecomesSpace() {
        XCTAssertEqual(LineBreakNormalizer.normalize("First line\nsecond line", targetLanguage: "en"), "First line second line")
    }

    func testMultipleBlankLinesBecomeOneParagraphBreak() {
        XCTAssertEqual(LineBreakNormalizer.normalize("第一段\n\n\n第二段", targetLanguage: "zh-Hans"), "第一段\n\n第二段")
    }

    func testLineOrientedSourceDoesNotCreateParagraphs() {
        XCTAssertEqual(
            LineBreakNormalizer.normalize(
                "关于能源的更多信息\n\n动态能源\n\n可变能源合同\n\n防止回供成本",
                sourceText: "Meer over energie\nDynamische energie\nVariabel energiecontract\nTerugleverkosten voorkomen",
                targetLanguage: "zh-Hans"
            ),
            "关于能源的更多信息\n动态能源\n可变能源合同\n防止回供成本"
        )
    }

    func testSourceParagraphBreakIsPreserved() {
        XCTAssertEqual(
            LineBreakNormalizer.normalize("第一段\n\n第二段", sourceText: "First paragraph\n\nSecond paragraph", targetLanguage: "zh-Hans"),
            "第一段\n\n第二段"
        )
    }
}
