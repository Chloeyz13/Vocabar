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
                    Text(card.translation)
                        .font(.title3)
                    HStack {
                        Button("Again ↓") { grade(card, .again) }
                            .keyboardShortcut(.defaultAction)
                        Button("Got it →") { grade(card, .gotIt) }
                    }
                } else {
                    Button("Show translation") { revealed = true }
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
            revealed = true
        }
        return .handled
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
