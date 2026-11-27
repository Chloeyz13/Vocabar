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

    func testEnrichmentFieldsRoundTrip() throws {
        let card = Card(sourceText: "serendipity", translation: "机缘巧合", pronunciation: "/ˌserənˈdɪpəti/",
                        partOfSpeech: "n.", examples: "• It was pure serendipity.\n  纯属机缘巧合。",
                        usageNote: "褒义词，多用于书面语。", now: Date(timeIntervalSince1970: 1_700_000_000))

        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup.write([card], to: url)
        let remade = try Backup.read(from: url)[0].makeCard()

        XCTAssertEqual(remade.partOfSpeech, card.partOfSpeech)
        XCTAssertEqual(remade.examples, card.examples)
        XCTAssertEqual(remade.usageNote, card.usageNote)
    }

    func testLegacyBackupLineWithoutEnrichmentFieldsDecodes() throws {
        // A line written by a build that predates the enrichment fields must still restore.
        let legacy = """
        {"id":"B51A8A3B-9E7B-4E49-9F0A-111111111111","sourceText":"ephemeral","translation":"短暂的","pronunciation":"ɪˈfem(ə)rəl","createdAt":"2023-11-14T22:13:20Z","stage":2,"nextReviewAt":"2023-11-21T20:53:20Z"}
        """
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(legacy.utf8).write(to: url)

        let restored = try Backup.read(from: url)
        XCTAssertEqual(restored.count, 1)
        let card = restored[0].makeCard()
        XCTAssertEqual(card.sourceText, "ephemeral")
        XCTAssertEqual(card.stage, 2)
        XCTAssertNil(card.partOfSpeech)
        XCTAssertNil(card.examples)
        XCTAssertNil(card.usageNote)
    }

    func testEmptyDeckRoundTrips() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup.write([], to: url)
        XCTAssertEqual(try Backup.read(from: url), [])
    }
}
