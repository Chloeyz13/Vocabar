import AppKit
import SwiftUI
import SwiftData

/// Hand-managed status item (MenuBarExtra has no right-click hook).
/// Left click toggles the review window; right click shows a menu with
/// the Auto-pronounce toggle, API key setup, and Quit.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let container: ModelContainer
    private var menuPanel: NSPanel?
    private var clickMonitor: Any?
    private var saveObserver: NSObjectProtocol?

    init(container: ModelContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

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
            toggleWindow()
        }
    }

    // MARK: - Left click: review window

    // ponytail: NSPopover anchored to a status item kept opening with its top above the
    // screen edge, so the window is a plain panel positioned by hand: top pinned just
    // below the menu bar, centered under the icon, clamped to the visible screen.
    private func toggleWindow() {
        if let panel = menuPanel, panel.isVisible {
            closeWindow()
            return
        }
        guard let button = statusItem.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }
        updateDueCount() // cards may have become due since the last data change

        let panel = menuPanel ?? makeMenuPanel()
        let size = panel.frame.size
        let visible = screen.visibleFrame
        var x = buttonWindow.frame.midX - size.width / 2
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        let y = min(buttonWindow.frame.minY, visible.maxY) - size.height - 4
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, visible.minY)))

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)

        // Transient behavior: a click anywhere outside the app closes the window.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeWindow() }
        }
    }

    private func closeWindow() {
        menuPanel?.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func makeMenuPanel() -> NSPanel {
        let hosting = NSHostingController(
            rootView: MenuContentView().modelContainer(container)
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hosting
        menuPanel = panel
        return panel
    }

    // MARK: - Right click: menu

    private func showMenu() {
        let menu = NSMenu()
        let auto = NSMenuItem(title: "Auto-pronounce",
                              action: #selector(toggleAutoPronounce), keyEquivalent: "")
        auto.target = self
        auto.state = UserDefaults.standard.object(forKey: "autoPronounce") as? Bool ?? true ? .on : .off
        menu.addItem(auto)
        let apiKey = NSMenuItem(title: "Set API Key…",
                                action: #selector(promptForAPIKey), keyEquivalent: "")
        apiKey.target = self
        menu.addItem(apiKey)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Standard trick: attach the menu only for this click so left click keeps the action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func promptForAPIKey() {
        let hasKey = APIKeyStore.load() != nil
        let alert = NSAlert()
        alert.messageText = "Anthropic API Key"
        alert.informativeText = hasKey
            ? "A key is saved in your Keychain. Enter a new one to replace it, or remove it."
            : "Used to enrich looked-up words with US pronunciation, examples, and usage notes. Stored securely in your Keychain."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "sk-ant-…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if hasKey { alert.addButton(withTitle: "Remove Key") }
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { APIKeyStore.save(key) }
        case .alertThirdButtonReturn:
            APIKeyStore.delete()
        default:
            break
        }
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
