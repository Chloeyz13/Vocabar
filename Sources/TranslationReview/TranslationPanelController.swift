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

        print("[TranslationReview] hotkey fired")
        guard SelectionService.isTrusted(prompt: true) else {
            print("[TranslationReview] Accessibility not granted")
            return
        }
        guard let raw = await SelectionService.selectedText() else {
            print("[TranslationReview] could not read selected text")
            return
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else {
            print("[TranslationReview] selection empty or longer than 500 characters")
            return
        }
        print("[TranslationReview] showing translation for: \(text)")
        show(text)
    }

    private func show(_ text: String) {
        panel?.orderOut(nil)

        let view = TranslationPopoverView(
            sourceText: text,
            onSave: { [weak self] source, translation in self?.save(source, translation) },
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

    private func save(_ source: String, _ translation: String) {
        container.mainContext.insert(Card(sourceText: source, translation: translation))
        do {
            try container.mainContext.save()
            panel?.orderOut(nil)
        } catch {
            print("[TranslationReview] failed to save card: \(error)")
            container.mainContext.rollback()
            // Leave the panel open on failure so the translation isn't lost and the user can retry.
        }
    }
}
