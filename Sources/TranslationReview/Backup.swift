import Foundation
import SwiftData

/// Where the app's data lives: a fixed, app-specific folder, so every build (debug,
/// release, rebuilt from scratch) opens the same store. A plain-text JSONL backup sits
/// beside it as insurance against SwiftData schema changes during development.
enum Storage {
    static let directory = URL.applicationSupportDirectory.appending(path: "TranslationReview")
    static let storeURL = directory.appending(path: "cards.store")
    static let backupURL = directory.appending(path: "cards.jsonl")

    /// Earlier builds used SwiftData's generic default store. Copy it (and its SQLite
    /// sidecar files) into our folder once so existing words carry over. Copy, not move:
    /// nothing is destroyed if anything goes wrong.
    static func migrateLegacyStoreIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = URL.applicationSupportDirectory.appending(path: "default.store")
        guard !fm.fileExists(atPath: storeURL.path), fm.fileExists(atPath: legacy.path) else { return }
        for suffix in ["", "-wal", "-shm"] {
            try? fm.copyItem(at: URL(filePath: legacy.path + suffix),
                             to: URL(filePath: storeURL.path + suffix))
        }
    }

    /// A store that failed to open (usually an incompatible Card schema change during
    /// development) is renamed aside, never deleted, so its data stays recoverable by hand.
    static func moveBrokenStoreAside() {
        let fm = FileManager.default
        let stamp = Int(Date.now.timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            try? fm.moveItem(at: URL(filePath: storeURL.path + suffix),
                             to: URL(filePath: storeURL.path + ".broken-\(stamp)" + suffix))
        }
    }
}

/// One card mirrored to plain JSON. Includes review progress so a restore loses nothing.
struct CardBackup: Codable, Equatable {
    let id: UUID
    let sourceText: String
    let translation: String
    let pronunciation: String?
    let createdAt: Date
    let stage: Int
    let nextReviewAt: Date

    init(_ card: Card) {
        id = card.id
        sourceText = card.sourceText
        translation = card.translation
        pronunciation = card.pronunciation
        createdAt = card.createdAt
        stage = card.stage
        nextReviewAt = card.nextReviewAt
    }

    func makeCard() -> Card {
        let card = Card(sourceText: sourceText, translation: translation, pronunciation: pronunciation, now: createdAt)
        card.id = id
        card.stage = stage
        card.nextReviewAt = nextReviewAt
        return card
    }
}

/// Plain-text safety net: the whole deck rewritten to cards.jsonl after every change.
/// The deck is small, so a full rewrite is simpler and safer than incremental updates.
enum Backup {
    // ponytail: ISO 8601 truncates dates to whole seconds — irrelevant for day-scale
    // review scheduling, and it keeps the backup file human-readable.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func write(_ cards: [Card], to url: URL = Storage.backupURL) throws {
        let lines = try cards.map { String(decoding: try encoder.encode(CardBackup($0)), as: UTF8.self) }
        try Data(lines.joined(separator: "\n").utf8).write(to: url, options: .atomic)
    }

    static func read(from url: URL = Storage.backupURL) throws -> [CardBackup] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map { try decoder.decode(CardBackup.self, from: Data($0.utf8)) }
    }

    @MainActor
    static func writeAll(from container: ModelContainer) {
        do {
            let cards = try container.mainContext.fetch(FetchDescriptor<Card>())
            try write(cards)
        } catch {
            print("[TranslationReview] backup write failed: \(error)")
        }
    }
}
