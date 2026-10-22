import SwiftUI

/// Menu bar popover content: Review and Deck tabs, plus Quit.
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

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300, height: 420)
    }
}
