import AppKit
import ApplicationServices
import os

/// NSLog content is redacted as <private> in the unified log; os_log with %{public}s is readable.
func plog(_ message: String) {
    os_log("%{public}s", "[TranslationReview] \(message)")
}

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
            plog("selection read via Accessibility")
            return text
        }
        plog("Accessibility path empty; falling back to synthetic copy")
        return await selectedTextViaCopy()
    }

    private static func selectedTextViaAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()

        var focused: AnyObject?
        let focusErr = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusErr == .success, let focused else {
            plog("AX: no focused element (err \(focusErr.rawValue))")
            return nil
        }

        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = focused as! AXUIElement

        var role: AnyObject?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role)
        let roleName = role as? String ?? "?"

        var selected: AnyObject?
        let selErr = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selected)
        guard selErr == .success else {
            plog("AX: focused \(roleName) has no selected-text attribute (err \(selErr.rawValue))")
            return nil
        }
        plog("AX: focused \(roleName) selected-text length \((selected as? String)?.count ?? -1)")
        return selected as? String
    }

    private static func selectedTextViaCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        // Snapshot each type's data now, before the synthetic ⌘C overwrites the pasteboard —
        // the NSPasteboardItem references themselves go stale once the pasteboard changes.
        let previousItems: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                dataByType[type] = item.data(forType: type)
            }
            return dataByType
        }
        let previousCount = pasteboard.changeCount

        // Wait until the user's ⌥⌘T modifiers are physically released: a held ⌥ turns the
        // synthetic ⌘C into ⌥⌘C, which no app treats as Copy. A fixed sleep is not enough —
        // people hold the hotkey well past 100ms.
        let releaseDeadline = Date().addingTimeInterval(1.0)
        while !CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate]).isEmpty,
            Date() < releaseDeadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        // Invoke the frontmost app's Edit > Copy menu item via Accessibility — the same code
        // path as a real ⌘C. Terminal.app discards synthetic ⌘C keystrokes entirely (both
        // HID-tap and pid-targeted), but honors a menu press. Keystroke injection remains
        // the fallback for apps without a Copy menu item.
        if let front = NSWorkspace.shared.frontmostApplication,
           pressCopyMenuItem(pid: front.processIdentifier) {
            plog("pressed Copy menu item in \(front.localizedName ?? "?")")
        } else {
            postCommandC()
        }

        // Poll for the frontmost app to update the clipboard; a busy app (e.g. a terminal
        // mid-redraw) can take longer than a fixed 150ms.
        let copyDeadline = Date().addingTimeInterval(0.6)
        while pasteboard.changeCount == previousCount, Date() < copyDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard pasteboard.changeCount != previousCount else {
            // No app responded to the copy. Some TUIs (e.g. Claude Code) capture the mouse,
            // draw their own selection highlight, and auto-copy it to the clipboard on
            // mouse-up — the host terminal has no selection of its own to copy, but the
            // selected text is already sitting right here.
            // ponytail: can translate a stale clipboard when the hotkey is pressed with no
            // selection anywhere; acceptable, the caller's 500-char cap bounds the damage.
            let existing = pasteboard.string(forType: .string)
            plog("copy produced no clipboard change; using existing clipboard (\(existing?.count ?? -1) chars)")
            return existing
        }
        let copied = pasteboard.string(forType: .string)

        // Restore the user's previous clipboard contents, preserving every type (not just
        // plain text), so a copied image/file/RTF item isn't lost by this fallback.
        pasteboard.clearContents()
        let restoredItems = previousItems.map { dataByType -> NSPasteboardItem in
            let restored = NSPasteboardItem()
            for (type, data) in dataByType {
                restored.setData(data, forType: type)
            }
            return restored
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
        return copied
    }

    private static func axAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    /// Finds the menu item whose shortcut is plain ⌘C (matched by shortcut, not title,
    /// so localization doesn't matter) and presses it.
    private static func pressCopyMenuItem(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = axAttribute(app, kAXMenuBarAttribute) else { return false }
        let barItems = axChildren(menuBar as! AXUIElement)
        for barItem in barItems {
            for menu in axChildren(barItem) {
                for item in axChildren(menu) {
                    guard axAttribute(item, kAXMenuItemCmdCharAttribute) as? String == "C",
                          (axAttribute(item, kAXMenuItemCmdModifiersAttribute) as? Int ?? -1) == 0 // 0 = ⌘ alone
                    else { continue }
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = 0x08 // kVK_ANSI_C
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        // Post to the frontmost app's process rather than the HID stream: Terminal.app
        // ignores tap-injected keystrokes (keystroke injection into a terminal would be
        // command injection) but accepts process-targeted events.
        if let front = NSWorkspace.shared.frontmostApplication {
            plog("posting ⌘C to \(front.localizedName ?? "?") (pid \(front.processIdentifier))")
            down?.postToPid(front.processIdentifier)
            up?.postToPid(front.processIdentifier)
        } else {
            plog("no frontmost app; posting ⌘C to HID stream")
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
