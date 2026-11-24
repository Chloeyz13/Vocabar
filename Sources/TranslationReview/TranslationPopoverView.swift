import SwiftUI
import Translation

/// Lookup popover. One Claude call provides translation + enrichment (IPA, part of
/// speech, examples, usage note); Apple's on-device translation and the system
/// dictionary remain the fallback when there's no API key or the call fails.
struct TranslationPopoverView: View {
    let sourceText: String
    let onSave: (Card) -> Void
    let onClose: () -> Void

    @State private var enrichment: Enrichment?
    @State private var enrichmentFailed = false
    @State private var fallbackTranslation = ""
    @State private var fallbackFailed = false
    @State private var dictionaryIPA: String?

    private let configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "en"),
        target: Locale.Language(identifier: "zh-Hans")
    )

    private var ipa: String? { enrichment?.ipaOrNil ?? dictionaryIPA }

    private var canSave: Bool {
        enrichment != nil || (enrichmentFailed && !fallbackTranslation.isEmpty && !fallbackFailed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SpeakableWordView(text: sourceText, pronunciation: ipa)
                .lineLimit(4)
            if let enrichment {
                enriched(enrichment)
            } else if enrichmentFailed {
                fallback
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Looking up…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            HStack {
                Spacer()
                Button("Save to deck") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onExitCommand(perform: onClose)
        .task {
            // Dictionary Services' lookup is synchronous; run it off the main actor so it
            // can't make the panel stutter right as it appears.
            dictionaryIPA = await Task.detached {
                PronunciationService.pronunciation(for: sourceText)
            }.value
        }
        .task {
            do {
                enrichment = try await EnrichmentService.enrich(sourceText)
            } catch {
                plog("enrichment failed: \(error)")
                enrichmentFailed = true
            }
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(sourceText)
                fallbackTranslation = response.targetText
            } catch {
                fallbackTranslation = "Translation unavailable. Check the Chinese language pack in System Settings."
                fallbackFailed = true
            }
        }
    }

    @ViewBuilder
    private func enriched(_ e: Enrichment) -> some View {
        if !e.partOfSpeech.isEmpty {
            Text(e.partOfSpeech)
                .font(.subheadline).italic()
                .foregroundStyle(.secondary)
        }
        Text(e.translation).font(.title3)
        Divider()
        Text(e.examplesText).font(.callout)
        if !e.usageNote.isEmpty {
            Text("💡 \(e.usageNote)")
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(fallbackTranslation.isEmpty ? "Translating…" : fallbackTranslation)
                .font(.title3)
                .foregroundStyle(fallbackTranslation.isEmpty ? .secondary : .primary)
            Text("⚠︎ Basic lookup — enrichment unavailable (offline or no API key)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        onSave(Card(
            sourceText: sourceText,
            translation: enrichment?.translation ?? fallbackTranslation,
            pronunciation: ipa,
            partOfSpeech: enrichment?.partOfSpeech,
            examples: enrichment?.examplesText,
            usageNote: enrichment?.usageNote
        ))
    }
}
