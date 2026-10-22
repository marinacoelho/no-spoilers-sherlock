import Foundation
import Observation

/// Main-actor observable state coordinator for the "No Spoilers, Sherlock" reading assistant.
///
/// Orchestrates book selection, chapter boundary extraction/clamping, spoiler-bounded chunk retrieval,
/// interim placeholder message replacement, and Victorian scene illustration requests.
@Observable
@MainActor
public final class ChatViewModel {
    /// Available novels loaded from the repository.
    public private(set) var books: [Book] = []

    /// The currently active novel for spoiler-bounded queries.
    public private(set) var selectedBook: Book?

    /// Chapters loaded for the currently active novel, sorted by `chapterOrder` ascending.
    public private(set) var chapters: [Chapter] = []

    /// Ordered conversation transcript displayed in the chat UI.
    public private(set) var messages: [ChatMessage] = []

    /// Indicates whether an asynchronous deduction or scene visualization is currently in progress.
    public private(set) var isLoading: Bool = false

    /// Human-readable status text describing the active investigation step.
    public private(set) var statusMessage: String?

    /// Status indicator for on-device AI availability (`"On-Device AI Ready"`, `"Downloading On-Device AI..."`, or `nil` for Cloud AI).
    public private(set) var onDeviceStatus: String?

    /// Fallback chapter boundary used when a user prompt does not explicitly mention a chapter number.
    public private(set) var defaultChapter: Int = 3

    /// Most recently resolved chapter boundary from user interaction.
    public private(set) var lastDetectedChapter: Int = 3

    private let repository: any BookRepositoryProtocol
    private let aiService: any AiServiceProtocol
    private var sessionGeneration: UInt64 = 0

    /// Creates a new `ChatViewModel` with injectable repository and AI service implementations.
    ///
    /// - Parameters:
    ///   - repository: Persistence service providing books, chapters, and spoiler-bounded chunks.
    ///   - aiService: Inference service generating spoiler-safe answers and Victorian illustrations.
    public init(
        repository: any BookRepositoryProtocol = InMemorySeededBookRepository(),
        aiService: any AiServiceProtocol = DeterministicSherlockAiService()
    ) {
        self.repository = repository
        self.aiService = aiService
    }

    /// Initializes sample data, loads available novels, sets the initial active book (*A Study in Scarlet*),
    /// posts the welcome message, and checks on-device AI model readiness.
    public func loadBooksAndInit() async {
        sessionGeneration &+= 1
        let generation = sessionGeneration

        isLoading = true
        statusMessage = "Loading Sherlock Holmes library..."

        let fallbackBook = Book(
            id: "study_in_scarlet",
            universeId: "sherlock_holmes",
            bookOrder: 1,
            title: "A Study in Scarlet",
            author: "Sir Arthur Conan Doyle",
            totalChapters: 14
        )

        do {
            try await repository.ensureSampleDataPopulated()
            let fetchedBooks = try await repository.getBooks()
            guard generation == self.sessionGeneration else { return }
            if fetchedBooks.isEmpty {
                books = [fallbackBook]
            } else {
                books = fetchedBooks
            }
        } catch {
            guard generation == self.sessionGeneration else { return }
            books = [fallbackBook]
        }

        let initialBook = books.first ?? fallbackBook
        selectedBook = initialBook
        chapters = (try? await repository.getChapters(bookId: initialBook.id)) ?? []
        guard generation == self.sessionGeneration else { return }
        defaultChapter = 3
        lastDetectedChapter = defaultChapter
        messages = [makeWelcomeMessage(for: initialBook)]
        isLoading = false
        statusMessage = nil

        let status = await aiService.checkAndDownloadOnDeviceModel()
        guard generation == self.sessionGeneration else { return }
        onDeviceStatus = status
    }

