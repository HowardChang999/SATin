import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    @Published var selectedAnswer: String?
    @Published var hasSubmitted = false
    @Published var isMarked = false
    @Published var translatedRationale: String = ""
    @Published var selectedWord: String = ""
    @Published var selectedWordDefinition: DefinitionResult?
    @Published var wordNote: String = ""
    @Published var toastMessage: String?

    private let dictionaryService: LocalDictionaryService
    private let translationService: RationaleTranslationService

    init(dictionaryService: LocalDictionaryService = OfflineDictionaryService(), translationService: RationaleTranslationService = LocalMLXTranslationService()) {
        self.dictionaryService = dictionaryService
        self.translationService = translationService
    }

    func submit() {
        hasSubmitted = true
    }

    func lookupSelectedWord() {
        selectedWordDefinition = dictionaryService.lookup(term: selectedWord)
    }

    func saveSelectedWord(question: Question, sessionId: UUID, context: ModelContext) {
        guard let definition = selectedWordDefinition else { return }

        let saved = SavedWord(
            word: dictionaryService.normalize(term: selectedWord),
            lemma: nil,
            definition: definition.definition,
            example: definition.example,
            sourceQuestionId: question.questionId,
            sourceSessionId: sessionId,
            notes: wordNote,
            isMastered: false
        )
        context.insert(saved)
        do {
            try context.save()
            toastMessage = "Saved '\(saved.word)' to Vocabulary"
            wordNote = ""
        } catch {
            toastMessage = "Failed to save word"
        }
    }

    func translateRationale(question: Question, settings: UserSettings?) {
        translatedRationale = translationService.translate(
            question.rationale,
            to: settings?.translationLanguage ?? .simplifiedChinese,
            quality: settings?.translationQuality ?? .balanced
        )
    }

    func resetForNextQuestion() {
        selectedAnswer = nil
        hasSubmitted = false
        isMarked = false
        translatedRationale = ""
        selectedWord = ""
        selectedWordDefinition = nil
        wordNote = ""
    }
}
