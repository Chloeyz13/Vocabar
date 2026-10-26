import SwiftUI

/// A word next to its pronunciation (if known), with a button to hear it spoken aloud.
struct SpeakableWordView: View {
    let text: String
    let pronunciation: String?
    var pronunciationFont: Font = .subheadline

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text).font(.headline)
            if let pronunciation {
                Text(pronunciation)
                    .font(pronunciationFont)
                    .foregroundStyle(.secondary)
            }
            Button {
                SpeechService.speak(text)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.plain)
        }
    }
}