    /// Switches the active novel context, resets the detected chapter to `defaultChapter`,
    /// and resets the conversation transcript to the welcome message for the newly selected book.
    ///
    /// - Parameter book: The `Book` selected by the reader.
    public func selectBook(_ book: Book) {
        sessionGeneration &+= 1
        let generation = sessionGeneration
        selectedBook = book
        chapters = []
        defaultChapter = SpoilerGuardManager.clampChapter(defaultChapter, totalChapters: book.totalChapters)
        lastDetectedChapter = defaultChapter
        isLoading = false
        statusMessage = nil
        messages = [makeWelcomeMessage(for: book)]

        Task { @MainActor [weak self] in
            guard let self else { return }
            let fetchedChapters = (try? await self.repository.getChapters(bookId: book.id)) ?? []
            guard generation == self.sessionGeneration else { return }
            self.chapters = fetchedChapters
        }
    }

    /// Updates the fallback chapter boundary used when prompts omit an explicit chapter number,
    /// and immediately synchronizes `lastDetectedChapter` to the newly selected boundary.
    ///
    /// - Parameter chapterNum: Desired fallback chapter number (clamped to `1...totalChapters`).
    public func setDefaultChapter(_ chapterNum: Int) {
        let total = selectedBook?.totalChapters ?? 14
        let clamped = SpoilerGuardManager.clampChapter(chapterNum, totalChapters: total)
        defaultChapter = clamped
        lastDetectedChapter = clamped
    }

    /// Clears all messages in the current conversation so the reader can return to the empty state hero view.
    public func clearConversation() {
        sessionGeneration &+= 1
        isLoading = false
        statusMessage = nil
        messages = []
    }

    /// Processes a user prompt, enforces two-layer spoiler guardrails up to the extracted/clamped chapter,
    /// and appends (or replaces) the AI response in `messages`.
    ///
    /// If the prompt matches a visualization keyword via ``SpoilerGuardManager/isVisualizationRequest(_:)``,
    /// this method automatically delegates to ``visualizeScene(_:targetChapter:)``.
    ///
    /// - Parameter userText: Raw text entered by the user.
    public func sendMessage(_ userText: String) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let activeBook = resolveActiveBook()
        let rawChapter = SpoilerGuardManager.extractChapterFromPrompt(trimmed) ?? defaultChapter
        let clampedChapter = SpoilerGuardManager.clampChapter(rawChapter, totalChapters: activeBook.totalChapters)

        if SpoilerGuardManager.isVisualizationRequest(trimmed) {
            await visualizeScene(trimmed, targetChapter: clampedChapter)
            return
        }

        let generation = sessionGeneration

        let userMessage = ChatMessage(
            sender: .user,
            text: trimmed,
            extractedChapter: clampedChapter
        )
        messages.append(userMessage)

        isLoading = true
        lastDetectedChapter = clampedChapter
        statusMessage = "Restricting spoiler boundary to Chapter \(clampedChapter) of \(activeBook.title)..."

        let placeholderId = UUID().uuidString

