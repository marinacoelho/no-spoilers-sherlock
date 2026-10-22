import SwiftUI
import AppCore

/// Empty state hero shown inside the main scrollable area when `messages.isEmpty`.
/// Note: Per `apple-flo-liquid-glass` Rule #7, this view uses solid Apple HIG system surfaces
/// and avoids `.glassEffect` or `.buttonStyle(.glass)` inside `ScrollView`.
public struct EmptyChatHero: View {
    public let selectedBookTitle: String
    public let onSuggestionClick: (String) -> Void

    public static let starterPrompts: [String] = [
        "🎨 Visualize the crime scene at Lauriston Gardens in Chapter 3",
        "In Chapter 3, who was found dead at Lauriston Gardens?",
        "In Chapter 5, what clue did the wedding ring provide?",
        "Who is Inspector Lestrade, and what is his theory?"
    ]

    public init(
        selectedBookTitle: String,
        onSuggestionClick: @escaping (String) -> Void
    ) {
        self.selectedBookTitle = selectedBookTitle
        self.onSuggestionClick = onSuggestionClick
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 68, height: 68)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text("The Game is Afoot")
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("emptyHeroTitle")

                Text("Ask questions as you read through \(selectedBookTitle). Sherlock guarantees zero spoilers for upcoming chapters!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    ForEach(Array(Self.starterPrompts.enumerated()), id: \.offset) { index, prompt in
                        Button {
                            onSuggestionClick(prompt)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: prompt.contains("🎨") ? "paintpalette.fill" : "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)

                                Text(prompt)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 4)

                                Image(systemName: "arrow.up.left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(SherlockTheme.secondaryBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(SherlockTheme.separator, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("starterPromptCard_\(index)")
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("emptyChatHero")
    }
}
