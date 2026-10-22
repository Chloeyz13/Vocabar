# Translation Review Menu Bar App — Design

## Summary
A macOS menu bar app (Swift/SwiftUI). Select English text, press a hotkey, see a Simplified Chinese translation in a small popover, and save it to a deck. A daily badge and notification prompt review. Everything is stored locally.

## Scope
**v1 (MVP)**
- Menu bar item with a due-today badge
- Global hotkey (⌥⌘T) that reads the selected text
- Translation via Apple's on-device Translation framework (English → Simplified Chinese)
- "Save to deck" button
- Review session with 1/3/7-day schedule
- Daily notification
- Local storage (SwiftData)

**Later**
- LLM/API translation for better phrasing and extra features
- Right-click macOS Service ("Translate & Save")

## User flows
1. **Translate & save:** select text → ⌥⌘T → popover shows source and translation → "Save to deck" → confirmation, popover closes.
2. **Review:** badge shows count of due cards → click menu bar item → review session shows the English prompt, user reveals the Chinese, marks "Got it" or "Again" → next card. Session ends when no cards are due.
3. **Reminder:** once a day at a set time, a notification appears if cards are due.

## Popover
- Shows: source text, translation, "Save to deck" button.
- Dismisses on click elsewhere or Escape.
- Visual style: rounded, friendly, lively. Final look to be tuned in SwiftUI previews.

## Review schedule
- Card stages: 1 day → 3 days → 7 days → done (graduated).
- "Got it" advances one stage; next review = today + interval for the new stage.
- "Again" resets the card to stage 1 (1 day).
- Due = next review date ≤ today.

## Data model
`Card`
- `id: UUID`
- `sourceText: String`
- `translation: String`
- `createdAt: Date`
- `stage: Int` (0 = 1 day, 1 = 3 days, 2 = 7 days, 3 = graduated)
- `nextReviewAt: Date`

## Architecture
- **App shell:** `MenuBarExtra` with due-count badge.
- **HotkeyService:** registers the global hotkey (⌥⌘T).
- **SelectionService:** reads the selected text via Accessibility (requires permission on first run).
- **TranslationService:** protocol `Translating` with an Apple-framework implementation. The LLM implementation plugs in later behind the same protocol.
- **DeckStore:** SwiftData storage and due-card queries.
- **ReviewScheduler:** pure logic for stage transitions and due dates (unit-testable).
- **NotificationService:** daily reminder via `UNUserNotificationCenter`.

## Requirements
- macOS 15+ (Translation framework)
- Accessibility permission (for reading selected text)
- Notification permission (for daily reminder)
- Chinese language pack for Apple Translation (app prompts download if missing)

## Open items
- Exact time for the daily reminder (default: 9:00 AM, configurable later).
- Behavior if selected text is longer than a short phrase (v1: accept up to ~500 characters).
