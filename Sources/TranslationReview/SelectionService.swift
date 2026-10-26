import AppKit
import ApplicationServices

/// Reads the currently selected text. Tries the Accessibility API first, then falls back to
/// copying with ⌘C (works in Electron apps such as Claude, Chrome, and Slack) and restores the clipboard.
enum SelectionService {
    /// Returns whether the app is trusted for Accessibility; optionally shows the system prompt.
    static func isTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func selectedText() async -> String? {
        if let text = selectedTextViaAccessibility(), !text.isEmpty {
            return text
        }
        return await selectedTextViaCopy()
    }

    private static func selectedTextViaAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()

        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }

        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = focused as! AXUIElement

        var selected: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selected) == .success else {
            return nil
        }
        return selected as? String
    }

    private static func selectedTextViaCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems ?? []
        let previousCount = pasteboard.changeCount

        // Give the user's ⌥⌘T modifiers time to release so they don't leak into the ⌘C.
        try? await Task.sleep(for: .milliseconds(100))
        postCommandC()

        // Wait briefly for the frontmost app to update the clipboard.
        try? await Task.sleep(for: .milliseconds(150))
        guard pasteboard.changeCount != previousCount else { return nil }
        let copied = pasteboard.string(forType: .string)

        // Restore the user's previous clipboard contents, preserving every type (not just
        // plain text), so a copied image/file/RTF item isn't lost by this fallback.
        pasteboard.clearContents()
        let restoredItems = previousItems.map { item -> NSPasteboardItem in
            let restored = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    restored.setData(data, forType: type)
                }
            }
            return restored
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
        return copied
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = 0x08 // kVK_ANSI_C
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
