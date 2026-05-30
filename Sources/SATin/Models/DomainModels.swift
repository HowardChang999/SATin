import Foundation
import SwiftData

enum TestType: String, Codable, CaseIterable, Identifiable {
    case readingAndWriting = "Reading and Writing"
    var id: String { rawValue }
}

enum Domain: String, Codable, CaseIterable, Identifiable {
    case informationAndIdeas = "Information and Ideas"
    case craftAndStructure = "Craft and Structure"
    case expressionOfIdeas = "Expression of Ideas"
    case standardEnglishConventions = "Standard English Conventions"

    var id: String { rawValue }
}

enum Skill: String, Codable, CaseIterable, Identifiable {
    case centralIdeasAndDetails = "Central Ideas and Details"
    case inferences = "Inferences"
    case commandOfEvidence = "Command of Evidence"
    case wordsInContext = "Words in Context"
    case textStructureAndPurpose = "Text Structure and Purpose"
    case crossTextConnections = "Cross-Text Connections"
    case rhetoricalSynthesis = "Rhetorical Synthesis"
    case transitions = "Transitions"
    case boundaries = "Boundaries"
    case formStructureAndSense = "Form, Structure, and Sense"

    var id: String { rawValue }

    static func skills(for domain: Domain) -> [Skill] {
        switch domain {
        case .informationAndIdeas:
            return [.centralIdeasAndDetails, .inferences, .commandOfEvidence]
        case .craftAndStructure:
            return [.wordsInContext, .textStructureAndPurpose, .crossTextConnections]
        case .expressionOfIdeas:
            return [.rhetoricalSynthesis, .transitions]
        case .standardEnglishConventions:
            return [.boundaries, .formStructureAndSense]
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
    var weightScore: Double {
        switch self {
        case .easy: return 60
        case .medium: return 80
        case .hard: return 100
        }
    }
}

enum TranslationLanguage: String, Codable, CaseIterable, Identifiable {
    case simplifiedChinese = "Simplified Chinese"
    case traditionalChinese = "Traditional Chinese"
    case spanish = "Spanish"
    case korean = "Korean"
    case arabic = "Arabic"
    case japanese = "Japanese"
    case custom = "Custom"

    var id: String { rawValue }
}

enum TranslationQuality: String, Codable, CaseIterable, Identifiable {
    case fast = "Fast"
    case balanced = "Balanced"
    case highQuality = "High Quality"

    var id: String { rawValue }
}

enum PracticeQuestionSource: String, Codable, CaseIterable, Identifiable {
    case allQuestions = "All Questions"
    case newQuestionsOnly = "New Questions Only"
    case mistakesOnly = "Mistakes Only"
    case markedQuestions = "Marked Questions"
    case importedSet = "Imported Set"

    var id: String { rawValue }
}

enum VocabularyExportFormat: String, Codable, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case markdown = "Markdown"

    var id: String { rawValue }
}

enum QuestionExportFormat: String, Codable, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    case markdown = "Markdown"
    case pdf = "PDF"

    var id: String { rawValue }
}

enum QuestionPDFExportMode: String, Codable, CaseIterable, Identifiable {
    case questionsOnly = "Questions Only"
    case questionsWithAnswers = "Questions with Answers"
    case questionsWithAnswersAndRationales = "Questions with Answers and Rationales"

    var id: String { rawValue }

    var includesAnswers: Bool {
        self != .questionsOnly
    }

    var includesRationales: Bool {
        self == .questionsWithAnswersAndRationales
    }
}

struct ChoiceSet: Codable, Hashable {
    var a: String
    var b: String
    var c: String
    var d: String
}

struct FigureAsset: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var type: String
    var fileName: String
}

@Model
final class Question {
    @Attribute(.unique) var questionId: String
    var assessment: String
    var test: String
    var domainRaw: String
    var skillRaw: String
    var difficultyRaw: String
    var questionText: String
    var prompt: String
    var choices: ChoiceSet
    var correctAnswer: String
    var rationale: String
    var figureAssets: [FigureAsset]
    var sourcePdfName: String
    var sourcePageRangeStart: Int
    var sourcePageRangeEnd: Int
    var createdAt: Date

    init(
        questionId: String,
        assessment: String,
        test: String,
        domain: Domain,
        skill: Skill,
        difficulty: Difficulty,
        questionText: String,
        prompt: String,
        choices: ChoiceSet,
        correctAnswer: String,
        rationale: String,
        figureAssets: [FigureAsset] = [],
        sourcePdfName: String = "",
        sourcePageRangeStart: Int = 0,
        sourcePageRangeEnd: Int = 0,
        createdAt: Date = .now
    ) {
        self.questionId = questionId
        self.assessment = assessment
        self.test = test
        self.domainRaw = domain.rawValue
        self.skillRaw = skill.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.questionText = questionText
        self.prompt = prompt
        self.choices = choices
        self.correctAnswer = correctAnswer
        self.rationale = rationale
        self.figureAssets = figureAssets
        self.sourcePdfName = sourcePdfName
        self.sourcePageRangeStart = sourcePageRangeStart
        self.sourcePageRangeEnd = sourcePageRangeEnd
        self.createdAt = createdAt
    }

