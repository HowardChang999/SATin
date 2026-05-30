import SwiftUI
import SwiftData

struct MistakesView: View {
    @Query private var mistakes: [MistakeEntry]
    var body: some View {
        List(mistakes) { m in
            Text("Question \(m.questionId)")
        }
        .navigationTitle("Mistakes")
    }
}

struct HistoryView: View {
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    var body: some View {
        List(sessions) { s in
            VStack(alignment: .leading) {
                Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                Text("Questions: \(s.questionCount), Accuracy: \(s.questionCount == 0 ? 0 : Int(Double(s.correctCount) / Double(s.questionCount) * 100))%")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AboutSATView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InfoSection(title: "What is the SAT?", icon: "graduationcap") {
                    Text("The SAT is a standardized college admissions test. This app covers only Reading and Writing.")
                }
                InfoSection(title: "Reading and Writing", icon: "text.book.closed") {
                    Text("Questions assess comprehension, analysis, grammar, and revision skills.")
                }
                InfoSection(title: "Scoring", icon: "chart.bar") {
                    Text("SATin provides internal practice scoring for study feedback and is not an official SAT score.")
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

struct SATinAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InfoSection(title: "SATin", icon: "sparkles") {
                    Text("SATin is a local-first SAT Reading and Writing practice app with your own imported question sets.")
                }
                InfoSection(title: "Privacy", icon: "lock") {
                    Text("All data is stored locally on your Mac.")
                }
                InfoSection(title: "Disclaimer", icon: "info.circle") {
                    Text("SATin is an independent third-party application and is not affiliated with, endorsed by, or sponsored by the College Board.")
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var words: [SavedWord]
    @State private var exportVocabulary = ""

    var body: some View {
        let userSettings = ensureSettings()

        Form {
            Section("Profile") {
                TextField("Name", text: Binding(get: { userSettings.name }, set: { userSettings.name = $0 }))
                DatePicker("Test Date", selection: Binding(get: { userSettings.testDate }, set: { userSettings.testDate = $0 }), displayedComponents: .date)
            }

            Section("Translation") {
                Picker("Language", selection: Binding(get: { userSettings.translationLanguageRaw }, set: { userSettings.translationLanguageRaw = $0 })) {
                    ForEach(TranslationLanguage.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }

                Picker("Model", selection: Binding(get: { userSettings.translationQualityRaw }, set: { userSettings.translationQualityRaw = $0 })) {
                    ForEach(TranslationQuality.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }

            Section("Data Management") {
                Button("Export Vocabulary Backup (JSON)") {
                    exportVocabulary = (try? VocabularyExporter().export(words: words, format: .json)) ?? "[]"
                }
                TextEditor(text: $exportVocabulary).frame(minHeight: 120)
            }

            Text("Users are responsible for the copyright compliance of imported questions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(24)
    }

    private func ensureSettings() -> UserSettings {
        if let existing = settings.first { return existing }
        let fresh = UserSettings()
        modelContext.insert(fresh)
        try? modelContext.save()
        return fresh
    }
}

private struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .satinCard()
    }
}
