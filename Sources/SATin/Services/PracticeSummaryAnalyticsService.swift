import Foundation

struct SkillSummary: Identifiable, Hashable {
    enum Level: String {
        case weak = "Weak"
        case normal = "Normal"
        case strong = "Strong"
    }

    let id: Skill
    let skill: Skill
    let attemptedCount: Int
    let correctCount: Int
    let accuracy: Double
    let averageTime: Double
    let level: Level
}

struct QuestionReviewItem: Identifiable, Hashable {
    let id: String
    let question: Question
    let attempt: PracticeAttempt

    var resultText: String { attempt.wasCorrect ? "Correct" : "Incorrect" }
}

struct MarkedSummary: Hashable {
    let total: Int
    let correct: Int
    let incorrect: Int
    let rate: Double
}

struct PracticeSummaryAnalytics {
    let skillBreakdown: [SkillSummary]
    let reviewItems: [QuestionReviewItem]
    let marked: MarkedSummary
}

struct PracticeSummaryAnalyticsService {
    func summarize(attempts: [PracticeAttempt], questions: [Question]) -> PracticeSummaryAnalytics {
        let questionsById = Dictionary(uniqueKeysWithValues: questions.map { ($0.questionId, $0) })
        let reviewItems = attempts.compactMap { attempt -> QuestionReviewItem? in
            guard let question = questionsById[attempt.questionId] else { return nil }
            return QuestionReviewItem(id: "\(attempt.id.uuidString)-\(question.questionId)", question: question, attempt: attempt)
        }

        let groupedBySkill = Dictionary(grouping: reviewItems, by: { $0.question.skill })
        let skillBreakdown = groupedBySkill.map { skill, items in
            let attempted = items.count
            let correct = items.filter { $0.attempt.wasCorrect }.count
            let accuracy = attempted == 0 ? 0 : Double(correct) / Double(attempted) * 100
            let totalTime = items.reduce(0) { $0 + $1.attempt.timeUsedSeconds }
            let averageTime = attempted == 0 ? 0 : totalTime / Double(attempted)
            return SkillSummary(
                id: skill,
                skill: skill,
                attemptedCount: attempted,
                correctCount: correct,
                accuracy: accuracy,
                averageTime: averageTime,
                level: level(for: accuracy)
            )
        }
        .sorted { $0.skill.rawValue < $1.skill.rawValue }

        let markedItems = reviewItems.filter { $0.attempt.marked }
        let markedCorrect = markedItems.filter { $0.attempt.wasCorrect }.count
        let marked = MarkedSummary(
            total: markedItems.count,
            correct: markedCorrect,
            incorrect: markedItems.count - markedCorrect,
            rate: attempts.isEmpty ? 0 : Double(markedItems.count) / Double(attempts.count) * 100
        )

        return PracticeSummaryAnalytics(
            skillBreakdown: skillBreakdown,
            reviewItems: reviewItems,
            marked: marked
        )
    }

    func level(for accuracy: Double) -> SkillSummary.Level {
        if accuracy < 60 { return .weak }
        if accuracy < 80 { return .normal }
        return .strong
    }
}
