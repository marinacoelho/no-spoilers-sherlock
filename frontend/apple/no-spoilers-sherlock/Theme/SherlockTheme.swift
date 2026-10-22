import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Apple Human Interface Guidelines (HIG) semantic color palette & cross-platform image helper for "No Spoilers, Sherlock".
public enum SherlockTheme {
    // MARK: - Apple HIG Semantic Colors

    public static var background: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.primary
        #endif
    }

    public static var secondaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.secondary
        #endif
    }

    public static var tertiaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .tertiarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .underPageBackgroundColor)
        #else
        return Color.secondary
        #endif
    }

    public static var groupedBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.primary
        #endif
    }

    public static var secondaryGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.secondary
        #endif
    }

    public static var separator: Color {
        #if canImport(UIKit)
        return Color(uiColor: .separator)
        #elseif canImport(AppKit)
        return Color(nsColor: .separatorColor)
        #else
        return Color.secondary.opacity(0.3)
        #endif
    }

    public static let primaryText: Color = .primary
    public static let secondaryText: Color = .secondary
    public static let accent: Color = .accentColor
    public static let userBubbleBackground: Color = .accentColor
    public static var aiBubbleBackground: Color { secondaryBackground }

    // MARK: - Legacy Aliases Mapped to Apple System Semantic Colors

    public static var detectiveNavyDark: Color { background }
    public static var detectiveNavyMedium: Color { secondaryBackground }
    public static var detectiveNavyLight: Color { tertiaryBackground }
    public static var detectiveNavySurface: Color { secondaryBackground }
    public static var detectiveNavyElevated: Color { tertiaryBackground }

    public static let victorianGold: Color = .accentColor
    public static let victorianGoldLight: Color = .accentColor
    public static let gaslampAmber: Color = .accentColor
    public static var victorianGoldContainer: Color { Color.accentColor.opacity(0.15) }

    public static let parchmentCream: Color = .primary
    public static let fogGrey: Color = .secondary

    public static let spoilerRedAccent: Color = .red
    public static let crimsonAccent: Color = .red

    public static let citationGreen: Color = .green
    public static let emeraldReady: Color = .green
}

/// Cross-platform helper to convert raw binary image `Data` into a SwiftUI `Image`.
public enum SherlockPlatformImage {
    public static func swiftUIImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
