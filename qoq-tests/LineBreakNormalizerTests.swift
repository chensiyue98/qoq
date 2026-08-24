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

final class OCRTextReconstructorTests: XCTestCase {
    func testJoinsWrappedLatinLinesWithSpace() {
        let lines = [
            OCRTextLine(text: "A paragraph wraps onto", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.7, height: 0.08)),
            OCRTextLine(text: "the following line.", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.55, height: 0.08))
        ]
        XCTAssertEqual(OCRTextReconstructor.reconstruct(lines), "A paragraph wraps onto the following line.")
    }

    func testJoinsCJKLinesWithoutSpace() {
        let lines = [
            OCRTextLine(text: "这是自动折行的", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.7, height: 0.08)),
            OCRTextLine(text: "中文段落。", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.5, height: 0.08))
        ]
        XCTAssertEqual(OCRTextReconstructor.reconstruct(lines), "这是自动折行的中文段落。")
    }

    func testPreservesParagraphGapAndListItems() {
        let lines = [
            OCRTextLine(text: "First paragraph.", boundingBox: CGRect(x: 0.1, y: 0.82, width: 0.7, height: 0.06)),
            OCRTextLine(text: "Second paragraph", boundingBox: CGRect(x: 0.1, y: 0.65, width: 0.7, height: 0.06)),
            OCRTextLine(text: "• First item", boundingBox: CGRect(x: 0.1, y: 0.55, width: 0.5, height: 0.06)),
            OCRTextLine(text: "• Second item", boundingBox: CGRect(x: 0.1, y: 0.45, width: 0.5, height: 0.06))
        ]
        XCTAssertEqual(
            OCRTextReconstructor.reconstruct(lines),
            "First paragraph.\nSecond paragraph\n• First item\n• Second item"
        )
    }

    func testRepairsHyphenatedLatinWord() {
        let lines = [
            OCRTextLine(text: "A trans-", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.7, height: 0.08)),
            OCRTextLine(text: "lation", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.08))
        ]
        XCTAssertEqual(OCRTextReconstructor.reconstruct(lines), "A translation")
    }
}
