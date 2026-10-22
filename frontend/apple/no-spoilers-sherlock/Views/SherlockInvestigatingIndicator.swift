import SwiftUI

/// Animated Liquid Glass capsule indicator shown inside the bottom `.safeAreaBar` while Sherlock is deducing clues or illustrating a scene.
public struct SherlockInvestigatingIndicator: View {
    public let statusText: String?

    @State private var isPulsing = false

    public init(statusText: String?) {
        self.statusText = statusText
    }

    public var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.accentColor)

            Text(statusText ?? "Sherlock is deducing clues...")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(isPulsing ? 1.0 : 0.4)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText ?? "Sherlock is deducing clues...")
        .accessibilityIdentifier("sherlockInvestigatingIndicator")
    }
}
