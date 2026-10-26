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
        }
        self.container = container
        self.panelController = TranslationPanelController(container: container)
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
