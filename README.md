# Translation Review (macOS menu bar app)

Menu bar vocabulary builder: translate English to Chinese with a hotkey, then review your saved words.

See DESIGN.md for the plan.

## Run it
1. Install Xcode 16 or later (requires macOS 15+).
2. Open `Package.swift` in Xcode. Xcode fetches the HotKey package automatically.
3. Press ⌘R. A translate icon appears in the menu bar; there is no Dock icon.
4. Grant Accessibility access when prompted (System Settings → Privacy & Security → Accessibility).
5. Select English text in any app and press ⌥⌘T. Click "Save to deck" to store it.
6. Click the menu bar icon to review cards that are due.

## Notes
- The first translation may prompt you to download the English → Simplified Chinese language pack.
- Run the tests with ⌘U.
- Not yet built: the daily notification, the macOS Service, and the LLM translator. These come next.
- This code was written without a compiler available; expect small fixes on first build.
