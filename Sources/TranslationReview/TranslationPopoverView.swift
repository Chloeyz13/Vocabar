import SwiftUI
import Translation

/// Small popover that translates English to Simplified Chinese using Apple's on-device framework.
struct TranslationPopoverView: View {
    let sourceText: String
    let onSave: (_ source: String, _ translation: String) -> Void
    let onClose: () -> Void

    @State private var translation = ""

    private let configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "en"),
        target: Locale.Language(identifier: "zh-Hans")
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sourceText)
                .font(.headline)
                .lineLimit(4)
            Text(translation.isEmpty ? "Translating…" : translation)
                .font(.title3)
                .foregroundStyle(translation.isEmpty ? .secondary : .primary)
            HStack {
                Spacer()
                Button("Save to deck") {
                    onSave(sourceText, translation)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(translation.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onExitCommand(perform: onClose)
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(sourceText)
                translation = response.targetText
            } catch {
                translation = "Translation unavailable. Check the Chinese language pack in System Settings."
            }
        }
    }
}
