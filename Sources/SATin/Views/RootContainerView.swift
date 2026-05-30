import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case practice = "Practice"
    case library = "Library"
    case aboutSAT = "About SAT"
    case satin = "SATin"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .practice: return "pencil.and.scribble"
        case .library: return "books.vertical"
        case .aboutSAT: return "graduationcap"
        case .satin: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

struct RootContainerView: View {
    @State private var selection: AppSection? = .home
    @AppStorage("hasShownDisclaimer") private var hasShownDisclaimer = false
    @State private var showDisclaimer = false

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("SATin")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            NavigationStack {
                detailView(for: selection ?? .home)
                    .navigationTitle((selection ?? .home).rawValue)
                    .toolbarTitleDisplayMode(.inline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SATinStyle.pageBackground)
            }
        }
        .onAppear { showDisclaimer = !hasShownDisclaimer }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerView(onContinue: {
                hasShownDisclaimer = true
                showDisclaimer = false
            })
        }
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .home:
            HomeHubView(selection: Binding(get: { selection ?? .home }, set: { selection = $0 }))
        case .practice:
            PracticeContainerView()
        case .library:
            LibraryView()
        case .aboutSAT:
            AboutSATView()
        case .satin:
            SATinAboutView()
        case .settings:
            SettingsView()
        }
    }
}

private struct HomeHubView: View {
    @Binding var selection: AppSection
    @Query private var settings: [UserSettings]
    @Query private var sessions: [PracticeSession]

    var body: some View {
        let userName = settings.first?.name ?? "Student"
        let totalQuestions = sessions.map(\.questionCount).reduce(0, +)
        let totalCorrect = sessions.map(\.correctCount).reduce(0, +)
        let accuracy = totalQuestions == 0 ? 0 : Int(Double(totalCorrect) / Double(totalQuestions) * 100)
        let testDate = settings.first?.testDate ?? .now.addingTimeInterval(21 * 86400)
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: .now, to: testDate).day ?? 0)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back, \(userName)")
                        .font(.largeTitle.weight(.semibold))
                    Text("Track practice, review mistakes, and manage your local SAT question bank.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    PlaceholderCard(title: "Days Left", value: "\(daysLeft)")
                    PlaceholderCard(title: "Questions Practiced", value: "\(totalQuestions)")
                    PlaceholderCard(title: "Accuracy", value: "\(accuracy)%")
                }

                HStack(alignment: .top, spacing: 12) {
                    launchCard(
                        title: "Practice",
                        subtitle: "Start a focused session",
                        icon: "play.circle.fill",
                        actionText: "Start Practice"
                    ) { selection = .practice }

                    launchCard(
                        title: "Library",
                        subtitle: "Import, filter, and export questions",
                        icon: "books.vertical.fill",
                        actionText: "Open Library"
                    ) { selection = .library }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("More")
                        .font(.headline)
                    quickNav("About SAT", icon: "graduationcap") { selection = .aboutSAT }
                    quickNav("About SATin", icon: "sparkles") { selection = .satin }
                    quickNav("Settings", icon: "gearshape") { selection = .settings }
                }
                .padding(14)
                .satinPanel()

                Text("SATin is an independent third-party application and is not affiliated with, endorsed by, or sponsored by the College Board.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private func launchCard(title: String, subtitle: String, icon: String, actionText: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SATinStyle.primary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: action) {
                Label(actionText, systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .satinCard()
    }

    private func quickNav(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
