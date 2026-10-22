import SwiftUI

/// Full-screen interactive investigator overlay for Victorian scene illustrations with 1.0x–5.0x pinch-to-zoom,
/// double-tap 2.5x toggle, drag-to-pan, and Liquid Glass HUD bars.
public struct ZoomableImageDialog: View {
    public let imageData: Data
    public let caption: String
    public let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    public init(
        imageData: Data,
        caption: String,
        onDismiss: @escaping () -> Void
    ) {
        self.imageData = imageData
        self.caption = caption
        self.onDismiss = onDismiss
    }

    private var truncatedCaption: String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "..."
        }
        return trimmed
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    if let swiftUIImage = SherlockPlatformImage.swiftUIImage(from: imageData) {
                        swiftUIImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        let nextScale = lastScale * value.magnification
                                        scale = min(max(nextScale, 1.0), 5.0)
                                        if scale <= 1.0 {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.0 {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        guard scale > 1.0 else { return }
                                        let maxX = (proxy.size.width * (scale - 1.0)) / 2.0
                                        let maxY = (proxy.size.height * (scale - 1.0)) / 2.0
                                        let proposedX = lastOffset.width + value.translation.width
                                        let proposedY = lastOffset.height + value.translation.height
                                        offset = CGSize(
                                            width: min(max(proposedX, -maxX), maxX),
                                            height: min(max(proposedY, -maxY), maxY)
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(duration: 0.25)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                            .accessibilityIdentifier("zoomableSceneImage")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                // Top Liquid Glass HUD Bar
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🔍 Scene Investigation")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("sceneInvestigationTitle")

                        Text("Pinch to zoom • Double-tap to toggle zoom • Drag to pan")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            if scale > 1.0 {
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.circle)
                                .accessibilityLabel("Reset Zoom")
                                .accessibilityIdentifier("resetZoomButton")
                            }

                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.accentColor)
                            .buttonBorderShape(.circle)
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier("closeZoomDialogButton")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Bottom Liquid Glass HUD Bar
                VStack(spacing: 4) {
                    Text(String(format: "Zoom: %.1fx", scale))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("zoomLevelLabel")

                    if !truncatedCaption.isEmpty {
                        Text(truncatedCaption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .accessibilityIdentifier("zoomableImageDialog")
    }
}
