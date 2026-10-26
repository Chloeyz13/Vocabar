import SwiftUI
import SwiftData
import AppKit

@main
struct TranslationReviewApp: App {
    private let container: ModelContainer
    private let panelController: TranslationPanelController

    init() {
        NSApplication.shared.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Card.self)
        } catch {
            print("[TranslationReview] failed to open persistent store (\(error)); falling back to an in-memory store")
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: Card.self, configurations: fallbackConfig)
            Self.warnAboutInMemoryFallback(error)
        }
        self.container = container
        self.panelController = TranslationPanelController(container: container)
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
