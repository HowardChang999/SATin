import Testing
@testable import SATin
import Foundation

@Test func dictionaryNormalization() async throws {
    let service = OfflineDictionaryService()
    #expect(service.normalize(term: " Delicate, ") == "delicate")
}

@Test func dictionaryLookupHitAndMiss() async throws {
    let service = OfflineDictionaryService()
    #expect(service.lookup(term: "delicate") != nil)
    #expect(service.lookup(term: "nonexistentterm") == nil)
}

@Test func scoringFormulaProducesReasonableRange() async throws {
    let svc = PracticeScoringService()
    let breakdown = svc.score(attempts: [
        (true, .hard, 70),
        (true, .medium, 90),
        (false, .easy, 120)
    ])
    #expect(breakdown.finalScore >= 0)
    #expect(breakdown.finalScore <= 100)
    #expect(breakdown.accuracyScore > 60)
}

@Test func vocabularyExportFormats() async throws {
    let word = SavedWord(
        word: "delicate",
        definition: "Easily affected.",
        sourceQuestionId: "q1",
        sourceSessionId: UUID(),
        notes: "review",
        isMastered: false
    )
    let exporter = VocabularyExporter()

    let csv = try exporter.export(words: [word], format: .csv)
    #expect(csv.contains("word,definition"))

    let json = try exporter.export(words: [word], format: .json)
    #expect(json.contains("delicate"))

    let md = try exporter.export(words: [word], format: .markdown)
    #expect(md.contains("| Word | Definition"))
}

@Test func pdfQuestionBlockSplitting() async throws {
    let raw = """
    Question ID: q1
    SAT | Reading and Writing | Information and Ideas | Inferences | Medium
    Question
    Some passage
    Answer
    A. one
    B. two
    C. three
    D. four
    Correct Answer: B
    Rationale
    Because.

    Question ID: q2
    SAT | Reading and Writing | Craft and Structure | Words in Context | Easy
    Question
    Another passage
    Answer
    A. a
    B. b
    C. c
    D. d
    Correct Answer: A
    Rationale
    Why.
    """

    let service = PDFImportService()
    let blocks = service.splitQuestionBlocks(raw)
    #expect(blocks.count == 2)
}

@Test func practiceSummarySkillAggregationAndThresholds() async throws {
    let questions = [
        makeQuestion(id: "q1", skill: .inferences, difficulty: .medium),
        makeQuestion(id: "q2", skill: .inferences, difficulty: .medium),
        makeQuestion(id: "q3", skill: .wordsInContext, difficulty: .hard)
    ]
    let sessionId = UUID()
    let attempts = [
        PracticeAttempt(sessionId: sessionId, questionId: "q1", selectedAnswer: "A", wasCorrect: true, timeUsedSeconds: 30, marked: false),
        PracticeAttempt(sessionId: sessionId, questionId: "q2", selectedAnswer: "B", wasCorrect: false, timeUsedSeconds: 90, marked: true),
        PracticeAttempt(sessionId: sessionId, questionId: "q3", selectedAnswer: "A", wasCorrect: true, timeUsedSeconds: 60, marked: true)
    ]

    let summary = PracticeSummaryAnalyticsService().summarize(attempts: attempts, questions: questions)
    let inferences = try #require(summary.skillBreakdown.first { $0.skill == .inferences })
    let words = try #require(summary.skillBreakdown.first { $0.skill == .wordsInContext })

    #expect(inferences.attemptedCount == 2)
    #expect(inferences.accuracy == 50)
    #expect(inferences.averageTime == 60)
    #expect(inferences.level == .weak)
    #expect(words.level == .strong)
}

@Test func practiceSummaryMarkedBreakdown() async throws {
    let questions = [
        makeQuestion(id: "q1", skill: .inferences, difficulty: .medium),
        makeQuestion(id: "q2", skill: .wordsInContext, difficulty: .hard),
        makeQuestion(id: "q3", skill: .transitions, difficulty: .easy)
    ]
    let sessionId = UUID()
    let attempts = [
        PracticeAttempt(sessionId: sessionId, questionId: "q1", selectedAnswer: "A", wasCorrect: true, timeUsedSeconds: 30, marked: true),
        PracticeAttempt(sessionId: sessionId, questionId: "q2", selectedAnswer: "B", wasCorrect: false, timeUsedSeconds: 45, marked: true),
        PracticeAttempt(sessionId: sessionId, questionId: "q3", selectedAnswer: "C", wasCorrect: true, timeUsedSeconds: 55, marked: false)
    ]

    let marked = PracticeSummaryAnalyticsService().summarize(attempts: attempts, questions: questions).marked
    #expect(marked.total == 2)
    #expect(marked.correct == 1)
    #expect(marked.incorrect == 1)
    #expect(marked.rate > 66)
    #expect(marked.rate < 67)
}

@Test func questionExporterStructuredFormats() async throws {
    let question = makeQuestion(id: "q-export", skill: .commandOfEvidence, difficulty: .hard)
    let exporter = QuestionExporter()

    let json = try exporter.export(questions: [question], format: .json).preview
    #expect(json.contains("\"questionId\""))
    #expect(json.contains("q-export"))
    #expect(json.contains("\"choices\""))

    let csv = try exporter.export(questions: [question], format: .csv).preview
    #expect(csv.contains("questionId,assessment,test,domain,skill,difficulty"))
    #expect(csv.contains("\"q-export\""))

    let markdown = try exporter.export(questions: [question], format: .markdown, pdfMode: .questionsWithAnswersAndRationales).preview
    #expect(markdown.contains("## q-export"))
    #expect(markdown.contains("Answer: B"))
    #expect(markdown.contains("Rationale:"))
}

@Test func questionExporterPDFModesProduceExpectedPreviewAndFiles() async throws {
    let question = makeQuestion(id: "q-pdf", skill: .inferences, difficulty: .medium)
    let exporter = QuestionExporter()

    let questionsOnlyMarkdown = try exporter.export(questions: [question], format: .markdown, pdfMode: .questionsOnly).preview
    #expect(!questionsOnlyMarkdown.contains("Answer:"))
    #expect(!questionsOnlyMarkdown.contains("Rationale:"))

    let answersMarkdown = try exporter.export(questions: [question], format: .markdown, pdfMode: .questionsWithAnswers).preview
    #expect(answersMarkdown.contains("Answer: B"))
    #expect(!answersMarkdown.contains("Rationale:"))

    let fullMarkdown = try exporter.export(questions: [question], format: .markdown, pdfMode: .questionsWithAnswersAndRationales).preview
    #expect(fullMarkdown.contains("Answer: B"))
    #expect(fullMarkdown.contains("Rationale:"))

    let pdf = try exporter.export(questions: [question], format: .pdf, pdfMode: .questionsWithAnswers)
    let url = try #require(pdf.fileURL)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0) > 0)
}

private func makeQuestion(id: String, skill: Skill, difficulty: Difficulty) -> Question {
    Question(
        questionId: id,
        assessment: "SAT",
        test: TestType.readingAndWriting.rawValue,
        domain: .informationAndIdeas,
        skill: skill,
        difficulty: difficulty,
        questionText: "A short passage for \(id).",
        prompt: "Which choice best answers the question?",
        choices: .init(a: "Choice one", b: "Choice two", c: "Choice three", d: "Choice four"),
        correctAnswer: "B",
        rationale: "Choice B is best supported by the passage.",
        sourcePdfName: "source.pdf",
        sourcePageRangeStart: 1,
        sourcePageRangeEnd: 1
    )
}
