import SwiftUI

/// Horizontal scrolling row of book-aware Liquid Glass quick prompt suggestion buttons anchored in the bottom `.safeAreaBar`.
public struct QuickPromptSuggestions: View {
    public let selectedBookId: String?
    public let onSuggestionClick: (String) -> Void

    public init(
        selectedBookId: String?,
        onSuggestionClick: @escaping (String) -> Void
    ) {
        self.selectedBookId = selectedBookId
        self.onSuggestionClick = onSuggestionClick
    }

    public var suggestions: [String] {
        switch selectedBookId {
        case "sign_of_the_four":
            return [
                "🎨 Visualize Chapter 4 crime scene",
                "In Chapter 2, who is Miss Morstan?",
                "In Chapter 4, who was found dead?",
                "What clue was left behind?"
            ]
        default:
            return [
                "🎨 Visualize Lauriston Gardens in Chapter 3",
                "In Chapter 3, who died?",
                "In Chapter 5, what clue was found?",
                "Who is Inspector Lestrade?"
            ]
        }
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, prompt in
                        Button {
                            onSuggestionClick(prompt)
                        } label: {
                            Text(prompt)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel(prompt)
                        .accessibilityIdentifier("quickPromptChip_\(index)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .accessibilityIdentifier("quickPromptSuggestions")
    }
}
