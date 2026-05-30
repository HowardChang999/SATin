import Foundation
import SwiftData

struct VocabularyQuery {
    var keyword: String = ""
    var masteredOnly: Bool = false
    var fromDate: Date?
    var toDate: Date?
}

protocol VocabularyRepository {
    func saveWord(word: String, definition: String, note: String, sourceQuestionId: String, sourceSessionId: UUID, context: ModelContext) throws
    func queryWords(_ query: VocabularyQuery, in words: [SavedWord]) -> [SavedWord]
    func exportWords(_ words: [SavedWord], format: VocabularyExportFormat) throws -> String
}

struct DefaultVocabularyRepository: VocabularyRepository {
    func saveWord(word: String, definition: String, note: String, sourceQuestionId: String, sourceSessionId: UUID, context: ModelContext) throws {
        let item = SavedWord(word: word, definition: definition, sourceQuestionId: sourceQuestionId, sourceSessionId: sourceSessionId, notes: note)
        context.insert(item)
        try context.save()
    }

    func queryWords(_ query: VocabularyQuery, in words: [SavedWord]) -> [SavedWord] {
        words.filter { word in
            let keywordPass = query.keyword.isEmpty || word.word.localizedCaseInsensitiveContains(query.keyword)
            let masteredPass = !query.masteredOnly || word.isMastered
            let fromPass = query.fromDate == nil || word.savedAt >= query.fromDate!
            let toPass = query.toDate == nil || word.savedAt <= query.toDate!
            return keywordPass && masteredPass && fromPass && toPass
        }
    }

    func exportWords(_ words: [SavedWord], format: VocabularyExportFormat) throws -> String {
        try VocabularyExporter().export(words: words, format: format)
    }
}
