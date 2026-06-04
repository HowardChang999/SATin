import SwiftUI
import SwiftData
import Charts

struct PracticeContainerView: View {
    @Query(sort: \Question.createdAt) private var questions: [Question]
    @Query private var settings: [UserSettings]
    @Query private var attempts: [PracticeAttempt]
    @Environment(\.modelContext) private var modelContext

    @StateObject private var vm = PracticeSessionViewModel()
    @State private var selectedDomain: Domain? = nil
    @State private var selectedSkill: Skill? = nil
    @State private var selectedDifficulty: Difficulty? = nil
    @State private var numberOfQuestions: Int = 5
    @State private var isUnlimitedMode = false
    @State private var currentIndex = 0
    @State private var hasStarted = false
    @State private var session = PracticeSession()
    @State private var retryQuestionIds: Set<String>?

    @State private var attemptCountForCurrentQuestion = 0
    @State private var lastSubmissionWrong = false
    @State private var canShowAnswer = false
    @State private var resolvedByShowAnswer = false
    @State private var showSummaryAfterEnd = false
    @State private var liveAttempts: [PracticeAttempt] = []
    @State private var submissionFeedback: String = ""
    @State private var questionStartedAt = Date()
    @State private var questionFinishedAt: Date?

    var body: some View {
        ZStack {
            if showSummaryAfterEnd {
                PracticeSummaryView(session: session, attempts: liveAttempts, questions: filteredQuestions) { questionIds in
                    startMistakePractice(questionIds: questionIds)
                }
                    .overlay(alignment: .topLeading) {
                        Button {
                            showSummaryAfterEnd = false
                            hasStarted = false
                            retryQuestionIds = nil
                        } label: {
                            Label("Back to Setup", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .padding(24)
                    }
                    .transition(.opacity)
            } else if hasStarted {
                practiceRunner
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                filterView
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.95), value: hasStarted)
        .animation(.spring(response: 0.3, dampingFraction: 0.95), value: showSummaryAfterEnd)
    }

    private var filteredQuestions: [Question] {
        if let retryQuestionIds {
            return questions.filter { retryQuestionIds.contains($0.questionId) }
        }

        let base = questions.filter { q in
            let domainPass = selectedDomain == nil || q.domain == selectedDomain
            let skillPass = selectedSkill == nil || q.skill == selectedSkill
            let difficultyPass = selectedDifficulty == nil || q.difficulty == selectedDifficulty
            return domainPass && skillPass && difficultyPass
        }
        if isUnlimitedMode { return base }
        return Array(base.prefix(numberOfQuestions))
    }

    private var currentQuestion: Question? {
        guard currentIndex < filteredQuestions.count else { return nil }
        return filteredQuestions[currentIndex]
    }

    private var skillOptions: [Skill] {
        if let selectedDomain {
            return Skill.skills(for: selectedDomain)
        }
        return Skill.allCases
    }

    private var filterView: some View {
        HStack(alignment: .top, spacing: 18) {
            Form {
                Section("Question Set") {
                    Picker("Test", selection: .constant(TestType.readingAndWriting)) {
                        Text(TestType.readingAndWriting.rawValue).tag(TestType.readingAndWriting)
                    }
                    Picker("Domain", selection: $selectedDomain) {
                        Text("All").tag(Domain?.none)
                        ForEach(Domain.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    Picker("Skill", selection: $selectedSkill) {
                        Text("All").tag(Skill?.none)
                        ForEach(skillOptions) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        Text("All").tag(Difficulty?.none)
                        ForEach(Difficulty.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                }

                Section("Session") {
                    Stepper("Questions: \(numberOfQuestions)", value: $numberOfQuestions, in: 1...50)
                        .disabled(isUnlimitedMode)
                    Toggle("Unlimited", isOn: $isUnlimitedMode)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(width: 430)

            VStack(alignment: .leading, spacing: 14) {
                Label("Ready to begin?", systemImage: "play.circle")
                    .font(.title2.weight(.semibold))
                Text("SATin will record accuracy, timing, marked questions, and mistake review data for this session.")
                    .foregroundStyle(.secondary)
                Divider()
                Label("\(filteredQuestions.count) questions match these filters", systemImage: "checklist")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    startPractice()
                } label: {
                    Label("Start Practice", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(filteredQuestions.isEmpty && !questions.isEmpty)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 360, maxHeight: .infinity, alignment: .topLeading)
            .satinCard()
        }
        .padding(24)
    }

    private var practiceRunner: some View {
        Group {
            if let q = currentQuestion {
                HStack(alignment: .top, spacing: 20) {
                    leftQuestionPanel(q)
                    rightAnswerPanel(q)
                }
                .padding(24)
            } else {
                PracticeSummaryView(session: session, attempts: attempts.filter { $0.sessionId == session.id }, questions: filteredQuestions) { questionIds in
                    startMistakePractice(questionIds: questionIds)
                }
            }
        }
    }

    private func leftQuestionPanel(_ q: Question) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(q.domain.rawValue) · \(q.skill.rawValue) · \(q.difficulty.rawValue) · ID: \(q.questionId)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(isUnlimitedMode ? "Question \(currentIndex + 1)" : "Question \(currentIndex + 1) of \(filteredQuestions.count)")
                .font(.headline)

            if vm.hasSubmitted {
                Text(q.questionText).textSelection(.enabled)
                Text(q.prompt).textSelection(.enabled)
            } else {
                Text(q.questionText)
                Text(q.prompt)
            }

            if vm.hasSubmitted {
                Text("Answer: \(q.correctAnswer)")
                    .font(.headline)
                    .foregroundStyle(.green)
                Button("Translate Rationale") { vm.translateRationale(question: q, settings: settings.first) }
                Text(vm.translatedRationale.isEmpty ? q.rationale : vm.translatedRationale)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Divider().padding(.vertical, 4)
                Text("Vocabulary").font(.headline)
                HStack {
                    TextField("Select/enter an unfamiliar word", text: $vm.selectedWord)
                    Button("Define") { vm.lookupSelectedWord() }
                }
                if let def = vm.selectedWordDefinition {
                    Text(def.definition)
                    TextField("Optional note", text: $vm.wordNote)
                    Button("Save Word") {
                        vm.saveSelectedWord(question: q, sessionId: session.id, context: modelContext)
                    }
                }
                if let toast = vm.toastMessage {
                    Text(toast).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .satinCard()
    }

    private func rightAnswerPanel(_ q: Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choices")
                    .font(.headline)
                Spacer()
                timerBadge
            }

            choiceButton("A", q.choices.a)
            choiceButton("B", q.choices.b)
            choiceButton("C", q.choices.c)
            choiceButton("D", q.choices.d)

            if !submissionFeedback.isEmpty && !vm.hasSubmitted {
                Text(submissionFeedback)
                    .foregroundStyle(lastSubmissionWrong ? .red : .secondary)
                    .fontWeight(.semibold)
            }

            if canShowAnswer && !vm.hasSubmitted {
                Button("Show Answer") {
                    resolvedByShowAnswer = true
                    vm.hasSubmitted = true
                    questionFinishedAt = .now
                    submissionFeedback = "Answer revealed."
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            HStack {
                Toggle("Mark", isOn: $vm.isMarked)
                Spacer()
                Button("Submit") { submitCurrentQuestion(q) }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.selectedAnswer == nil || vm.hasSubmitted)
                Button("Next") { nextQuestion(q) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.hasSubmitted)
                Button("End") { endPractice() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(minWidth: 430, maxWidth: 430, maxHeight: .infinity, alignment: .topLeading)
        .satinCard()
    }

    private func submitCurrentQuestion(_ q: Question) {
        guard let selected = vm.selectedAnswer else { return }
        attemptCountForCurrentQuestion += 1
        let isCorrect = selected == q.correctAnswer
        if isCorrect {
            vm.hasSubmitted = true
            questionFinishedAt = .now
            lastSubmissionWrong = false
            submissionFeedback = "Correct."
        } else {
            lastSubmissionWrong = true
            canShowAnswer = true
            submissionFeedback = "Incorrect (Attempt \(attemptCountForCurrentQuestion)). Try again or tap Show Answer."
        }
    }

    private func choiceButton(_ letter: String, _ text: String) -> some View {
        Button(action: {
            if !vm.hasSubmitted { vm.selectedAnswer = letter }
        }) {
            HStack(alignment: .top) {
                Text("\(letter).")
                    .fontWeight(.bold)
                Text(text)
                    .multilineTextAlignment(.leading)
                Spacer()
                if vm.selectedAnswer == letter {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(buttonBackground(for: letter))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .satinPress()
    }

    private func buttonBackground(for letter: String) -> Color {
        guard vm.hasSubmitted, let q = currentQuestion else {
            return vm.selectedAnswer == letter ? Color.blue.opacity(0.15) : Color.gray.opacity(0.08)
        }
        if letter == q.correctAnswer { return Color.green.opacity(0.2) }
        if vm.selectedAnswer == letter && letter != q.correctAnswer { return Color.red.opacity(0.2) }
        return Color.gray.opacity(0.08)
    }

    private func nextQuestion(_ q: Question) {
        guard vm.hasSubmitted else { return }

        let wasCorrect = (vm.selectedAnswer == q.correctAnswer) || resolvedByShowAnswer
        let attempt = PracticeAttempt(
            sessionId: session.id,
            questionId: q.questionId,
            selectedAnswer: vm.selectedAnswer ?? "",
            wasCorrect: wasCorrect,
            timeUsedSeconds: recordedTimeUsed(),
            marked: vm.isMarked
        )
        modelContext.insert(attempt)
        liveAttempts.append(attempt)
        if !wasCorrect { modelContext.insert(MistakeEntry(questionId: q.questionId)) }
        if vm.isMarked { modelContext.insert(MarkedEntry(questionId: q.questionId)) }

        session.questionCount += 1
        session.correctCount += wasCorrect ? 1 : 0
        session.markedCount += vm.isMarked ? 1 : 0

        currentIndex += 1
        resetQuestionState()
    }

    private func resetQuestionState() {
        vm.resetForNextQuestion()
        attemptCountForCurrentQuestion = 0
        lastSubmissionWrong = false
        canShowAnswer = false
        resolvedByShowAnswer = false
        submissionFeedback = ""
        questionStartedAt = .now
        questionFinishedAt = nil
    }

    private func endPractice() {
        session.endedAt = .now
        currentIndex = filteredQuestions.count
        showSummaryAfterEnd = true
        hasStarted = false
        resetQuestionState()
        try? modelContext.save()
    }

    private var timerBadge: some View {
        TimelineView(.periodic(from: questionStartedAt, by: 1)) { context in
            let endDate = questionFinishedAt ?? context.date
            Label(formattedElapsed(endDate.timeIntervalSince(questionStartedAt)), systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SATinStyle.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(SATinStyle.primary.opacity(0.10))
                .clipShape(Capsule())
        }
    }

    private func startPractice() {
        if questions.isEmpty { seedSampleQuestion() }
        retryQuestionIds = nil
        beginSession()
    }

    private func startMistakePractice(questionIds: [String]) {
        guard !questionIds.isEmpty else { return }
        retryQuestionIds = Set(questionIds)
        beginSession()
    }

    private func beginSession() {
        session = PracticeSession(startedAt: .now)
        modelContext.insert(session)
        liveAttempts = []
        currentIndex = 0
        showSummaryAfterEnd = false
        hasStarted = true
        resetQuestionState()
    }

    private func recordedTimeUsed() -> Double {
        max(1, (questionFinishedAt ?? .now).timeIntervalSince(questionStartedAt))
    }

    private func formattedElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func seedSampleQuestion() {
        let q = Question(
            questionId: UUID().uuidString.prefix(8).lowercased(),
            assessment: "SAT",
            test: TestType.readingAndWriting.rawValue,
            domain: selectedDomain ?? .informationAndIdeas,
            skill: selectedSkill ?? .centralIdeasAndDetails,
            difficulty: selectedDifficulty ?? .medium,
            questionText: "Many marine ecosystems depend on a delicate balance of temperature and salinity.",
            prompt: "Which choice best states the main idea of the passage?",
            choices: .init(a: "Marine ecosystems are unaffected by climate.", b: "Temperature and salinity are important to marine balance.", c: "Salinity is always more important than temperature.", d: "Only deep oceans are affected."),
            correctAnswer: "B",
            rationale: "The passage highlights both temperature and salinity as central factors.",
            sourcePdfName: "seed"
        )
        modelContext.insert(q)
        try? modelContext.save()
    }
}

private struct RadarPoint: Identifiable {
    let id = UUID()
    let axis: String
    let value: Double
}

struct PracticeSummaryView: View {
    let session: PracticeSession
    let attempts: [PracticeAttempt]
    let questions: [Question]
    let onPracticeMistakes: ([String]) -> Void

    @State private var selectedReviewItem: QuestionReviewItem?

    var body: some View {
        let scoring = PracticeScoringService().score(attempts: attempts.map { attempt in
            let difficulty = questions.first(where: { $0.questionId == attempt.questionId })?.difficulty ?? .medium
            return (attempt.wasCorrect, difficulty, attempt.timeUsedSeconds)
        })
        let accuracy = session.questionCount == 0 ? 0 : Double(session.correctCount) / Double(session.questionCount) * 100
        let analytics = PracticeSummaryAnalyticsService().summarize(attempts: attempts, questions: questions)
        let mistakeQuestionIds = Array(Set(attempts.filter { !$0.wasCorrect }.map(\.questionId))).sorted()
        let radar = [
            RadarPoint(axis: "Accuracy", value: scoring.accuracyScore),
            RadarPoint(axis: "Speed", value: scoring.speedScore),
            RadarPoint(axis: "Difficulty", value: scoring.difficultyScore),
            RadarPoint(axis: "Consistency", value: max(0, min(100, 100 - abs(accuracy - scoring.speedScore))))
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Practice Summary", systemImage: "chart.bar.xaxis")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SATinStyle.text)
                    Spacer()
                    Button {
                        onPracticeMistakes(mistakeQuestionIds)
                    } label: {
                        Label("Practice Mistakes", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SATinStyle.primary)
                    .disabled(mistakeQuestionIds.isEmpty)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    PlaceholderCard(title: "Total Questions", value: "\(session.questionCount)", index: 0)
                    PlaceholderCard(title: "Correct Answers", value: "\(session.correctCount)", index: 1)
                    PlaceholderCard(title: "Accuracy", value: String(format: "%.1f%%", accuracy), index: 2)
                    PlaceholderCard(title: "Practice Score", value: String(format: "%.1f", scoring.finalScore), index: 3)
                    PlaceholderCard(title: "Marked", value: "\(analytics.marked.total)", index: 4)
                    PlaceholderCard(title: "Marked Rate", value: String(format: "%.1f%%", analytics.marked.rate), index: 5)
                }

                HStack(spacing: 12) {
                    PlaceholderCard(title: "Marked Correct", value: "\(analytics.marked.correct)", index: 6)
                    PlaceholderCard(title: "Marked Incorrect", value: "\(analytics.marked.incorrect)", index: 7)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Performance", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                    Chart(radar) { item in
                        BarMark(
                            x: .value("Axis", item.axis),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(SATinStyle.primary)
                    }
                    .frame(height: 190)
                }
                .padding(14)
                .satinCard()
                .satinAppear(8)

                VStack(spacing: 8) {
                    HStack {
                        Label("Skill Breakdown", systemImage: "target")
                            .font(.headline)
                        Spacer()
                    }
                    if analytics.skillBreakdown.isEmpty {
                        Text("No attempted skills in this session.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .satinAppear(9)
                    } else {
                        ForEach(Array(analytics.skillBreakdown.enumerated()), id: \.element.id) { offset, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.skill.rawValue).font(.headline)
                                    Text("\(item.attemptedCount) attempted · \(String(format: "%.1f", item.averageTime))s avg")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", item.accuracy))
                                    .font(.headline)
                                Text(item.level.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(levelColor(item.level).opacity(0.16))
                                    .foregroundStyle(levelColor(item.level))
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .satinCard()
                            .satinAppear(Double(offset + 9))
                        }
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Label("Question Review", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                        Spacer()
                    }
                    ForEach(Array(analytics.reviewItems.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            selectedReviewItem = item
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.question.questionId).font(.headline)
                                    Text("\(item.question.domain.rawValue) · \(item.question.skill.rawValue) · \(item.question.difficulty.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.attempt.marked ? "Marked" : "Unmarked")
                                    .font(.caption)
                                    .foregroundStyle(item.attempt.marked ? .orange : .secondary)
                                Text(String(format: "%.0fs", item.attempt.timeUsedSeconds))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.resultText)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.attempt.wasCorrect ? Color.green.opacity(0.16) : Color.red.opacity(0.16))
                                    .foregroundStyle(item.attempt.wasCorrect ? .green : .red)
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .satinCard()
                        .satinAppear(Double(analytics.skillBreakdown.count + 10 + offset))
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $selectedReviewItem) { item in
            SummaryQuestionReviewSheet(item: item)
        }
    }

    private func levelColor(_ level: SkillSummary.Level) -> Color {
        switch level {
        case .weak: return .red
        case .normal: return .orange
        case .strong: return .green
        }
    }
}

private struct SummaryQuestionReviewSheet: View {
    let item: QuestionReviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.question.questionId).font(.title2.bold())
                    Text("\(item.question.domain.rawValue) · \(item.question.skill.rawValue) · \(item.question.difficulty.rawValue)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.question.questionText).textSelection(.enabled)
                    Text(item.question.prompt).font(.headline).textSelection(.enabled)
                    choiceLine("A", item.question.choices.a)
                    choiceLine("B", item.question.choices.b)
                    choiceLine("C", item.question.choices.c)
                    choiceLine("D", item.question.choices.d)

                    Divider()
                    Text("Selected: \(item.attempt.selectedAnswer)")
                    Text("Correct: \(item.question.correctAnswer)")
                        .foregroundStyle(.green)
                    Text("Rationale").font(.headline)
                    Text(item.question.rationale).textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
    }

    private func choiceLine(_ letter: String, _ text: String) -> some View {
        HStack(alignment: .top) {
            Text("\(letter).").fontWeight(.bold)
            Text(text).textSelection(.enabled)
            Spacer()
        }
        .padding(10)
        .background(choiceBackground(letter))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func choiceBackground(_ letter: String) -> Color {
        if letter == item.question.correctAnswer { return Color.green.opacity(0.18) }
        if letter == item.attempt.selectedAnswer && letter != item.question.correctAnswer { return Color.red.opacity(0.16) }
        return Color.gray.opacity(0.08)
    }
}
