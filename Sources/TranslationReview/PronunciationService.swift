import Foundation
import CoreServices

/// Looks up a word's pronunciation using macOS's built-in Dictionary Services (the same
/// data behind right-click → Look Up). Best-effort: returns nil for phrases or words with
/// no dictionary entry.
enum PronunciationService {
    static func pronunciation(for text: String) -> String? {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return nil }
        let cfWord = word as CFString
        let range = CFRange(location: 0, length: CFStringGetLength(cfWord))
        guard let definition = DCSCopyTextDefinition(nil, cfWord, range)?.takeRetainedValue() as String? else {
            return nil
        }
        return extractPronunciation(from: definition)
    }

    // ponytail: system dictionary entries start "headword | pronunciation |", e.g.
    // "word | wɜːrd |\nnoun\n...". Parsing the raw text is best-effort; a format mismatch
    // just hides the pronunciation rather than crashing.
    static func extractPronunciation(from definition: String) -> String? {
        guard let firstLine = definition.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first else {
            return nil
        }
        let parts = firstLine.components(separatedBy: "|")
        guard parts.count >= 2 else { return nil }
        let pronunciation = parts[1].trimmingCharacters(in: .whitespaces)
        return pronunciation.isEmpty ? nil : pronunciation
    }
}
