import SwiftUI
import AppKit
import SwiftData
import HotKey

/// Owns the global hotkey and the floating panel that shows the translation.
@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private let container: ModelContainer
    private var hotKey: HotKey?
    private var panel: NSPanel?
    private var panelTopLeft: NSPoint?
    private var isTranslating = false

    init(container: ModelContainer) {
        self.container = container
        super.init()
        hotKey = HotKey(key: .t, modifiers: [.command, .option])
        hotKey?.keyDownHandler = { [weak self] in
            Task { await self?.translateSelection() }
        }
    }

    private func translateSelection() async {
        guard !isTranslating else { return }
        isTranslating = true
        defer { isTranslating = false }

        // plog, not print: stdout of a Finder-launched app goes nowhere; plog lands readable
        // in the unified log (`log show --predicate 'process == "TranslationReview"'`).
        plog("hotkey fired")
        guard SelectionService.isTrusted(prompt: true) else {
            plog("Accessibility not granted")
            showAccessibilityAlert()
            return
        }
        guard let raw = await SelectionService.selectedText() else {
            plog("could not read selected text")
            return
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else {
            plog("selection empty or longer than 500 characters")
            return
        }
        plog("showing translation")
        show(text)
    }

    /// The permission failure used to be silent; make it visible and actionable.
    /// A reinstall invalidates a previous grant, in which case the system prompt
    /// does not reappear — the stale entry must be removed and re-added.
    private func showAccessibilityAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Accessibility permission needed"
        alert.informativeText = "Translation Review needs Accessibility access to read the selected text. Enable it in System Settings > Privacy & Security > Accessibility. If Translation Review is already listed, remove it with the \u{2212} button and add it again — reinstalling the app invalidates the old grant."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ text: String) {
        panel?.orderOut(nil)

        let view = TranslationPopoverView(
            sourceText: text,
            onSave: { [weak self] card in self?.save(card) },
            onClose: { [weak self] in self?.panel?.orderOut(nil) }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false // app is a background (accessory) app, so it is never 'active'
        // Content grows as enrichment arrives; preferredContentSize keeps the panel sized to fit.
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
        panel.center()
        // Windows grow upward from their bottom-left origin, so a panel that gains
        // content (enrichment arriving) would push its top off-screen. Pin the top-left
        // corner instead and re-pin on every resize, so it grows downward.
        panel.delegate = self
        panelTopLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel, (notification.object as? NSPanel) === panel,
              var topLeft = panelTopLeft,
              let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        // Keep the whole panel inside the visible screen: top below the menu bar,
        // and if it has grown past the bottom, raise the top just enough to fit.
        topLeft.y = min(topLeft.y, visible.maxY)
        if topLeft.y - panel.frame.height < visible.minY {
            topLeft.y = min(visible.minY + panel.frame.height, visible.maxY)
        }
        panel.setFrameTopLeftPoint(topLeft)
    }

    private func save(_ card: Card) {
        container.mainContext.insert(card)
        do {
            try container.mainContext.save()
            panel?.orderOut(nil)
        } catch {
            plog("failed to save card: \(error)")
            container.mainContext.rollback()
            // Leave the panel open on failure so the translation isn't lost and the user can retry.
        }
    }
}
