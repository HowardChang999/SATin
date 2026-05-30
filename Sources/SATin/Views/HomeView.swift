import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var sessions: [PracticeSession]
    @Query private var settings: [UserSettings]

    var body: some View {
        let user = settings.first
        let totalQuestions = sessions.map(\.questionCount).reduce(0, +)
        let correct = sessions.map(\.correctCount).reduce(0, +)
        let accuracy = totalQuestions == 0 ? 0 : Double(correct) / Double(totalQuestions) * 100

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome back, \(user?.name ?? "Student")")
                    .font(.largeTitle.bold())

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    PlaceholderCard(title: "Days until SAT", value: daysUntil(date: user?.testDate ?? .now))
                    PlaceholderCard(title: "Total Questions Practiced", value: "\(totalQuestions)")
                    PlaceholderCard(title: "Overall Accuracy", value: String(format: "%.1f%%", accuracy))
                    PlaceholderCard(title: "Average Time per Question", value: "--")
                }

                HStack {
                    Button("Continue Practice") {}
                    Button("Review Mistakes") {}
                }
            }
            .padding(24)
        }
    }

    private func daysUntil(date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        return "\(max(0, days))"
    }
}
