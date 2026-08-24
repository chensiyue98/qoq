import AppKit
import CoreGraphics
import ScreenCaptureKit
@preconcurrency import Vision

struct ScreenCapture {
    let image: CGImage
}

enum ScreenCaptureError: LocalizedError {
    case captureFailed
    case noText

    var errorDescription: String? {
        switch self {
        case .captureFailed: L("无法截取所选屏幕区域。")
        case .noText: L("所选区域中没有识别到文字。")
        }
    }
}

struct OCRTextLine: Equatable {
    let text: String
    let boundingBox: CGRect
}

enum OCRTextReconstructor {
    static func reconstruct(_ input: [OCRTextLine]) -> String {
        let lines = input
            .map { OCRTextLine(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), boundingBox: $0.boundingBox) }
            .filter { !$0.text.isEmpty }
            .sorted { lhs, rhs in
                let sameRowTolerance = max(lhs.boundingBox.height, rhs.boundingBox.height) * 0.5
                if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) <= sameRowTolerance {
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }

        guard let first = lines.first else { return "" }
        let typicalHeight = median(lines.map(\.boundingBox.height))
        let typicalLeft = median(lines.map(\.boundingBox.minX))
        let typicalRight = median(lines.map(\.boundingBox.maxX))

        var result = first.text
        for index in 1..<lines.count {
            let previous = lines[index - 1]
            let current = lines[index]
            if shouldKeepLineBreak(
                from: previous,
                to: current,
                typicalHeight: typicalHeight,
                typicalLeft: typicalLeft,
                typicalRight: typicalRight
            ) {
                result += "\n" + current.text
            } else {
                result = join(result, with: current.text)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldKeepLineBreak(
        from previous: OCRTextLine,
        to current: OCRTextLine,
        typicalHeight: CGFloat,
        typicalLeft: CGFloat,
        typicalRight: CGFloat
    ) -> Bool {
        let height = max(typicalHeight, 0.001)
        let verticalGap = previous.boundingBox.minY - current.boundingBox.maxY
        let startsNewColumn = current.boundingBox.midY > previous.boundingBox.midY
            || (current.boundingBox.minX - previous.boundingBox.maxX) > height * 1.5
        if startsNewColumn || verticalGap > height * 0.8 { return true }
        if isListItem(current.text) || isListItem(previous.text) { return true }

        let indent = current.boundingBox.minX - typicalLeft
        if indent > height * 0.75 { return true }

        // A short, visually distinct line is usually a heading rather than the
        // first line of a wrapped paragraph.
        let previousIsShort = previous.boundingBox.maxX < typicalRight - height * 2
        let previousIsLarger = previous.boundingBox.height > height * 1.28
        if previousIsLarger || (previousIsShort && endsParagraph(previous.text)) { return true }
        return false
    }

    private static func join(_ accumulated: String, with next: String) -> String {
        if accumulated.hasSuffix("-") && startsWithLatinLetter(next) {
            return String(accumulated.dropLast()) + next
        }
        if needsSpace(between: accumulated, and: next) {
            return accumulated + " " + next
        }
        return accumulated + next
    }

    private static func needsSpace(between lhs: String, and rhs: String) -> Bool {
        guard let left = lhs.last, let right = rhs.first else { return false }
        if isCJK(left) || isCJK(right) { return false }
        if ",.;:!?%)]}，。；：！？、」』】）".contains(right) { return false }
        if "([{（【「『".contains(left) { return false }
        return true
    }

    private static func isListItem(_ text: String) -> Bool {
        text.range(of: #"^(?:[-–—•▪◦]|\d+[.)]|[A-Za-z][.)])\s+"#, options: .regularExpression) != nil
    }

    private static func endsParagraph(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".!?。！？：:".contains(last)
    }

    private static func startsWithLatinLetter(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else { return false }
        return scalar.isASCII && CharacterSet.letters.contains(scalar)
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}

enum ScreenOCRService {
    static func ensureScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
    }

    static func capture(screen: NSScreen, rect: NSRect) async throws -> ScreenCapture {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw ScreenCaptureError.captureFailed
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        let displayBounds = CGDisplayBounds(displayID)
        let captureRect = CGRect(
            x: displayBounds.minX + rect.minX - screen.frame.minX,
            y: displayBounds.minY + screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: captureRect) { image, error in
                if let error { continuation.resume(throwing: error); return }
                guard let image else { continuation.resume(throwing: ScreenCaptureError.captureFailed); return }
                continuation.resume(returning: ScreenCapture(image: image))
            }
        }
    }

    static func recognize(_ image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { observation -> OCRTextLine? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRTextLine(text: candidate.string, boundingBox: observation.boundingBox)
                    } ?? []
                let text = OCRTextReconstructor.reconstruct(lines)
                guard !text.isEmpty else { continuation.resume(throwing: ScreenCaptureError.noText); return }
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: image).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
