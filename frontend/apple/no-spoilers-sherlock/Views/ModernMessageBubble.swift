import SwiftUI
import AppCore

/// Renders a single chat message inside the scrollable message list.
/// Note: Per `apple-flo-liquid-glass` Rule #7, this view strictly uses solid Apple HIG system
/// surfaces inside `ScrollView` and avoids `.glassEffect` or `.buttonStyle(.glass)`.
public struct ModernMessageBubble: View {
    public let message: ChatMessage
    public let onImageClick: (ChatMessage) -> Void
    public let onVisualizeClick: (Int) -> Void

    public init(
        message: ChatMessage,
        onImageClick: @escaping (ChatMessage) -> Void,
        onVisualizeClick: @escaping (Int) -> Void
    ) {
        self.message = message
        self.onImageClick = onImageClick
        self.onVisualizeClick = onVisualizeClick
    }

    private var isUser: Bool {
        message.sender == .user
    }

    private var bubbleBackgroundColor: Color {
        if isUser {
            return SherlockTheme.userBubbleBackground
        } else {
            return SherlockTheme.secondaryBackground
        }
    }

    private var bubbleBorderColor: Color {
        if isUser {
            return Color.clear
        } else {
            return SherlockTheme.separator
        }
    }

    private var markdownAttributedText: AttributedString {
        if let parsed = try? AttributedString(
            markdown: message.text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(message.text)
    }

    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if isUser {
                    Spacer(minLength: 40)
                } else {
                    avatarView
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let chapter = message.extractedChapter, !isUser {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.caption2.weight(.bold))
                            Text("Bounded to Chapter \(chapter)")
                                .font(.caption2.weight(.semibold))
                            if !message.citedChapters.isEmpty {
                                Text("• Cited Ch. \(message.citedChapters.map(String.init).joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .foregroundStyle(.secondary)
                    } else if let chapter = message.extractedChapter, isUser {
                        HStack(spacing: 4) {
                            Image(systemName: "book.closed.fill")
                                .font(.caption2)
                            Text("Ch. \(chapter)")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                    }

                    if let imageData = message.imageData,
                       let swiftUIImage = SherlockPlatformImage.swiftUIImage(from: imageData) {
                        Button {
                            onImageClick(message)
                        } label: {
                            VStack(spacing: 0) {
                                ZStack(alignment: .topTrailing) {
                                    swiftUIImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                        .clipped()

                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass.circle.fill")
                                            .font(.caption)
                                        Text("Examine")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(SherlockTheme.tertiaryBackground.opacity(0.92))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(SherlockTheme.separator, lineWidth: 0.5)
                                    )
                                    .padding(10)
                                }

                                HStack(spacing: 6) {
                                    Image(systemName: "paintbrush.pointed.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                    Text("Sidney Paget Victorian Style • Nano Banana AI")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(SherlockTheme.tertiaryBackground)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(SherlockTheme.separator, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Examine Victorian scene illustration")
                        .accessibilityIdentifier("examineImageCard")
                    }

                    Text(markdownAttributedText)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(isUser ? Color.white : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: isUser ? 18 : 4,
                        bottomTrailingRadius: isUser ? 4 : 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                    .fill(bubbleBackgroundColor)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: isUser ? 18 : 4,
                        bottomTrailingRadius: isUser ? 4 : 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(bubbleBorderColor, lineWidth: 0.5)
                )

                if !isUser {
                    Spacer(minLength: 32)
                }
            }

            if !isUser &&
                message.sender == .ai &&
                !message.isSceneVisualization &&
                message.text != "..." {
                let targetChapter = message.extractedChapter ?? 3
                Button {
                    onVisualizeClick(targetChapter)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.caption.weight(.semibold))
                        Text("Visualize Scene (Ch. \(targetChapter))")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(SherlockTheme.secondaryBackground)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(SherlockTheme.separator, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.leading, 40)
                .accessibilityLabel("Visualize Scene for Chapter \(targetChapter)")
                .accessibilityIdentifier("visualizeSceneButton_\(targetChapter)")
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("messageBubble_\(message.id)")
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: message.isSceneVisualization ? "paintpalette.fill" : "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
    }
}
