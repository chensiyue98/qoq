import Foundation

enum LineBreakNormalizer {
    static func normalize(_ text: String, sourceText: String, targetLanguage: String) -> String {
        let source = canonicalized(sourceText)
        let translation = canonicalized(text)
        let sourceLayout = nonemptyLinesAndSeparators(in: source)
        let translatedBlocks = splitParagraphs(in: translation)

        guard sourceLayout.lines.count > 1,
              sourceLayout.lines.count == translatedBlocks.count else {
            return normalize(translation, targetLanguage: targetLanguage)
        }

        return zip(translatedBlocks.dropFirst(), sourceLayout.separators).reduce(translatedBlocks[0]) {
            $0 + $1.1 + $1.0
        }
    }

    static func normalize(_ text: String, targetLanguage: String) -> String {
        let canonical = canonicalized(text)
        let paragraphMarker = "\u{F0000}"
        let withParagraphsMarked = replacing(
            pattern: #"[ \t]*\n(?:[ \t]*\n)+[ \t]*"#,
            in: canonical,
            with: paragraphMarker
        )
        let joinsWithoutSpace = targetLanguage.hasPrefix("zh")
            || targetLanguage.hasPrefix("ja")
            || targetLanguage.hasPrefix("ko")
        let joinedLines = replacing(
            pattern: #"[ \t]*\n[ \t]*"#,
            in: withParagraphsMarked,
            with: joinsWithoutSpace ? "" : " "
        )
        return joinedLines.replacingOccurrences(of: paragraphMarker, with: "\n\n")
    }

    private static func canonicalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func nonemptyLinesAndSeparators(in text: String) -> (lines: [String], separators: [String]) {
        let rawLines = text.components(separatedBy: "\n")
        let nonemptyIndices = rawLines.indices.filter {
            !rawLines[$0].trimmingCharacters(in: .whitespaces).isEmpty
        }
        let lines = nonemptyIndices.map { rawLines[$0].trimmingCharacters(in: .whitespaces) }
        let separators = zip(nonemptyIndices, nonemptyIndices.dropFirst()).map { previous, next in
            next - previous == 1 ? "\n" : "\n\n"
        }
        return (lines, separators)
    }

    private static func splitParagraphs(in text: String) -> [String] {
        let marker = "\u{F0000}"
        return replacing(
            pattern: #"[ \t]*\n(?:[ \t]*\n)+[ \t]*"#,
            in: text,
            with: marker
        )
        .components(separatedBy: marker)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }

    private static func replacing(pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
