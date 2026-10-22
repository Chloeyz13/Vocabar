import SwiftUI
import SwiftData
import AppKit

@main
struct TranslationReviewApp: App {
    private let container: ModelContainer
    private let panelController: TranslationPanelController

    init() {
        NSApplication.shared.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        let container = try! ModelContainer(for: Card.self)
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
