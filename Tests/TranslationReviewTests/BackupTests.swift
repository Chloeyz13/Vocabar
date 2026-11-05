import XCTest
@testable import TranslationReview

final class BackupTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "backup-test-\(UUID()).jsonl")
    }

    func testRoundTripPreservesAllFields() throws {
        // Whole-second dates: the backup stores ISO 8601, which truncates to seconds.
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let card = Card(sourceText: "ephemeral", translation: "短暂的", pronunciation: "ɪˈfem(ə)rəl", now: created)
        card.stage = 2
        card.nextReviewAt = Date(timeIntervalSince1970: 1_700_600_000)
        let phrase = Card(sourceText: "no pronunciation here", translation: "没有发音", now: created)

        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup.write([card, phrase], to: url)
        let restored = try Backup.read(from: url)

        XCTAssertEqual(restored, [CardBackup(card), CardBackup(phrase)])

        let remade = restored[0].makeCard()
        XCTAssertEqual(remade.id, card.id)
        XCTAssertEqual(remade.sourceText, card.sourceText)
        XCTAssertEqual(remade.translation, card.translation)
        XCTAssertEqual(remade.pronunciation, card.pronunciation)
        XCTAssertEqual(remade.createdAt, card.createdAt)
        XCTAssertEqual(remade.stage, card.stage)
        XCTAssertEqual(remade.nextReviewAt, card.nextReviewAt)
    }

    func testEmptyDeckRoundTrips() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup.write([], to: url)
        XCTAssertEqual(try Backup.read(from: url), [])
    }
}
