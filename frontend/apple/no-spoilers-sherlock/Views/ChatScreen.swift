import SwiftUI
import AppCore

/// Primary chat screen for "No Spoilers, Sherlock" built with iOS 26+ Liquid Glass controls,
/// Apple HIG system semantic colors, and anchored bottom `.safeAreaBar(edge: .bottom)`.
public struct ChatScreen: View {
    @State private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var showBookBottomSheet: Bool = false
    @State private var selectedImageMessage: ChatMessage?

    @AppStorage("selectedBookId") private var persistedBookId: String = "study_in_scarlet"
    @AppStorage("selectedChapterOrder") private var persistedChapterOrder: Int = 3

    public init(viewModel: ChatViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    private var totalChaptersForSelectedBook: Int {
        max(1, viewModel.selectedBook?.totalChapters ?? 14)
    }

    private func chapterLabel(for chapterNum: Int) -> String {
        if let match = viewModel.chapters.first(where: { $0.chapterOrder == chapterNum }),
           !match.title.isEmpty {
            return "Ch. \(chapterNum) — \(match.title)"
        }
        return "Chapter \(chapterNum)"
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topHeaderBar

                Divider()

                messageContentArea
            }
            .background(
                SherlockTheme.background
                    .ignoresSafeArea()
            )
            .safeAreaBar(edge: .bottom) {
                VStack(spacing: 6) {
                    if viewModel.isLoading {
                        SherlockInvestigatingIndicator(statusText: viewModel.statusMessage)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    QuickPromptSuggestions(
                        selectedBookId: viewModel.selectedBook?.id,
                        onSuggestionClick: { suggestion in
                            inputText = suggestion
                        }
                    )

                    ChatInputBar(
                        inputText: $inputText,
                        onSendMessage: {
                            let textToSend = inputText
                            inputText = ""
                            Task {
                                await viewModel.sendMessage(textToSend)
                                persistedChapterOrder = viewModel.lastDetectedChapter
                            }
                        }
                    )
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(isPresented: $showBookBottomSheet) {
            BookSelectionSheet(
                books: viewModel.books,
                selectedBook: viewModel.selectedBook,
                chapters: viewModel.chapters,
                currentChapterOrder: viewModel.lastDetectedChapter,
                onSelectBook: { book in
                    persistedBookId = book.id
                    viewModel.selectBook(book)
                    persistedChapterOrder = viewModel.lastDetectedChapter
                },
                onSelectChapter: { chapterNum in
                    viewModel.setDefaultChapter(chapterNum)
                    persistedChapterOrder = viewModel.lastDetectedChapter
                }
            )
        }
        .overlay {
            if let imageMessage = selectedImageMessage,
               let imageData = imageMessage.imageData {
                ZoomableImageDialog(
                    imageData: imageData,
                    caption: imageMessage.text,
                    onDismiss: {
                        selectedImageMessage = nil
                    }
                )
                .transition(.opacity)
            }
        }
        .task {
            if viewModel.books.isEmpty && viewModel.messages.isEmpty {
                await viewModel.loadBooksAndInit()
                if let savedBook = viewModel.books.first(where: { $0.id == persistedBookId }),
                   savedBook.id != viewModel.selectedBook?.id {
                    viewModel.selectBook(savedBook)
                }
                if persistedChapterOrder > 0 {
                    viewModel.setDefaultChapter(persistedChapterOrder)
                }
            }
        }
    }

    // MARK: - Top Header Bar (Liquid Glass)

    private var topHeaderBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("No Spoilers, Sherlock")
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("appTitleLabel")

                    Text("Bounded to Chapter \(viewModel.lastDetectedChapter) • Zero Future Spoilers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("spoilerBoundarySubtitle")
                }

                Spacer()

                Button {
                    viewModel.clearConversation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Clear conversation")
                .accessibilityIdentifier("clearConversationButton")
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        showBookBottomSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)

                            Text(viewModel.selectedBook?.title ?? "Select Book")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Select Book: \(viewModel.selectedBook?.title ?? "Select Book")")
                    .accessibilityIdentifier("bookSelectorChip")

                    Menu {
                        ForEach(1...totalChaptersForSelectedBook, id: \.self) { chapterNum in
                            Button {
                                viewModel.setDefaultChapter(chapterNum)
                                persistedChapterOrder = viewModel.lastDetectedChapter
                            } label: {
                                if chapterNum == viewModel.lastDetectedChapter {
                                    Label(chapterLabel(for: chapterNum), systemImage: "checkmark")
                                } else {
                                    Text(chapterLabel(for: chapterNum))
                                }
                            }
                            .accessibilityIdentifier("chapterMenuOption_\(chapterNum)")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)

                            Text("Ch. \(viewModel.lastDetectedChapter)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Select Chapter Boundary: Chapter \(viewModel.lastDetectedChapter)")
                    .accessibilityIdentifier("chapterSelectorChip")

                    Spacer(minLength: 4)

                    AiStatusBadge(onDeviceStatus: viewModel.onDeviceStatus)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Main Message Area

    @ViewBuilder
    private var messageContentArea: some View {
        if viewModel.messages.isEmpty {
            EmptyChatHero(
                selectedBookTitle: viewModel.selectedBook?.title ?? "A Study in Scarlet",
                onSuggestionClick: { prompt in
                    inputText = prompt
                }
            )
        } else {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            ModernMessageBubble(
                                message: message,
                                onImageClick: { clickedMessage in
                                    selectedImageMessage = clickedMessage
                                },
                                onVisualizeClick: { chapter in
                                    Task {
                                        await viewModel.visualizeScene(
                                            "Visualize the scene from Chapter \(chapter)",
                                            targetChapter: chapter
                                        )
                                        persistedChapterOrder = viewModel.lastDetectedChapter
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .accessibilityIdentifier("chatMessageScrollView")
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollProxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

/// Custom non-button status badge rendered with `.glassEffect(.regular, in: .capsule)`.
public struct AiStatusBadge: View {
    public let onDeviceStatus: String?

    public init(onDeviceStatus: String?) {
        self.onDeviceStatus = onDeviceStatus
    }

    private var isReady: Bool {
        onDeviceStatus?.contains("Ready") == true
    }

    private var isDownloading: Bool {
        onDeviceStatus?.contains("Downloading") == true
    }

    private var labelText: String {
        if isReady {
            return "On-Device"
        } else if isDownloading {
            return "Downloading..."
        } else {
            return "Cloud AI"
        }
    }

    private var badgeColor: Color {
        if isReady {
            return .green
        } else {
            return .accentColor
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            if isDownloading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(badgeColor)
            } else {
                Image(systemName: isReady ? "bolt.fill" : "cloud.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(badgeColor)
            }

            Text(labelText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(badgeColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI Status: \(labelText)")
        .accessibilityIdentifier("aiStatusBadge")
    }
}
