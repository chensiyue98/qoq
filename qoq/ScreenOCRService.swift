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
        case .captureFailed: "无法截取所选屏幕区域。"
        case .noText: "所选区域中没有识别到文字。"
        }
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
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
