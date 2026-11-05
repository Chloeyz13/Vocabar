import SwiftUI
import AppKit
import SwiftData
import HotKey

/// Owns the global hotkey and the floating panel that shows the translation.
@MainActor
final class TranslationPanelController {
    private let container: ModelContainer
    private var hotKey: HotKey?
    private var panel: NSPanel?
    private var isTranslating = false

    init(container: ModelContainer) {
        self.container = container
        hotKey = HotKey(key: .t, modifiers: [.command, .option])
        hotKey?.keyDownHandler = { [weak self] in
            Task { await self?.translateSelection() }
        }
    }

    private func translateSelection() async {
        guard !isTranslating else { return }
        isTranslating = true
        defer { isTranslating = false }

        // NSLog instead of print: stdout of a Finder-launched app goes nowhere,
        // NSLog lands in the unified log (`log show --predicate 'process == "TranslationReview"'`).
        NSLog("[TranslationReview] hotkey fired")
        guard SelectionService.isTrusted(prompt: true) else {
            NSLog("[TranslationReview] Accessibility not granted")
            showAccessibilityAlert()
            return
        }
        guard let raw = await SelectionService.selectedText() else {
            NSLog("[TranslationReview] could not read selected text")
            return
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else {
            NSLog("[TranslationReview] selection empty or longer than 500 characters")
            return
        }
        NSLog("[TranslationReview] showing translation")
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
            onSave: { [weak self] source, translation, pronunciation in self?.save(source, translation, pronunciation) },
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
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func save(_ source: String, _ translation: String, _ pronunciation: String?) {
        container.mainContext.insert(Card(sourceText: source, translation: translation, pronunciation: pronunciation))
        do {
            try container.mainContext.save()
            panel?.orderOut(nil)
        } catch {
            NSLog("[TranslationReview] failed to save card: %@", String(describing: error))
            container.mainContext.rollback()
            // Leave the panel open on failure so the translation isn't lost and the user can retry.
        }
    }
}
