import XCTest
@testable import QoQ

final class TranslationSourcePreprocessorTests: XCTestCase {
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
