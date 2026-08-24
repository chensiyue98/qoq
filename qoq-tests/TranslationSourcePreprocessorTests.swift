import XCTest
@testable import QoQ

final class TranslationSourcePreprocessorTests: XCTestCase {
    func testCollapsesMultipleBlankLinesIncludingWhitespaceOnlyLines() {
        let source = "First\n\n \t\n\t\nSecond"

        XCTAssertEqual(
            TranslationSourcePreprocessor.process(
                source,
                replaceLineBreaks: false,
                removeCommentMarkers: false,
                removeDashPrefixes: false
            ),
            "First\n\nSecond"
        )
    }

    func testCollapsesWindowsBlankLines() {
        XCTAssertEqual(
            TranslationSourcePreprocessor.process(
                "First\r\n \r\n\r\nSecond",
                replaceLineBreaks: false,
                removeCommentMarkers: false,
                removeDashPrefixes: false
            ),
            "First\n\nSecond"
        )
    }

    func testRemovesLinePrefixesAndLineBreaks() {
        let source = """
        // first line
        # second line
        * third line
        / fourth line
        - fifth line
        """
        XCTAssertEqual(
            TranslationSourcePreprocessor.process(source, replaceLineBreaks: true, removeCommentMarkers: true, removeDashPrefixes: true),
            "first line second line third line fourth line fifth line"
        )
    }

    func testPreservesInlineURLHyphenAndHash() {
        XCTAssertEqual(
            TranslationSourcePreprocessor.process(
                "https://example.com/a-b\nvalue #1",
                replaceLineBreaks: false,
                removeCommentMarkers: true,
                removeDashPrefixes: true
            ),
            "https://example.com/a-b\nvalue #1"
        )
    }
}
