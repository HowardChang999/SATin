import AppKit
import SwiftUI

// MARK: - Apple-style subtle animations

private struct SATinAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .blur(radius: appeared ? 0 : 1)
            .scaleEffect(appeared ? 1 : 0.98, anchor: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

private struct SATinPressModifier: ViewModifier {
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: pressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    pressed = hovering
                }
            }
    }
}

extension View {
    /// Subtle fade-in + slide-up on appear. Higher index = later appearance.
    func satinAppear(_ index: Double = 0) -> some View {
        modifier(SATinAppearModifier(delay: index * 0.06))
    }

    /// Subtle scale-down on hover, Apple-style press feedback.
    func satinPress() -> some View {
        modifier(SATinPressModifier())
    }
}

enum SATinStyle {
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let panel = Color(nsColor: .underPageBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.55)
    static let primary = Color.accentColor
    static let text = Color.primary
}

extension View {
    func satinCard(radius: CGFloat = 8) -> some View {
        self
            .background(SATinStyle.surface)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(SATinStyle.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    func satinPanel(radius: CGFloat = 8) -> some View {
        self
            .background(.thinMaterial)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(SATinStyle.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct DisclaimerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Disclaimer")
                .font(.largeTitle.bold())
            Text("SATin is an independent third-party application and is not affiliated with, endorsed by, or sponsored by the College Board.")
                .font(.title3)
            Button("I Understand") {
                onContinue()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 260)
    }
}

struct PlaceholderCard: View {
    let title: String
    let value: String
    var index: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(SATinStyle.text)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .satinCard()
        .satinAppear(index)
    }
}
