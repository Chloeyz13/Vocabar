import AppKit
import SwiftUI
import SwiftData

/// Hand-managed status item (MenuBarExtra has no right-click hook).
/// Left click toggles the review popover; right click shows a menu with
/// the Auto-pronounce toggle and Quit.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let container: ModelContainer
    private var saveObserver: NSObjectProtocol?

    init(container: ModelContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView().modelContainer(container)
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble",
                                   accessibilityDescription: "Translation Review")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(didClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateDueCount()
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateDueCount() }
        }
    }

    @objc private func didClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            updateDueCount() // cards may have become due since the last data change
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let auto = NSMenuItem(title: "Auto-pronounce",
                              action: #selector(toggleAutoPronounce), keyEquivalent: "")
        auto.target = self
        auto.state = UserDefaults.standard.object(forKey: "autoPronounce") as? Bool ?? true ? .on : .off
        menu.addItem(auto)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Standard trick: attach the menu only for this click so left click keeps the action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleAutoPronounce() {
        let current = UserDefaults.standard.object(forKey: "autoPronounce") as? Bool ?? true
        UserDefaults.standard.set(!current, forKey: "autoPronounce")
    }

    private func updateDueCount() {
        let count = ((try? container.mainContext.fetch(FetchDescriptor<Card>())) ?? [])
            .filter { $0.isDue() }.count
        statusItem.button?.title = count > 0 ? "\(count)" : ""
    }
}
