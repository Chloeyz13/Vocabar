import SwiftUI
import SwiftData

/// Deck tab: every saved word, newest first. Swipe or press Delete to remove.
struct DeckView: View {
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @Environment(\.modelContext) private var context

    var body: some View {
        if cards.isEmpty {
            Text("No words saved yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            List {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        SpeakableWordView(text: card.sourceText, pronunciation: card.pronunciation, pronunciationFont: .caption)
                        Text(card.translation).font(.subheadline)
                        Text(createdText(for: card))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(cards[index])
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func createdText(for card: Card) -> String {
        "Created: " + card.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}
