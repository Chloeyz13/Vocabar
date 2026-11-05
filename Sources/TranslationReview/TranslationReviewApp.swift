import SwiftUI
import SwiftData
import AppKit

@main
struct TranslationReviewApp: App {
    private let container: ModelContainer
    private let panelController: TranslationPanelController
    @MainActor private static var backupObserver: NSObjectProtocol?

    init() {
        NSApplication.shared.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        Storage.migrateLegacyStoreIfNeeded()
        let container = Self.makeContainer()
        self.container = container
        self.panelController = TranslationPanelController(container: container)

        Self.restoreFromBackupIfStoreEmpty(container)
        Backup.writeAll(from: container)
        Self.backupObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in Backup.writeAll(from: container) }
        }
    }

    @MainActor
    private static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(url: Storage.storeURL)
        do {
            return try ModelContainer(for: Card.self, configurations: config)
        } catch {
            // Typical cause during development: an incompatible Card schema change.
            // Set the unreadable store aside and start fresh; the words come back from
            // the JSONL backup via restoreFromBackupIfStoreEmpty.
            print("[TranslationReview] failed to open store (\(error)); moving it aside and starting fresh")
            Storage.moveBrokenStoreAside()
            if let fresh = try? ModelContainer(for: Card.self, configurations: config) {
                warnAboutRecovery(error)
                return fresh
            }
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let memory = try! ModelContainer(for: Card.self, configurations: memoryConfig)
            warnAboutInMemoryFallback(error)
            return memory
        }
    }

    /// Restores the deck from cards.jsonl when the store has no cards but the backup does —
    /// after a schema-break recovery, or when the store file was deleted or replaced.
    /// Only runs on an empty store, so it can never duplicate or overwrite saved words.
    @MainActor
    private static func restoreFromBackupIfStoreEmpty(_ container: ModelContainer) {
        let count = (try? container.mainContext.fetchCount(FetchDescriptor<Card>())) ?? 0
        guard count == 0, let backups = try? Backup.read(), !backups.isEmpty else { return }
        for backup in backups {
            container.mainContext.insert(backup.makeCard())
        }
        do {
            try container.mainContext.save()
            print("[TranslationReview] restored \(backups.count) card(s) from backup")
        } catch {
            print("[TranslationReview] failed to restore from backup: \(error)")
        }
    }

    private static func warnAboutRecovery(_ error: Error) {
        let backedUp = (try? Backup.read())?.count ?? 0
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Word storage was reset"
        alert.informativeText = "The word store couldn't be opened (\(error.localizedDescription)). The old file was kept next to the new one, and \(backedUp) word(s) are being restored from the backup."
        alert.runModal()
    }

    /// Surfaces the degraded-storage mode instead of letting saves silently vanish on quit.
    private static func warnAboutInMemoryFallback(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Saved words won't be kept"
        alert.informativeText = "Translation Review couldn't open its storage (\(error.localizedDescription)). Cards you save this session will be lost when the app quits."
        alert.runModal()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .modelContainer(container)
        } label: {
            MenuBarLabel()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
    }
}
