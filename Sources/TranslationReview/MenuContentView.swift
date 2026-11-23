import SwiftUI

/// Menu bar popover content: Review and Deck tabs.
/// Quit lives in the status item's right-click menu (StatusItemController).
struct MenuContentView: View {
    enum Tab: String, CaseIterable {
        case review = "Review"
        case deck = "Deck"
    }

    @State private var tab: Tab = .review

    var body: some View {
        VStack(spacing: 12) {
            Picker("View", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch tab {
                case .review: ReviewView()
                case .deck: DeckView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding()
        .frame(width: 300, height: 420)
    }
}
