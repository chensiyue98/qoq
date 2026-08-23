import AppKit
import Combine
import Foundation
import NaturalLanguage
import Translation

enum TranslationSource {
    case selection, screen, manual

    var label: String {
        switch self {
        case .selection: "所选文字"
        case .screen: "屏幕识别"
        case .manual: "输入文字"
        }
    }
}

struct LanguageChoice: Identifiable, Hashable {
    let id: String
    let title: String

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
    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    @Published var fallbackLanguage: String {
        didSet { UserDefaults.standard.set(fallbackLanguage, forKey: "fallbackLanguage") }
    }
    @Published var configuration: TranslationSession.Configuration?

    init() {
        targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "zh-Hans"
        fallbackLanguage = UserDefaults.standard.string(forKey: "fallbackLanguage") ?? "en"
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
        guard let sourceLanguage else { return "选择语言" }
        return LanguageChoice.supported.first(where: { $0.id == sourceLanguage })?.title ?? sourceLanguage
    }

    func requestTranslation(_ text: String, source: TranslationSource) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            showError("没有找到可翻译的文字。")
            return
        }
        sourceText = clean
        translatedText = ""
        self.source = source
        errorMessage = nil
        sourceLanguage = detectLanguage(in: clean)
        guard let sourceLanguage else {
            configuration = nil
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
            translatedText = converted
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
            translatedText = LineBreakNormalizer.normalize(
                response.targetText,
                sourceText: sourceText,
                targetLanguage: activeTargetLanguage
            )
            isWorking = false
        } catch {
            showError("翻译失败：\(error.localizedDescription)")
        }
    }

    func showError(_ message: String) {
        isWorking = false
        errorMessage = message
    }

    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }
}
