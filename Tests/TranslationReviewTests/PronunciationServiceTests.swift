import XCTest
@testable import TranslationReview

final class PronunciationServiceTests: XCTestCase {
    func testExtractsPronunciationFromDictionaryFormat() {
        let definition = "word | wɜːrd |\nnoun\n1. a single distinct meaningful element of speech or writing."
        XCTAssertEqual(PronunciationService.extractPronunciation(from: definition), "wɜːrd")
    }

    func testReturnsNilWhenNoPipeDelimitedPronunciation() {
        let definition = "word\nnoun\n1. a single distinct meaningful element of speech or writing."
        XCTAssertNil(PronunciationService.extractPronunciation(from: definition))
    }

    func testReturnsNilForEmptyInput() {
        XCTAssertNil(PronunciationService.pronunciation(for: "   "))
    }
}
