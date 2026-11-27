import SwiftUI
import SwiftData

/// Review tab: shows one due card at a time.
/// Keyboard: ↓/Return reveals, then marks Again + next; → marks Got it (after reveal only).
struct ReviewView: View {
    @Query(sort: \Card.nextReviewAt) private var cards: [Card]
    @Environment(\.modelContext) private var context
    @AppStorage("autoPronounce") private var autoPronounce = true
    @State private var revealed = false
    @FocusState private var focused: Bool

    private var due: [Card] { cards.filter { $0.isDue() } }

    var body: some View {
        VStack(spacing: 12) {
            if let card = due.first {
                Text("\(due.count) due")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SpeakableWordView(text: card.sourceText, pronunciation: card.pronunciation)
                    .multilineTextAlignment(.center)
                if revealed {
                    ScrollView {
                        VStack(spacing: 8) {
                            Text(card.translation)
                                .font(.title3)
                            if let pos = card.partOfSpeech, !pos.isEmpty {
                                Text(pos)
                                    .font(.subheadline).italic()
                                    .foregroundStyle(.secondary)
                            }
                            if let examples = card.examples, !examples.isEmpty {
                                Text(examples)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if let note = card.usageNote, !note.isEmpty {
                                Text("💡 \(note)")
                                    .font(.caption)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    HStack {
                        Button("Again ↓") { grade(card, .again) }
                            .keyboardShortcut(.defaultAction)
                        Button("Got it →") { grade(card, .gotIt) }
                    }
                } else {
                    Button("Show translation") { reveal(card) }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Text("All caught up 🎉")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.downArrow) { revealOrAgain() }
        .onKeyPress(.rightArrow) { gotIt() }
        .onAppear {
            focused = true
            speakIfEnabled()
        }
        .onChange(of: due.first?.id) {
            speakIfEnabled()
        }
    }

    private func revealOrAgain() -> KeyPress.Result {
        guard let card = due.first else { return .ignored }
        if revealed {
            grade(card, .again)
        } else {
            reveal(card)
        }
        return .handled
    }

    private func reveal(_ card: Card) {
        revealed = true
        backfillIfNeeded(card)
    }

    /// Cards saved before enrichment existed (or saved offline) fetch it on first reveal.
    private func backfillIfNeeded(_ card: Card) {
        guard card.partOfSpeech == nil, card.examples == nil else { return }
        Task {
            guard let e = try? await EnrichmentService.enrich(card.sourceText) else { return }
            card.partOfSpeech = e.partOfSpeech
            card.examples = e.examplesText
            card.usageNote = e.usageNote
            if card.pronunciation == nil { card.pronunciation = e.ipaOrNil }
            try? context.save()
        }
    }

    private func gotIt() -> KeyPress.Result {
        // Can't grade a card whose translation hasn't been checked.
        guard revealed, let card = due.first else { return .ignored }
        grade(card, .gotIt)
        return .handled
    }

    private func speakIfEnabled() {
        guard autoPronounce, let card = due.first else { return }
        SpeechService.speak(card.sourceText)
    }

    private func grade(_ card: Card, _ grade: ReviewGrade) {
        card.review(grade)
        // Explicit save: autosave is lazy, and the backup writes on save.
        try? context.save()
        revealed = false
    }
}
