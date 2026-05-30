import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case questions = "Questions"
        case vocabulary = "Vocabulary"
        case activity = "Activity"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .questions
    @State private var showImporter = false
    @State private var showImportReview = false
    @State private var importDrafts: [ParsedQuestionDraft] = []
    @State private var importFileName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Spacer()

                Button {
                    showImporter = true
                } label: {
                    Label("Import PDF", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.12, green: 0.38, blue: 0.86))
            }

            switch selectedTab {
            case .questions:
                QuestionsLibraryPane()
            case .vocabulary:
                VocabularyLibraryPane()
            case .activity:
                ActivityLibraryPane()
            }
        }
        .padding(24)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importDrafts = PDFImportService().parse(pdfURL: url)
                importFileName = url.lastPathComponent
                showImportReview = true
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showImportReview) {
            ImportReviewView(drafts: $importDrafts, sourcePdfName: importFileName) {
                showImportReview = false
            }
        }
    }
}


struct QuestionsLibraryPane: View {
    @Query(sort: \Question.createdAt, order: .reverse) private var questions: [Question]
    @Query private var attempts: [PracticeAttempt]

    enum AttemptFilter: String, CaseIterable, Identifiable { case all = "All", attempted = "Attempted", unattempted = "Unattempted"; var id: String { rawValue } }
    enum ResultFilter: String, CaseIterable, Identifiable { case all = "All", correct = "Correct", incorrect = "Incorrect"; var id: String { rawValue } }

    @State private var attemptFilter: AttemptFilter = .all
    @State private var resultFilter: ResultFilter = .all
    @State private var exportFormat: QuestionExportFormat = .json
    @State private var pdfMode: QuestionPDFExportMode = .questionsOnly
    @State private var exportMessage: String = ""

    private var latestByQuestion: [String: PracticeAttempt] {
        Dictionary(grouping: attempts, by: { $0.questionId }).compactMapValues { $0.sorted(by: { $0.submittedAt > $1.submittedAt }).first }
    }

