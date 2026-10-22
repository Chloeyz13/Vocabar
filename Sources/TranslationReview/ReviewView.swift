import SwiftUI
import SwiftData

/// Review tab: shows one due card at a time.
struct ReviewView: View {
    @Query(sort: \Card.nextReviewAt) private var cards: [Card]
    @State private var revealed = false

    private var due: [Card] { cards.filter { $0.isDue() } }

    var body: some View {
        VStack(spacing: 12) {
            if let card = due.first {
                Text("\(due.count) due")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(card.sourceText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if revealed {
                    Text(card.translation)
                        .font(.title3)
                    HStack {
                        Button("Again") { grade(card, .again) }
                        Button("Got it") { grade(card, .gotIt) }
                            .keyboardShortcut(.defaultAction)
                    }
                } else {
                    Button("Show translation") { revealed = true }
                }
            } else {
                Text("All caught up 🎉")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func grade(_ card: Card, _ grade: ReviewGrade) {
        card.review(grade)
        revealed = false
    }
}

/// Menu bar label showing the number of cards due today.
struct MenuBarLabel: View {
    @Query private var cards: [Card]

    var body: some View {
        let dueCount = cards.filter { $0.isDue() }.count
        Label(dueCount > 0 ? "\(dueCount)" : "", systemImage: "character.bubble")
    }
}