    var domain: Domain { Domain(rawValue: domainRaw) ?? .informationAndIdeas }
    var skill: Skill { Skill(rawValue: skillRaw) ?? .commandOfEvidence }
    var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .medium }
}

@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var totalTimeSeconds: Double
    var questionCount: Int
    var correctCount: Int
    var markedCount: Int
    var practiceScore: Double

    init(id: UUID = UUID(), startedAt: Date = .now, endedAt: Date? = nil, totalTimeSeconds: Double = 0, questionCount: Int = 0, correctCount: Int = 0, markedCount: Int = 0, practiceScore: Double = 0) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalTimeSeconds = totalTimeSeconds
        self.questionCount = questionCount
        self.correctCount = correctCount
        self.markedCount = markedCount
        self.practiceScore = practiceScore
    }
}

@Model
final class PracticeAttempt {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var questionId: String
    var selectedAnswer: String
    var wasCorrect: Bool
    var timeUsedSeconds: Double
    var marked: Bool
    var submittedAt: Date

    init(id: UUID = UUID(), sessionId: UUID, questionId: String, selectedAnswer: String, wasCorrect: Bool, timeUsedSeconds: Double, marked: Bool, submittedAt: Date = .now) {
        self.id = id
        self.sessionId = sessionId
        self.questionId = questionId
        self.selectedAnswer = selectedAnswer
        self.wasCorrect = wasCorrect
        self.timeUsedSeconds = timeUsedSeconds
        self.marked = marked
        self.submittedAt = submittedAt
    }
}

@Model
final class MistakeEntry {
    @Attribute(.unique) var id: UUID
    var questionId: String
    var lastSeenAt: Date

    init(id: UUID = UUID(), questionId: String, lastSeenAt: Date = .now) {
        self.id = id
        self.questionId = questionId
        self.lastSeenAt = lastSeenAt
    }
}

@Model
final class MarkedEntry {
    @Attribute(.unique) var id: UUID
    var questionId: String
    var markedAt: Date

    init(id: UUID = UUID(), questionId: String, markedAt: Date = .now) {
        self.id = id
        self.questionId = questionId
        self.markedAt = markedAt
    }
}

@Model
final class SavedWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var lemma: String?
    var definition: String
    var example: String?
    var sourceQuestionId: String
    var sourceSessionId: UUID
    var savedAt: Date
    var notes: String
    var isMastered: Bool

    init(id: UUID = UUID(), word: String, lemma: String? = nil, definition: String, example: String? = nil, sourceQuestionId: String, sourceSessionId: UUID, savedAt: Date = .now, notes: String = "", isMastered: Bool = false) {
        self.id = id
        self.word = word
        self.lemma = lemma
        self.definition = definition
        self.example = example
        self.sourceQuestionId = sourceQuestionId
        self.sourceSessionId = sourceSessionId
        self.savedAt = savedAt
        self.notes = notes
        self.isMastered = isMastered
    }
}

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var name: String
    var testDate: Date
    var translationLanguageRaw: String
    var translationQualityRaw: String
    var customLanguageName: String

    init(id: UUID = UUID(), name: String = "Student", testDate: Date = .now.addingTimeInterval(60 * 60 * 24 * 30), translationLanguage: TranslationLanguage = .simplifiedChinese, translationQuality: TranslationQuality = .balanced, customLanguageName: String = "") {
        self.id = id
        self.name = name
        self.testDate = testDate
        self.translationLanguageRaw = translationLanguage.rawValue
        self.translationQualityRaw = translationQuality.rawValue
        self.customLanguageName = customLanguageName
    }

    var translationLanguage: TranslationLanguage { TranslationLanguage(rawValue: translationLanguageRaw) ?? .simplifiedChinese }
    var translationQuality: TranslationQuality { TranslationQuality(rawValue: translationQualityRaw) ?? .balanced }
}

@Model
final class ImportBatch {
    @Attribute(.unique) var id: UUID
    var sourcePdfName: String
    var importedAt: Date
    var questionCount: Int

    init(id: UUID = UUID(), sourcePdfName: String, importedAt: Date = .now, questionCount: Int) {
        self.id = id
        self.sourcePdfName = sourcePdfName
        self.importedAt = importedAt
        self.questionCount = questionCount
    }
}