    private var filteredQuestions: [Question] {
        questions.filter { q in
            let latest = latestByQuestion[q.questionId]
            let attemptedPass = attemptFilter == .all || (attemptFilter == .attempted ? latest != nil : latest == nil)
            let resultPass: Bool
            switch resultFilter {
            case .all: resultPass = true
            case .correct: resultPass = latest?.wasCorrect == true
            case .incorrect: resultPass = latest?.wasCorrect == false
            }
            return attemptedPass && resultPass
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Question Bank", systemImage: "tray.full")
                    .font(.headline)
                Spacer()
                CountBadge(text: "\(filteredQuestions.count) questions")
            }

            HStack(spacing: 12) {
                Picker("Attempt", selection: $attemptFilter) { ForEach(AttemptFilter.allCases) { Text($0.rawValue).tag($0) } }
                    .frame(width: 180)
                Picker("Result", selection: $resultFilter) { ForEach(ResultFilter.allCases) { Text($0.rawValue).tag($0) } }
                    .frame(width: 180)
            }
            .padding(12)
            .satinPanel()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                    ForEach(filteredQuestions) { q in
                        let latest = latestByQuestion[q.questionId]
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(q.questionId)
                                    .font(.headline)
                                    .foregroundStyle(SATinStyle.text)
                                Spacer()
                                statusBadge(latest)
                            }
                            HStack(spacing: 8) {
                                MetadataChip(text: q.domain.rawValue, systemImage: "square.grid.2x2")
                                MetadataChip(text: q.difficulty.rawValue, systemImage: "dial.medium")
                            }
                            Label(q.skill.rawValue, systemImage: "target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(q.prompt)
                                .font(.callout)
                                .foregroundStyle(SATinStyle.text)
                                .lineLimit(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .satinCard()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.headline)
                    Picker("Export", selection: $exportFormat) {
                        ForEach(QuestionExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 220)

                    if exportFormat == .pdf {
                        Picker("PDF Mode", selection: $pdfMode) {
                            ForEach(QuestionPDFExportMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .frame(width: 320)
                    }

                    Button { exportQuestions() } label: {
                        Label("Export File", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SATinStyle.primary)
                        .disabled(filteredQuestions.isEmpty)

                    Spacer()
                    Text(figureExportNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !exportMessage.isEmpty {
                    Label(exportMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .satinPanel()
        }
    }

    private var figureExportNote: String {
        exportFormat == .pdf ? "PDF embeds available figures" : "Figures are exported as asset references"
    }

    @ViewBuilder
    private func statusBadge(_ attempt: PracticeAttempt?) -> some View {
        if let attempt {
            Text(attempt.wasCorrect ? "Correct" : "Incorrect")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(attempt.wasCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .clipShape(Capsule())
        } else {
            Text("Unattempted")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    private func exportQuestions() {
        do {
            guard let destination = ExportSavePanel.destinationURL(
                defaultBaseName: "SATin-Questions",
                fileExtension: exportFormat.fileExtension,
                contentType: exportFormat.contentType
            ) else {
                return
            }

            let result = try QuestionExporter().export(
                questions: filteredQuestions,
                format: exportFormat,
                pdfMode: pdfMode
            )
            if let fileURL = result.fileURL {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: fileURL, to: destination)
            } else {
                try result.preview.write(to: destination, atomically: true, encoding: String.Encoding.utf8)
            }
            exportMessage = "Exported \(filteredQuestions.count) questions to \(destination.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

struct VocabularyLibraryPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var words: [SavedWord]
    @State private var query = ""
    @State private var exportMessage: String = ""
    @State private var format: VocabularyExportFormat = .csv
    @State private var masteredOnly = false

    private var filtered: [SavedWord] {
        words.filter { (!masteredOnly || $0.isMastered) && (query.isEmpty || $0.word.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Vocabulary", systemImage: "text.book.closed")
                    .font(.headline)
                Spacer()
                CountBadge(text: "\(filtered.count) words")
            }

            HStack(spacing: 12) {
                TextField("Search word", text: $query)
                    .textFieldStyle(.roundedBorder)
                Toggle("Mastered only", isOn: $masteredOnly)
            }
            .padding(12)
            .satinPanel()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                    ForEach(filtered) { word in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(word.word)
                                    .font(.headline)
                                    .foregroundStyle(SATinStyle.text)
                                Spacer()
                                Toggle("Mastered", isOn: Binding(get: { word.isMastered }, set: { word.isMastered = $0 })).labelsHidden()
                            }
                            Text(word.definition)
                                .font(.callout)
                                .foregroundStyle(SATinStyle.text)
                            Label("Source: \(word.sourceQuestionId)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Note", text: Binding(get: { word.notes }, set: { word.notes = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .satinCard()
                    }
                }
            }

            HStack(spacing: 10) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.headline)
                Picker("Export", selection: $format) { ForEach(VocabularyExportFormat.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 220)
                Button { exportWords() } label: {
                    Label("Export File", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(SATinStyle.primary)
                .disabled(filtered.isEmpty)
                Button(role: .destructive) { deleteAll() } label: {
                    Label("Delete All", systemImage: "trash")
                }
                Spacer()
            }
            .padding(12)
            .satinPanel()

            if !exportMessage.isEmpty {
                Label(exportMessage, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportWords() {
        do {
            guard let destination = ExportSavePanel.destinationURL(
                defaultBaseName: "SATin-Vocabulary",
                fileExtension: format.fileExtension,
                contentType: format.contentType
            ) else {
                return
            }
            let output = try VocabularyExporter().export(words: filtered, format: format)
            try output.write(to: destination, atomically: true, encoding: String.Encoding.utf8)
            exportMessage = "Exported \(filtered.count) words to \(destination.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func deleteAll() {
        for word in words { modelContext.delete(word) }
        try? modelContext.save()
    }
}

private struct CountBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SATinStyle.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SATinStyle.primary.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct MetadataChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.08))
            .clipShape(Capsule())
    }
}

private enum ExportSavePanel {
    @MainActor
    static func destinationURL(defaultBaseName: String, fileExtension: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "\(defaultBaseName).\(fileExtension)"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private extension QuestionExportFormat {
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .pdf: return "pdf"
        }
    }

    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .pdf: return .pdf
        }
    }
}

private extension VocabularyExportFormat {
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .markdown: return "md"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        }
    }
}

struct ActivityLibraryPane: View {
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    @Query(sort: \MistakeEntry.lastSeenAt, order: .reverse) private var mistakes: [MistakeEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("History").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(sessions.prefix(20)) { item in
                        let acc = item.questionCount == 0 ? 0 : Int((Double(item.correctCount) / Double(item.questionCount)) * 100)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text("Questions: \(item.questionCount)")
                            Text("Accuracy: \(acc)%")
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.85, green: 0.88, blue: 0.96), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Text("Mistakes").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(mistakes.prefix(20)) { m in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            VStack(alignment: .leading) {
                                Text("Question \(m.questionId)").font(.headline)
                                Text(m.lastSeenAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.85, green: 0.88, blue: 0.96), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}
