import SwiftUI
import AppCore

/// Modal bottom sheet presenting the available Sherlock Holmes novels (*A Study in Scarlet* and *The Sign of the Four*)
/// along with a chapter boundary picker using Apple HIG system grouped backgrounds and semantic styles.
public struct BookSelectionSheet: View {
    public let books: [Book]
    public let selectedBook: Book?
    public let chapters: [Chapter]
    public let currentChapterOrder: Int
    public let onSelectBook: (Book) -> Void
    public let onSelectChapter: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        books: [Book],
        selectedBook: Book?,
        chapters: [Chapter] = [],
        currentChapterOrder: Int = 3,
        onSelectBook: @escaping (Book) -> Void,
        onSelectChapter: @escaping (Int) -> Void = { _ in }
    ) {
        self.books = books
        self.selectedBook = selectedBook
        self.chapters = chapters
        self.currentChapterOrder = currentChapterOrder
        self.onSelectBook = onSelectBook
        self.onSelectChapter = onSelectChapter
    }

    private var totalChapters: Int {
        max(1, selectedBook?.totalChapters ?? 14)
    }

    private func chapterTitle(for number: Int) -> String? {
        chapters.first(where: { $0.chapterOrder == number })?.title
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Novel")
                            .font(.system(.title3, design: .serif).weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("selectNovelHeader")

                        Text("Choose the Sherlock Holmes mystery you are currently reading")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(books) { book in
                            let isSelected = book.id == selectedBook?.id
                            Button {
                                onSelectBook(book)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.title3)
                                        .foregroundStyle(
                                            isSelected
                                                ? Color.accentColor
                                                : Color.secondary
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(book.title)
                                            .font(.headline.weight(isSelected ? .bold : .medium))
                                            .foregroundStyle(.primary)

                                        Text("\(book.author) • \(book.totalChapters) Chapters")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            isSelected
                                                ? Color.accentColor.opacity(0.12)
                                                : SherlockTheme.secondaryGroupedBackground
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isSelected
                                                ? Color.accentColor
                                                : SherlockTheme.separator,
                                            lineWidth: isSelected ? 1.5 : 0.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bookOption_\(book.id)")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.accentColor)

                            Text("Spoiler Guardrail Boundary")
                                .font(.system(.headline, design: .serif).weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Text("Select the highest chapter you have read so far. Sherlock will strictly block any plot twists beyond this chapter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 74), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(1...totalChapters, id: \.self) { chNum in
                                let isCurrent = chNum == currentChapterOrder
                                Button {
                                    onSelectChapter(chNum)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("Ch. \(chNum)")
                                            .font(.caption.weight(isCurrent ? .bold : .semibold))
                                            .foregroundStyle(
                                                isCurrent
                                                    ? Color.white
                                                    : Color.primary
                                            )

                                        if let title = chapterTitle(for: chNum) {
                                            Text(title)
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                                .foregroundStyle(
                                                    isCurrent
                                                        ? Color.white.opacity(0.85)
                                                        : Color.secondary
                                                )
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                isCurrent
                                                    ? Color.accentColor
                                                    : SherlockTheme.secondaryGroupedBackground
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                isCurrent ? Color.accentColor : SherlockTheme.separator,
                                                lineWidth: isCurrent ? 1.0 : 0.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("sheetChapterOption_\(chNum)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SherlockTheme.groupedBackground.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("bookSelectionSheet")
    }
}
