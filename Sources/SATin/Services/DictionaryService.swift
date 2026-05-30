import Foundation

struct DefinitionResult: Codable, Equatable {
    let term: String
    let definition: String
    let example: String?
}

protocol LocalDictionaryService {
    func lookup(term: String) -> DefinitionResult?
    func normalize(term: String) -> String
}

final class OfflineDictionaryService: LocalDictionaryService {
    private let entries: [String: DefinitionResult]

    init(bundle: Bundle = .main) {
        let resolvedBundle: Bundle = {
            if bundle.url(forResource: "offline_dictionary", withExtension: "json") != nil {
                return bundle
            }
            #if SWIFT_PACKAGE
            return .module
            #else
            return bundle
            #endif
        }()

        if let url = resolvedBundle.url(forResource: "offline_dictionary", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: DefinitionResult].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    func lookup(term: String) -> DefinitionResult? {
        let normalized = normalize(term: term)
        return entries[normalized]
    }

    func normalize(term: String) -> String {
        term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters)
    }
}