        do {
            let allowedChunks = try await repository.getSpoilerBoundedChunks(
                bookId: activeBook.id,
                targetChapterOrder: clampedChapter
            )
            guard generation == self.sessionGeneration else { return }

            let citedChapters = Array(Set(allowedChunks.map(\.chapterOrder))).sorted()

            let placeholderMessage = ChatMessage(
                id: placeholderId,
                sender: .ai,
                text: "...",
                extractedChapter: clampedChapter,
                citedChapters: citedChapters,
                isOfflineMode: onDeviceStatus == "On-Device AI Ready"
            )
            messages.append(placeholderMessage)

            let fullPrompt = SpoilerGuardManager.buildSpoilerGuardrailPrompt(
                bookTitle: activeBook.title,
                targetChapter: clampedChapter,
                userQuery: trimmed,
                retrievedChunks: allowedChunks
            )

            let answerText = try await aiService.noSpoilerAnswer(fullPrompt: fullPrompt)
            guard generation == self.sessionGeneration else { return }

            let resolvedMessage = ChatMessage(
                id: placeholderId,
                sender: .ai,
                text: answerText,
                extractedChapter: clampedChapter,
                citedChapters: citedChapters,
                isOfflineMode: onDeviceStatus == "On-Device AI Ready"
            )

            if let index = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[index] = resolvedMessage
            } else {
                messages.append(resolvedMessage)
            }
        } catch {
            guard generation == self.sessionGeneration else { return }
            messages.removeAll { $0.id == placeholderId || ($0.sender == .ai && $0.text == "...") }
            messages.append(
                ChatMessage(
                    sender: .system,
                    text: "⚠️ Unable to query book context. Ensure you have chapter content loaded."
                )
            )
        }

        guard generation == self.sessionGeneration else { return }
        isLoading = false
        statusMessage = nil
    }

    /// Generates a spoiler-bounded 1880s Victorian pen-and-ink scene illustration for `sceneQuery`.
    ///
    /// - Parameters:
    ///   - sceneQuery: Natural-language description of the scene to illustrate.
    ///   - targetChapter: Optional explicit chapter boundary override; if `nil`, extracts from `sceneQuery`
    ///     or falls back to `lastDetectedChapter` / `defaultChapter`.
    public func visualizeScene(_ sceneQuery: String, targetChapter: Int? = nil) async {
        let trimmed = sceneQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let activeBook = resolveActiveBook()
        let rawChapter = targetChapter
            ?? SpoilerGuardManager.extractChapterFromPrompt(trimmed)
            ?? lastDetectedChapter
        let clampedChapter = SpoilerGuardManager.clampChapter(rawChapter, totalChapters: activeBook.totalChapters)

        let generation = sessionGeneration

        let userMessage = ChatMessage(
            sender: .user,
            text: trimmed,
            extractedChapter: clampedChapter
        )
        messages.append(userMessage)

        isLoading = true
        lastDetectedChapter = clampedChapter
        statusMessage = "🎨 Sherlock is illustrating the scene with Nano Banana AI (Chapter \(clampedChapter))..."

        do {
            let allowedChunks = try await repository.getSpoilerBoundedChunks(
                bookId: activeBook.id,
                targetChapterOrder: clampedChapter
            )
            guard generation == self.sessionGeneration else { return }

            let citedChapters = Array(Set(allowedChunks.map(\.chapterOrder))).sorted()

            let visualPrompt = SpoilerGuardManager.buildSceneVisualizationPrompt(
                bookTitle: activeBook.title,
                targetChapter: clampedChapter,
                userQuery: trimmed,
                retrievedChunks: allowedChunks
            )

            let result = try await aiService.generateSceneIllustration(visualPrompt: visualPrompt)
            guard generation == self.sessionGeneration else { return }

            let captionText = result.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "🎨 *Scene Illustration (Chapter \(clampedChapter) - Sidney Paget Victorian style)*"
                : result.caption

            let illustrationMessage = ChatMessage(
                sender: .ai,
                text: captionText,
                extractedChapter: clampedChapter,
                citedChapters: citedChapters,
                isOfflineMode: onDeviceStatus == "On-Device AI Ready",
                imageData: result.imageData,
                isSceneVisualization: true
            )
            messages.append(illustrationMessage)
        } catch {
            guard generation == self.sessionGeneration else { return }
            messages.append(
                ChatMessage(
                    sender: .system,
                    text: "⚠️ Unable to generate scene visualization: \(error.localizedDescription)"
                )
            )
        }

        guard generation == self.sessionGeneration else { return }
        isLoading = false
        statusMessage = nil
    }

    // MARK: - Private Helpers

    private func resolveActiveBook() -> Book {
        if let selectedBook {
            return selectedBook
        }
        let fallback = Book(
            id: "study_in_scarlet",
            universeId: "sherlock_holmes",
            bookOrder: 1,
            title: "A Study in Scarlet",
            author: "Sir Arthur Conan Doyle",
            totalChapters: 14
        )
        selectedBook = fallback
        return fallback
    }

    private func makeWelcomeMessage(for book: Book) -> ChatMessage {
        ChatMessage(
            sender: .system,
            text: "🔍 Welcome to No Spoilers, Sherlock!\nAsk any question about '\(book.title)' (e.g. 'In chapter 3, who was killed at Lauriston Gardens?'). I will automatically detect your chapter and strictly prevent any future spoilers!"
        )
    }
}
