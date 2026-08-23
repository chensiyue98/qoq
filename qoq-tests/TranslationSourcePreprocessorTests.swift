import Foundation

@main
enum TranslationSourcePreprocessorTests {
    static func main() {
        let source = """
        // first line
        # second line
        * third line
        / fourth line
        - fifth line
        """
        let cleaned = TranslationSourcePreprocessor.process(
            source,
            replaceLineBreaks: true,
            removeCommentMarkers: true,
            removeDashPrefixes: true
        )
        guard cleaned == "first line second line third line fourth line fifth line" else {
            fputs("FAILED: 原文预处理没有按顺序清理注释、列表前缀和换行\n", stderr)
            exit(1)
        }

        let untouched = TranslationSourcePreprocessor.process(
            "https://example.com/a-b\nvalue #1",
            replaceLineBreaks: false,
            removeCommentMarkers: true,
            removeDashPrefixes: true
        )
        guard untouched == "https://example.com/a-b\nvalue #1" else {
            fputs("FAILED: 原文预处理不应删除行内 URL、连字符或井号\n", stderr)
            exit(1)
        }

        print("TranslationSourcePreprocessor tests passed")
    }
}
