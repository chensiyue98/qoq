import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    nonisolated static let defaultsKey = "appLanguage"
    var id: String { rawValue }

    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }

    var title: String {
        switch self {
        case .system: L("跟随系统")
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        }
    }

    nonisolated static var selected: AppLanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .system
    }
}

/// Localizes strings that must cross an AppKit boundary or are produced outside a SwiftUI view.
/// SwiftUI localizes string literals automatically; model and controller strings use this helper.
@inline(__always)
nonisolated func L(_ key: String, _ arguments: CVarArg...) -> String {
    let language = AppLanguage.selected
    let bundle: Bundle
    if language != .system,
       let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
       let localizedBundle = Bundle(path: path) {
        bundle = localizedBundle
    } else {
        bundle = .main
    }
    let format = bundle.localizedString(forKey: key, value: key, table: nil)
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: Locale.current, arguments: arguments)
}
