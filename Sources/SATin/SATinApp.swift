import SwiftUI
import SwiftData

@main
struct SATinApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Question.self,
            PracticeSession.self,
            PracticeAttempt.self,
            MistakeEntry.self,
            MarkedEntry.self,
            SavedWord.self,
            UserSettings.self,
            ImportBatch.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Start Practice") {
                    NotificationCenter.default.post(name: .satinStartPracticeShortcut, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let satinStartPracticeShortcut = Notification.Name("satinStartPracticeShortcut")
}
