import XCTest
@testable import QoQ

@MainActor
final class DictionaryLookupServiceTests: XCTestCase {
    func testEligibility() {
        XCTAssertTrue(DictionaryLookupService.isEligible("serendipity"))
        XCTAssertFalse(DictionaryLookupService.isEligible(String(repeating: "a", count: 41)))
        XCTAssertFalse(DictionaryLookupService.isEligible("first line\nsecond line"))
        XCTAssertFalse(DictionaryLookupService.isEligible("12345 !?"))
    }

    func testDictionaryFallbackUpdatesModel() {
        let previousMode = UserDefaults.standard.object(forKey: "dictionaryFallbackMode")
        defer { restoreDictionaryFallbackMode(previousMode) }

        let model = TranslationModel(dictionaryLookup: { _ in "意外发现美好事物的能力或运气" })
        model.dictionaryFallbackMode = DictionaryFallbackMode.system.rawValue

        XCTAssertTrue(model.useDictionaryFallbackIfAvailable(for: "serendipity"))
        XCTAssertEqual(model.translatedText, "意外发现美好事物的能力或运气")
        XCTAssertEqual(model.outputTitle, L("词典释义"))
    }

    func testDisabledFallbackDoesNotQueryDictionary() {
        let previousMode = UserDefaults.standard.object(forKey: "dictionaryFallbackMode")
        defer { restoreDictionaryFallbackMode(previousMode) }

        let model = TranslationModel(dictionaryLookup: { _ in "definition" })
        model.dictionaryFallbackMode = DictionaryFallbackMode.disabled.rawValue
        XCTAssertFalse(model.useDictionaryFallbackIfAvailable(for: "serendipity"))
    }

    private func restoreDictionaryFallbackMode(_ value: Any?) {
        if let value {
            UserDefaults.standard.set(value, forKey: "dictionaryFallbackMode")
        } else {
            UserDefaults.standard.removeObject(forKey: "dictionaryFallbackMode")
        }
    }
}
