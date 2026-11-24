import Foundation
import Security

/// Everything one Claude call returns about a word.
struct Enrichment: Decodable {
    struct Example: Decodable { let en: String; let zh: String }
    let translation: String
    let ipa: String
    let partOfSpeech: String
    let examples: [Example]
    let usageNote: String

    var examplesText: String {
        examples.map { "• \($0.en)\n  \($0.zh)" }.joined(separator: "\n")
    }
    /// Empty strings from the model become nil so the UI hides the row.
    var ipaOrNil: String? { ipa.isEmpty ? nil : ipa }
}

enum EnrichmentError: Error {
    case noAPIKey
    case badResponse(String)
}

/// One Messages API call per word: Simplified Chinese translation, US IPA,
/// part of speech, example sentences, and a usage note, as schema-locked JSON.
enum EnrichmentService {
    static func enrich(_ text: String) async throws -> Enrichment {
        guard let key = APIKeyStore.load() else { throw EnrichmentError.noAPIKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // Server-side refusal fallback (recommended default for Opus 5.5).
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(for: text))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let detail = String(decoding: data, as: UTF8.self).prefix(300)
            throw EnrichmentError.badResponse("HTTP \(status): \(detail)")
        }

        struct APIResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard decoded.stop_reason != "refusal",
              let json = decoded.content.first(where: { $0.type == "text" })?.text,
              let enrichment = try? JSONDecoder().decode(Enrichment.self, from: Data(json.utf8)) else {
            throw EnrichmentError.badResponse("unexpected response shape (stop_reason: \(decoded.stop_reason ?? "nil"))")
        }
        return enrichment
    }

    private static func body(for text: String) -> [String: Any] {
        let prompt = """
        You are helping a native Chinese speaker learn English vocabulary. For the English word or phrase below, provide:
        - translation: concise Simplified Chinese translation covering the main senses
        - ipa: US pronunciation in IPA between slashes, e.g. /ˌserənˈdɪpəti/ (empty string for long phrases)
        - partOfSpeech: abbreviated, e.g. "n." — or per-sense like "n. 机缘巧合 / v. 偶然发现" when senses differ
        - examples: 2-3 short, natural, common example sentences, each with its Simplified Chinese translation
        - usageNote: 1-2 sentences in Simplified Chinese covering register, common collocations, and easily confused words

        Word or phrase: \(text)
        """
        let exampleSchema: [String: Any] = [
            "type": "object",
            "properties": ["en": ["type": "string"], "zh": ["type": "string"]],
            "required": ["en", "zh"],
            "additionalProperties": false,
        ]
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "translation": ["type": "string"],
                "ipa": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "examples": ["type": "array", "items": exampleSchema],
                "usageNote": ["type": "string"],
            ],
            "required": ["translation", "ipa", "partOfSpeech", "examples", "usageNote"],
            "additionalProperties": false,
        ]
        return [
            "model": "claude-opus-5-5",
            "max_tokens": 2000,
            "fallbacks": "default",
            // Low effort: simple structured task; keeps the popup snappy.
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": prompt]],
        ]
    }
}

/// Keychain-backed storage for the Anthropic API key.
enum APIKeyStore {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.chloeshen.TranslationReview",
        kSecAttrAccount as String: "anthropic-api-key",
    ]

    static func load() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    static func save(_ key: String) {
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
