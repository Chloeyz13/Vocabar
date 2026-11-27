# Vocabar

Menu bar vocabulary builder for macOS: translate English words to Chinese with a hotkey, save them as flashcards, and review them right from the menu bar.

## Features

- Select English text in any app and press ⌥⌘T for an instant translation popover; one click saves the word to your deck.
- Click the menu bar icon to review due cards with a keyboard-first flow, including pronunciation playback.
- Translation runs on-device with Apple's Translation framework — no account or network required for the core flow.
- Optional Claude-powered enrichment adds IPA, part of speech, example sentences, and a usage note to each card (bring your own Anthropic API key).

See DESIGN.md for the full plan.

## Run it

1. Install Xcode 16 or later (requires macOS 15+).
2. Open `Package.swift` in Xcode. Xcode fetches the HotKey package automatically.
3. Press ⌘R. A translate icon appears in the menu bar; there is no Dock icon.
4. Grant Accessibility access when prompted (System Settings → Privacy & Security → Accessibility).
5. Select English text in any app and press ⌥⌘T. Click "Save to deck" to store it.
6. Click the menu bar icon to review cards that are due.

## Install without Xcode

Run `./install.sh` to build a release copy as `/Applications/TranslationReview.app` (it replaces any running copy). To start it automatically at login: System Settings → General → Login Items → "+" → choose Translation Review. Note: after reinstalling you may need to re-grant Accessibility permission (the ad-hoc code signature changes with each build).

## Notes

- The first translation may prompt you to download the English → Simplified Chinese language pack.
- Run the tests with ⌘U or `swift test`.
- Roadmap: daily review notification and a macOS Service.

## License

MIT — see [LICENSE](LICENSE).
