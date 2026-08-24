import AppKit
import AVFoundation
import Combine
import CoreServices
import Foundation
import NaturalLanguage
import Translation

enum TranslationSource {
    case selection, screen, manual

    var label: String {
        switch self {
        case .selection: L("所选文字")
        case .screen: L("屏幕识别")
        case .manual: L("输入文字")
        }
    }
}

enum TranslationOutputKind {
    case translation
    case dictionaryDefinition
}

enum TranslationBehaviorKey {
    static let showInputField = "showTranslationInputField"
    static let showLanguageBar = "showTranslationLanguageBar"
    static let replaceLineBreaks = "replaceSourceLineBreaks"
    static let removeCommentMarkers = "removeSourceCommentMarkers"
    static let removeDashPrefixes = "removeSourceDashPrefixes"
    static let copyOCRResult = "copyOCRResultAutomatically"
    static let copyFirstTranslation = "copyFirstTranslationAutomatically"
    static let speakSourceText = "speakSourceTextAutomatically"
}

enum TranslationSourcePreprocessor {
    nonisolated static func process(
        _ text: String,
        replaceLineBreaks: Bool,
        removeCommentMarkers: Bool,
        removeDashPrefixes: Bool
    ) -> String {
        var result = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(
                of: #"\n[ \t]*(?:\n[ \t]*){2,}"#,
                with: "\n\n",
                options: .regularExpression
            )
        if removeCommentMarkers {
            result = result
                .replacingOccurrences(of: #"(?m)^(\s*)[/\*#]+\s?"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"(?m)\s*\*/\s*$"#, with: "", options: .regularExpression)
        }
        if removeDashPrefixes {
            result = result.replacingOccurrences(
                of: #"(?m)^(\s*)[-–—]\s+"#,
                with: "$1",
                options: .regularExpression
            )
        }
        if replaceLineBreaks {
            result = result
                .replacingOccurrences(of: #"\s*[\r\n]+\s*"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DictionaryFallbackMode: String, CaseIterable, Identifiable {
    case system
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L("系统词典")
        case .disabled: L("不使用词典")
        }
    }
}

enum DictionaryLookupService {
    nonisolated static func isEligible(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty
            && clean.count <= 40
            && !clean.contains("\n")
            && clean.unicodeScalars.contains(where: CharacterSet.letters.contains)
    }

    nonisolated static func definition(for text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEligible(clean) else { return nil }
        let source = clean as CFString
        let range = DCSGetTermRangeInString(nil, source, 0)
        guard range.location != kCFNotFound, range.length == CFStringGetLength(source),
              let definition = DCSCopyTextDefinition(nil, source, range)?.takeRetainedValue() else {
            return nil
        }
        let result = (definition as String).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

struct DictionaryDefinitionLayout: Equatable {
    struct Sense: Identifiable, Equatable {
        let number: String?
        let definition: String

        var id: String { "\(number ?? "definition")-\(definition)" }
    }

    let metadata: String?
    let senses: [Sense]
}

enum DictionaryDefinitionParser {
    static func parse(_ definition: String, term: String) -> DictionaryDefinitionLayout {
        let normalized = normalizeSenseNumbers(in: definition)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return DictionaryDefinitionLayout(metadata: nil, senses: [])
        }

        let expression = try? NSRegularExpression(pattern: #"(?:^|\s)(\d+)\s+"#)
        let fullRange = NSRange(normalized.startIndex..., in: normalized)
        let matches = expression?.matches(in: normalized, range: fullRange) ?? []
        guard let firstMatch = matches.first else {
            return DictionaryDefinitionLayout(
                metadata: nil,
                senses: [.init(number: nil, definition: formatSense(normalized))]
            )
        }

        let source = normalized as NSString
        var metadata = source.substring(with: NSRange(location: 0, length: firstMatch.range.location))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        metadata = removeLeadingTerm(term, from: metadata)
        metadata = formatMetadata(metadata)

        let senses = matches.enumerated().compactMap { index, match -> DictionaryDefinitionLayout.Sense? in
            guard match.numberOfRanges > 1 else { return nil }
            let number = source.substring(with: match.range(at: 1))
            let start = NSMaxRange(match.range)
            let end = index + 1 < matches.count ? matches[index + 1].range.location : source.length
            guard end >= start else { return nil }
            let text = formatSense(source.substring(with: NSRange(location: start, length: end - start)))
            return text.isEmpty ? nil : .init(number: number, definition: text)
        }

        return DictionaryDefinitionLayout(
            metadata: metadata.isEmpty ? nil : metadata,
            senses: senses
        )
    }

    private static func removeLeadingTerm(_ term: String, from metadata: String) -> String {
        let escapedTerm = NSRegularExpression.escapedPattern(for: term.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !escapedTerm.isEmpty,
              let expression = try? NSRegularExpression(pattern: "^\(escapedTerm)\\s*", options: .caseInsensitive) else {
            return metadata
        }
        return expression.stringByReplacingMatches(
            in: metadata,
            range: NSRange(metadata.startIndex..., in: metadata),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatMetadata(_ text: String) -> String {
        text.replacingOccurrences(of: #"^\s*[•|]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[•|]\s*"#, with: "  ·  ", options: .regularExpression)
    }

    private static func formatSense(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s*[|▸]\s*"#, with: "\n• ", options: .regularExpression)
    }

    private static func normalizeSenseNumbers(in text: String) -> String {
        let circledNumbers = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
                              "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳"]
        return circledNumbers.enumerated().reduce(text) { result, item in
            result.replacingOccurrences(of: item.element, with: " \(item.offset + 1) ")
        }
    }
}

struct LanguageChoice: Identifiable, Hashable {
    let id: String
    private let fallbackTitle: String

    init(id: String, title: String) {
        self.id = id
        self.fallbackTitle = title
    }

    var title: String {
        Locale.autoupdatingCurrent.localizedString(forIdentifier: id) ?? fallbackTitle
    }

    static let supported = [
        LanguageChoice(id: "zh-Hans", title: "简体中文"),
        LanguageChoice(id: "zh-Hant", title: "繁體中文"),
        LanguageChoice(id: "en", title: "English"),
        LanguageChoice(id: "ja", title: "日本語"),
        LanguageChoice(id: "ko", title: "한국어"),
        LanguageChoice(id: "fr", title: "Français"),
        LanguageChoice(id: "de", title: "Deutsch"),
        LanguageChoice(id: "es", title: "Español"),
        LanguageChoice(id: "it", title: "Italiano"),
        LanguageChoice(id: "nl", title: "Nederlands"),
        LanguageChoice(id: "pt", title: "Português"),
        LanguageChoice(id: "ru", title: "Русский"),
        LanguageChoice(id: "ar", title: "العربية"),
        LanguageChoice(id: "th", title: "ไทย"),
        LanguageChoice(id: "vi", title: "Tiếng Việt"),
        LanguageChoice(id: "id", title: "Bahasa Indonesia"),
        LanguageChoice(id: "tr", title: "Türkçe"),
        LanguageChoice(id: "pl", title: "Polski"),
        LanguageChoice(id: "uk", title: "Українська")
    ]
}

enum TranslationLanguageResolver {
    static func target(
        sourceLanguage: String,
        preferredTargetLanguage: String,
        fallbackLanguage: String
    ) -> String {
        guard sourceLanguage == preferredTargetLanguage else { return preferredTargetLanguage }
        if fallbackLanguage != sourceLanguage { return fallbackLanguage }
        return LanguageChoice.supported.first(where: { $0.id != sourceLanguage })?.id
            ?? preferredTargetLanguage
    }
}

enum ChineseVariantConverter {
    static func convert(_ text: String, sourceLanguage: String, targetLanguage: String) -> String? {
        let transformIdentifier: String
        switch (sourceLanguage, targetLanguage) {
        case ("zh-Hant", "zh-Hans"):
            transformIdentifier = "Hant-Hans"
        case ("zh-Hans", "zh-Hant"):
            transformIdentifier = "Hans-Hant"
        default:
            return nil
        }
        return text.applyingTransform(StringTransform(transformIdentifier), reverse: false)
    }
}

@MainActor
final class TranslationModel: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var source: TranslationSource = .manual
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var sourceLanguage: String?
    @Published var needsSourceSelection = false
    @Published var outputKind: TranslationOutputKind = .translation
    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    @Published var fallbackLanguage: String {
        didSet { UserDefaults.standard.set(fallbackLanguage, forKey: "fallbackLanguage") }
    }
    @Published var dictionaryFallbackMode: String {
        didSet { UserDefaults.standard.set(dictionaryFallbackMode, forKey: "dictionaryFallbackMode") }
    }
    @Published var configuration: TranslationSession.Configuration?
    private let dictionaryLookup: (String) -> String?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var shouldCopyCurrentResult = false

    init(dictionaryLookup: @escaping (String) -> String? = DictionaryLookupService.definition) {
        targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "zh-Hans"
        fallbackLanguage = UserDefaults.standard.string(forKey: "fallbackLanguage") ?? "en"
        dictionaryFallbackMode = UserDefaults.standard.string(forKey: "dictionaryFallbackMode")
            ?? DictionaryFallbackMode.system.rawValue
        self.dictionaryLookup = dictionaryLookup
    }

    var activeTargetLanguage: String {
        guard let sourceLanguage else { return targetLanguage }
        return TranslationLanguageResolver.target(
            sourceLanguage: sourceLanguage,
            preferredTargetLanguage: targetLanguage,
            fallbackLanguage: fallbackLanguage
        )
    }

    var targetName: String {
        LanguageChoice.supported.first(where: { $0.id == activeTargetLanguage })?.title
            ?? activeTargetLanguage
    }

    var sourceName: String {
        guard let sourceLanguage else { return L("选择语言") }
        return LanguageChoice.supported.first(where: { $0.id == sourceLanguage })?.title ?? sourceLanguage
    }

    var outputTitle: String {
        outputKind == .dictionaryDefinition ? L("词典释义") : targetName
    }

    func requestTranslation(_ text: String, source: TranslationSource) {
        let defaults = UserDefaults.standard
        let clean = TranslationSourcePreprocessor.process(
            text,
            replaceLineBreaks: defaults.bool(forKey: TranslationBehaviorKey.replaceLineBreaks),
            removeCommentMarkers: defaults.bool(forKey: TranslationBehaviorKey.removeCommentMarkers),
            removeDashPrefixes: defaults.bool(forKey: TranslationBehaviorKey.removeDashPrefixes)
        )
        guard !clean.isEmpty else {
            showError(L("没有找到可翻译的文字。"))
            return
        }
        shouldCopyCurrentResult = defaults.bool(forKey: TranslationBehaviorKey.copyFirstTranslation)
        sourceText = clean
        translatedText = ""
        outputKind = .translation
        self.source = source
        errorMessage = nil
        if defaults.bool(forKey: TranslationBehaviorKey.speakSourceText) {
            speechSynthesizer.stopSpeaking(at: .immediate)
            speechSynthesizer.speak(AVSpeechUtterance(string: clean))
        }
        sourceLanguage = detectLanguage(in: clean)
        guard let sourceLanguage else {
            configuration = nil
            if useDictionaryFallbackIfAvailable(for: clean) { return }
            needsSourceSelection = true
            isWorking = false
            return
        }
        beginTranslation(from: sourceLanguage)
    }

    func chooseSourceLanguage(_ identifier: String) {
        sourceLanguage = identifier
        beginTranslation(from: identifier)
    }

    func retryAutomaticDetection() {
        requestTranslation(sourceText, source: source)
    }

    func translateEditedText() {
        requestTranslation(sourceText, source: source)
    }

    private func beginTranslation(from sourceIdentifier: String) {
        needsSourceSelection = false
        outputKind = .translation
        errorMessage = nil
        let resolvedTargetLanguage = TranslationLanguageResolver.target(
            sourceLanguage: sourceIdentifier,
            preferredTargetLanguage: targetLanguage,
            fallbackLanguage: fallbackLanguage
        )
        if let converted = ChineseVariantConverter.convert(
            sourceText,
            sourceLanguage: sourceIdentifier,
            targetLanguage: resolvedTargetLanguage
        ) {
            completeOutput(converted, kind: .translation)
            isWorking = false
            configuration = nil
            return
        }
        isWorking = true
        if configuration == nil {
            configuration = .init(
                source: Locale.Language(identifier: sourceIdentifier),
                target: Locale.Language(identifier: resolvedTargetLanguage)
            )
        } else {
            configuration?.source = Locale.Language(identifier: sourceIdentifier)
            configuration?.target = Locale.Language(identifier: resolvedTargetLanguage)
            configuration?.invalidate()
        }
    }

    @discardableResult
    func useDictionaryFallbackIfAvailable(for text: String) -> Bool {
        guard dictionaryFallbackMode == DictionaryFallbackMode.system.rawValue,
              DictionaryLookupService.isEligible(text),
              let definition = dictionaryLookup(text) else {
            return false
        }
        completeOutput(definition, kind: .dictionaryDefinition)
        needsSourceSelection = false
        isWorking = false
        configuration = nil
        return true
    }

    func retranslate() {
        if let sourceLanguage { beginTranslation(from: sourceLanguage) }
        else { retryAutomaticDetection() }
    }

    private func detectLanguage(in text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let (language, confidence) = hypotheses.first, confidence >= 0.45 else { return nil }
        let identifier = language.rawValue
        return LanguageChoice.supported.contains(where: { $0.id == identifier }) ? identifier : nil
    }

    func perform(using session: TranslationSession) async {
        do {
            let response = try await session.translate(sourceText)
            let normalized = LineBreakNormalizer.normalize(
                response.targetText,
                sourceText: sourceText,
                targetLanguage: activeTargetLanguage
            )
            completeOutput(normalized, kind: .translation)
            isWorking = false
        } catch {
            showError(L("翻译失败：%@", error.localizedDescription))
        }
    }

    func showError(_ message: String) {
        isWorking = false
        errorMessage = message
    }

    func copyTranslation() {
        copyToPasteboard(translatedText)
    }

    func copySourceText() {
        copyToPasteboard(sourceText)
    }

    func speakSourceText() {
        speak(sourceText, language: sourceLanguage)
    }

    func speakTranslation() {
        speak(translatedText, language: activeTargetLanguage)
    }

    private func completeOutput(_ text: String, kind: TranslationOutputKind) {
        translatedText = text
        outputKind = kind
        if shouldCopyCurrentResult {
            copyToPasteboard(text)
            shouldCopyCurrentResult = false
        }
    }

    private func copyToPasteboard(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func speak(_ text: String, language: String?) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: clean)
        if let language, let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        }
        speechSynthesizer.speak(utterance)
    }
}
