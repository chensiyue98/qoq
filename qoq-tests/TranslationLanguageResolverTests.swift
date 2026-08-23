import XCTest
@testable import QoQ

final class TranslationLanguageResolverTests: XCTestCase {
    func testUsesPreferredTargetWhenSourceDiffers() {
        XCTAssertEqual(TranslationLanguageResolver.target(sourceLanguage: "nl", preferredTargetLanguage: "zh-Hans", fallbackLanguage: "en"), "zh-Hans")
    }

    func testUsesFallbackWhenSourceMatchesPreferredTarget() {
        XCTAssertEqual(TranslationLanguageResolver.target(sourceLanguage: "zh-Hans", preferredTargetLanguage: "zh-Hans", fallbackLanguage: "en"), "en")
    }

    func testChoosesAnotherLanguageWhenCandidatesStillMatch() {
        XCTAssertEqual(TranslationLanguageResolver.target(sourceLanguage: "en", preferredTargetLanguage: "en", fallbackLanguage: "en"), "zh-Hans")
    }
}
