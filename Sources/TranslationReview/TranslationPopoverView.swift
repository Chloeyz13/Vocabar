import SwiftUI
import Translation

/// Small popover that translates English to Simplified Chinese using Apple's on-device framework.
struct TranslationPopoverView: View {
    let sourceText: String
    let onSave: (_ source: String, _ translation: String, _ pronunciation: String?) -> Void
    let onClose: () -> Void

    @State private var translation = ""
    @State private var translationFailed = false
    @State private var pronunciation: String?

    private let configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "en"),
        target: Locale.Language(identifier: "zh-Hans")
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SpeakableWordView(text: sourceText, pronunciation: pronunciation)
                .lineLimit(4)
            Text(translation.isEmpty ? "Translating…" : translation)
                .font(.title3)
                .foregroundStyle(translation.isEmpty ? .secondary : .primary)
            HStack {
                Spacer()
                Button("Save to deck") {
                    onSave(sourceText, translation, pronunciation)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(translation.isEmpty || translationFailed)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onExitCommand(perform: onClose)
        .task {
            // Dictionary Services' lookup is synchronous; run it off the main actor so it
            // can't make the panel stutter right as it appears.
            pronunciation = await Task.detached {
                PronunciationService.pronunciation(for: sourceText)
            }.value
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(sourceText)
                translation = response.targetText
            } catch {
                translation = "Translation unavailable. Check the Chinese language pack in System Settings."
                translationFailed = true
            }
        }
    }
}
