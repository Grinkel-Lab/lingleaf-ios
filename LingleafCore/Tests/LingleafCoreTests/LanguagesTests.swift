import XCTest
@testable import LingleafCore

/// Same cases as TranslationLanguagesTest in lingleaf-android (there Chinese is "zh").
final class LanguagesTests: XCTestCase {
    private let supported = TranslationLanguages.supported

    func testPickTakesTheFirstSupportedLanguageThatIsNotEnglish() {
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["en-US", "pt-BR", "es-MX"], supported: supported), "pt")
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["fr-FR"], supported: supported), "fr")
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["de_AT"], supported: supported), "de", "underscores work too")
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["PT-br"], supported: supported), "pt", "case doesn't matter")
    }

    func testPickSkipsUnsupportedLanguages() {
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["ca-ES", "sw", "it-IT"], supported: supported), "it")
    }

    func testPickMapsChineseToSimplified() {
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["zh-Hant-TW"], supported: supported), "zh-Hans")
        XCTAssertEqual(TranslationLanguages.pick(preferred: ["zh-Hans-CN"], supported: supported), "zh-Hans")
    }

    func testPickIsNilWhenThereIsNoCandidate() {
        XCTAssertNil(TranslationLanguages.pick(preferred: ["en-US", "en-GB"], supported: supported))
        XCTAssertNil(TranslationLanguages.pick(preferred: ["ca-ES"], supported: supported))
        XCTAssertNil(TranslationLanguages.pick(preferred: [], supported: supported))
    }

    func testSuggestionsStartWithTheRegionLanguageWithoutRepeats() {
        XCTAssertEqual(TranslationLanguages.suggestions(region: "BR", supported: supported), ["pt", "es", "fr", "zh-Hans", "ar"])
        XCTAssertEqual(TranslationLanguages.suggestions(region: "MX", supported: supported), ["es", "pt", "fr", "zh-Hans", "ar"])
        XCTAssertEqual(TranslationLanguages.suggestions(region: "jp", supported: supported), ["ja", "es", "pt", "fr", "zh-Hans"])
        XCTAssertEqual(TranslationLanguages.suggestions(region: "EG", supported: supported), ["ar", "es", "pt", "fr", "zh-Hans"])
    }

    func testSuggestionsWithoutARegionLanguage() {
        let defaults = ["es", "pt", "fr", "zh-Hans", "ar"]
        XCTAssertEqual(TranslationLanguages.suggestions(region: "US", supported: supported), defaults)
        XCTAssertEqual(TranslationLanguages.suggestions(region: nil, supported: supported), defaults)
        XCTAssertEqual(TranslationLanguages.suggestions(region: "JP", supported: ["es", "fr"]), ["es", "fr"], "only supported ones")
    }
}
