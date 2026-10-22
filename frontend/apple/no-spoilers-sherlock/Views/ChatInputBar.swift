import SwiftUI

/// Bottom chat input bar wrapped in `GlassEffectContainer` using `.glassEffect` for the text field
/// and `.buttonStyle(.glassProminent)` with Apple system accent tint for the circular Send button.
public struct ChatInputBar: View {
    @Binding public var inputText: String
    public let onSendMessage: () -> Void

    public init(
        inputText: Binding<String>,
        onSendMessage: @escaping () -> Void
    ) {
        self._inputText = inputText
        self.onSendMessage = onSendMessage
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Ask about your chapter (e.g. 'In chapter 3, who...')",
                        text: $inputText,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend {
                            onSendMessage()
                        }
                    }
                    .accessibilityIdentifier("chatInputTextField")

                    if !inputText.isEmpty {
                        Button {
                            inputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear input text")
                        .accessibilityIdentifier("clearInputTextButton")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                Button {
                    onSendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Color.accentColor)
                .buttonBorderShape(.circle)
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("sendMessageButton")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("chatInputBar")
    }
}
