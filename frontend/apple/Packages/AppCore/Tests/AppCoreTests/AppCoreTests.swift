import Foundation
import ImageIO
import Testing
@testable import AppCore

@Suite("AppCore Acceptance Criteria & Domain Verification")
struct AppCoreTests {

    // MARK: - AC-1: Explicit Chapter Extraction & Negative Rejection

    @Test("AC-1: Extracts explicit positive chapter numbers and rejects negative chapter numbers")
    func testExtractChapterFromPrompt() {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter 5, what did Holmes find?") == 5)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Tell me about ch 3") == 3)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Tell me about ch. 3") == 3)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chap 12 summary") == 12)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("in the 4th chapter") == 4)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In the 1st chapter, where did Watson study?") == 1)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Events of the 2nd chapter") == 2)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Events of the 3rd chapter") == 3)

        // Negative rejection
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter -3, what happened?") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In the -4th chapter, what happened?") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("ch. -1 summary") == nil)
    }

    // MARK: - AC-2: Implicit Chapter Fallback & Boundary Clamping

    @Test("AC-2: Falls back to defaultChapter when prompt omits chapter and clamps out-of-range chapters")
    @MainActor
    func testImplicitFallbackAndBoundaryClamping() async {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Who is Inspector Lestrade?") == nil)
        #expect(SpoilerGuardManager.clampChapter(0, totalChapters: 14) == 1)
        #expect(SpoilerGuardManager.clampChapter(-5, totalChapters: 14) == 1)
        #expect(SpoilerGuardManager.clampChapter(99, totalChapters: 14) == 14)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        // Implicit fallback to defaultChapter (3)
        await viewModel.sendMessage("Who is Inspector Lestrade?")
        #expect(viewModel.lastDetectedChapter == 3)
        #expect(viewModel.messages.last?.extractedChapter == 3)

        // Chapter 0 clamps to 1
        await viewModel.sendMessage("In chapter 0, who is Holmes?")
        #expect(viewModel.lastDetectedChapter == 1)
        #expect(viewModel.messages.last?.extractedChapter == 1)

        // Chapter 99 clamps to 14 (totalChapters for A Study in Scarlet)
        await viewModel.sendMessage("In chapter 99, who is the killer?")
        #expect(viewModel.lastDetectedChapter == 14)
        #expect(viewModel.messages.last?.extractedChapter == 14)
    }

    // MARK: - AC-3: Visualization Keyword Detection

    @Test("AC-3: Detects all 12 visualization keywords case-insensitively and returns false for normal queries")
    func testVisualizationKeywordDetection() {
        let keywords = [
            "visualize",
            "visualise",
            "illustrate",
            "draw",
            "sketch",
            "picture",
            "show me the scene",
            "generate an image",
            "generate image",
            "scene of",
            "depict",
            "portrait of"
        ]

        for keyword in keywords {
            #expect(SpoilerGuardManager.isVisualizationRequest("Please \(keyword.uppercased()) Lauriston Gardens in Chapter 3"))
        }

        #expect(!SpoilerGuardManager.isVisualizationRequest("In Chapter 3, who died at Lauriston Gardens?"))
        #expect(!SpoilerGuardManager.isVisualizationRequest("Who is Inspector Lestrade?"))
    }

    // MARK: - AC-4: Database-Level Spoiler Filtering

    @Test("AC-4: Repository returns only chunks with chapterOrder <= targetChapterOrder sorted ascending")
    func testDatabaseLevelSpoilerFiltering() async throws {
        let repo = InMemorySeededBookRepository()
        try await repo.ensureSampleDataPopulated()

        let allChapters = try await repo.getChapters(bookId: "study_in_scarlet")
        #expect(allChapters.count == 7)
        #expect(allChapters.map(\.chapterOrder) == [1, 2, 3, 4, 5, 6, 7])

        let boundedChunks = try await repo.getSpoilerBoundedChunks(
            bookId: "study_in_scarlet",
            targetChapterOrder: 3
        )
        #expect(boundedChunks.count == 3)
        #expect(boundedChunks.map(\.chapterOrder) == [1, 2, 3])
        #expect(boundedChunks.allSatisfy { $0.bookId == "study_in_scarlet" && $0.chapterOrder <= 3 })
        #expect(boundedChunks.last?.content.contains("Enoch J. Drebber") == true)
        #expect(boundedChunks.allSatisfy { !$0.content.contains("Joseph Stangerson") })
    }

    // MARK: - AC-5: System Guardrail Prompt Construction

    @Test("AC-5: Builds spoiler guardrail prompt with stripped summary prefix and STRICT SPOILER GUARDBOUND")
    func testBuildSpoilerGuardrailPrompt() async throws {
        let repo = InMemorySeededBookRepository()
        let chunks = try await repo.getSpoilerBoundedChunks(bookId: "study_in_scarlet", targetChapterOrder: 3)

        let prompt = SpoilerGuardManager.buildSpoilerGuardrailPrompt(
            bookTitle: "A Study in Scarlet",
            targetChapter: 3,
            userQuery: "Who was killed?",
            retrievedChunks: chunks
        )

        #expect(prompt.contains("CHAPTER 3"))
        #expect(prompt.contains("A Study in Scarlet"))
        #expect(prompt.contains("ABSOLUTELY DO NOT reveal"))
        #expect(!prompt.contains("Summary of Chapter 3 (The Lauriston Garden Mystery):"))
        #expect(prompt.contains("- Chapter 1: In 1878 I took my degree of Doctor of Medicine"))
        #expect(prompt.contains("- Chapter 3: A telegram arrives from Inspector Tobias Gregson"))
        #expect(prompt.contains("Sherlock's Direct Answer (ZERO SPOILERS beyond Chapter 3! Do not list chapters):"))
    }

    // MARK: - AC-6: Scene Visualization Prompt Construction

    @Test("AC-6: Builds scene visualization prompt specifying Sidney Paget and 1880s Victorian London")
    func testBuildSceneVisualizationPrompt() async throws {
        let repo = InMemorySeededBookRepository()
        let chunks = try await repo.getSpoilerBoundedChunks(bookId: "study_in_scarlet", targetChapterOrder: 3)

        let visualPrompt = SpoilerGuardManager.buildSceneVisualizationPrompt(
            bookTitle: "A Study in Scarlet",
            targetChapter: 3,
            userQuery: "Visualize Lauriston Gardens in Chapter 3",
            retrievedChunks: chunks
        )

        #expect(visualPrompt.contains("Sidney Paget's original illustrations for Sherlock Holmes in The Strand Magazine"))
        #expect(visualPrompt.contains("STRICT SPOILER GUARDBOUND"))
        #expect(visualPrompt.contains("CHAPTER 3"))
        #expect(visualPrompt.contains("1880s Victorian London"))
        #expect(!visualPrompt.contains("Summary of Chapter 3"))
    }

    // MARK: - AC-7: Initial App State & Welcome Message

    @Test("AC-7: Initializes ChatViewModel with two seeded books, A Study in Scarlet selected, defaultChapter 3, and welcome message")
    @MainActor
    func testInitialAppStateAndWelcomeMessage() async {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        #expect(viewModel.books.count == 2)
        #expect(viewModel.books.map(\.id) == ["study_in_scarlet", "sign_of_the_four"])
        #expect(viewModel.selectedBook?.id == "study_in_scarlet")
        #expect(viewModel.selectedBook?.totalChapters == 14)
        #expect(viewModel.defaultChapter == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.sender == .system)
        #expect(viewModel.messages.first?.text.contains("'A Study in Scarlet'") == true)
    }

    // MARK: - AC-8: End-to-End Spoiler-Free Q&A Flow & Interim Replacement

    @Test("AC-8: Executes Q&A flow, replaces interim '...' bubble, and populates extractedChapter and citedChapters")
    @MainActor
    func testEndToEndSpoilerFreeQAAndInterimReplacement() async throws {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        #expect(viewModel.messages.count == 1)

        await viewModel.sendMessage("In chapter 3, who died?")

        #expect(viewModel.messages.count == 3)
        #expect(!viewModel.messages.contains { $0.text == "..." })

        let userMessage = viewModel.messages[1]
        #expect(userMessage.sender == .user)
        #expect(userMessage.extractedChapter == 3)

        let aiMessage = viewModel.messages[2]
        #expect(aiMessage.sender == .ai)
        #expect(aiMessage.extractedChapter == 3)
        #expect(aiMessage.citedChapters == [1, 2, 3])
        #expect(aiMessage.text.contains("Enoch J. Drebber"))
        #expect(!aiMessage.text.contains("Joseph Stangerson"))
        #expect(viewModel.lastDetectedChapter == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.statusMessage == nil)
    }

    // MARK: - AC-9: End-to-End Scene Visualization Flow

    @Test("AC-9: Generates Victorian scene visualization with valid PNG data and non-empty caption")
    @MainActor
    func testEndToEndSceneVisualizationFlow() async throws {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        await viewModel.sendMessage("🎨 Visualize Lauriston Gardens in Chapter 3")

        let aiMessage = try #require(viewModel.messages.last)
        #expect(aiMessage.sender == .ai)
        #expect(aiMessage.isSceneVisualization == true)
        #expect(aiMessage.extractedChapter == 3)
        #expect(aiMessage.citedChapters == [1, 2, 3])
        #expect(!aiMessage.text.isEmpty)

        let pngData = try #require(aiMessage.imageData)
        // Verify standard 8-byte PNG header signature: 89 50 4E 47 0D 0A 1A 0A
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(pngData.prefix(8)) == pngSignature)

        // Verify CGImageSource / UIImage / NSImage decoding succeeds
        let imageSource = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        #expect(CGImageSourceGetCount(imageSource) == 1)
        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        #expect(cgImage != nil)
    }

    // MARK: - AC-10: Book Switching & Conversation Reset

    @Test("AC-10: Switching book to The Sign of the Four updates selectedBook, resets messages, and queries new book chunks")
    @MainActor
    func testBookSelectionAndStateReset() async throws {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        let signOfTheFour = try #require(viewModel.books.first { $0.id == "sign_of_the_four" })
        #expect(signOfTheFour.title == "The Sign of the Four")
        #expect(signOfTheFour.author == "Sir Arthur Conan Doyle")
        #expect(signOfTheFour.totalChapters == 12)

        viewModel.selectBook(signOfTheFour)

        #expect(viewModel.selectedBook?.id == "sign_of_the_four")
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.sender == .system)
        #expect(viewModel.messages.first?.text.contains("'The Sign of the Four'") == true)

        await viewModel.sendMessage("In Chapter 2, who is Miss Morstan?")
        #expect(viewModel.messages.count == 3)
        let aiMessage = try #require(viewModel.messages.last)
        #expect(aiMessage.extractedChapter == 2)
        #expect(aiMessage.citedChapters == [1, 2])
        #expect(aiMessage.text.contains("Mary Morstan"))

        viewModel.clearConversation()
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Error Handling & Edge Cases

    private struct FailingAiService: AiServiceProtocol {
        struct MockError: LocalizedError {
            var errorDescription: String? { "Mock AI failure" }
        }

        func checkAndDownloadOnDeviceModel() async -> String? {
            "On-Device AI Ready"
        }

        func noSpoilerAnswer(fullPrompt: String) async throws -> String {
            throw MockError()
        }

        func generateSceneIllustration(visualPrompt: String) async throws -> SceneIllustrationResult {
            throw MockError()
        }
    }

    @Test("Error Handling: Removes interim '...' placeholder on Q&A error and posts system warning")
    @MainActor
    func testErrorHandlingRemovesInterimBubble() async {
        let viewModel = ChatViewModel(
            repository: InMemorySeededBookRepository(),
            aiService: FailingAiService()
        )
        await viewModel.loadBooksAndInit()
        #expect(viewModel.onDeviceStatus == "On-Device AI Ready")

        await viewModel.sendMessage("In chapter 3, who died?")

        #expect(!viewModel.messages.contains { $0.text == "..." })
        #expect(viewModel.messages.last?.sender == .system)
        #expect(viewModel.messages.last?.text == "⚠️ Unable to query book context. Ensure you have chapter content loaded.")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.statusMessage == nil)

        await viewModel.visualizeScene("Visualize Chapter 3", targetChapter: 3)
        #expect(viewModel.messages.last?.sender == .system)
        #expect(viewModel.messages.last?.text.contains("⚠️ Unable to generate scene visualization:") == true)
    }

    // MARK: - Adversarial Red Team QA Suite

    @Test("Adversarial: Negative, zero, huge chapter inputs, and ordinal variations")
    @MainActor
    func testAdversarialChapterInputsAndOrdinals() async {
        // Negative chapter inputs must strictly return nil
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter -3") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("ch -1") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chap -99") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("-1st chapter") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("-14th chapter") == nil)

        // Zero chapter extraction and clamping
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chapter 0") == 0)
        #expect(SpoilerGuardManager.clampChapter(0, totalChapters: 14) == 1)

        // Huge chapter numbers extraction and clamping to totalChapters
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter 9999") == 9999)
        #expect(SpoilerGuardManager.clampChapter(9999, totalChapters: 14) == 14)
        #expect(SpoilerGuardManager.clampChapter(9999, totalChapters: 12) == 12)

        // Ordinal variations
        #expect(SpoilerGuardManager.extractChapterFromPrompt("1st chapter") == 1)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("2nd chapter") == 2)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("3rd chapter") == 3)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("14th chapter") == 14)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        // Negative chapter in ChatViewModel falls back to defaultChapter (3)
        await viewModel.sendMessage("In chapter -3, what happened?")
        #expect(viewModel.lastDetectedChapter == 3)
        #expect(viewModel.messages.last?.extractedChapter == 3)

        // Huge chapter in ChatViewModel clamps to totalChapters (14 for A Study in Scarlet)
        await viewModel.sendMessage("In chapter 9999, what happened?")
        #expect(viewModel.lastDetectedChapter == 14)
        #expect(viewModel.messages.last?.extractedChapter == 14)
    }

    @Test("Adversarial: Whitespace and empty prompts are ignored without mutating state")
    @MainActor
    func testAdversarialWhitespaceAndEmptyPrompts() async {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        let initialCount = viewModel.messages.count
        #expect(initialCount == 1)

        await viewModel.sendMessage("")
        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.isLoading == false)

        await viewModel.sendMessage("   ")
        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.isLoading == false)

        await viewModel.sendMessage("\n\t  \n")
        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.isLoading == false)

        await viewModel.visualizeScene("")
        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.isLoading == false)

        await viewModel.visualizeScene("   ")
        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.isLoading == false)
    }

    @Test("Adversarial: Multi-chapter prompt mentions extract the first chapter boundary to prevent spoiler escalation")
    @MainActor
    func testAdversarialMultiChapterPromptMentions() async throws {
        // When a user compares an early chapter with a later chapter ("Compare chapter 2 and chapter 7"),
        // extracting the first chapter (2) ensures the lower boundary (Chapter 2) is enforced rather than leaking Chapter 7.
        let extracted = SpoilerGuardManager.extractChapterFromPrompt("Compare chapter 2 and chapter 7")
        #expect(extracted == 2)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        await viewModel.sendMessage("Compare chapter 2 and chapter 7")
        #expect(viewModel.lastDetectedChapter == 2)

        let aiMessage = try #require(viewModel.messages.last)
        #expect(aiMessage.extractedChapter == 2)
        #expect(aiMessage.citedChapters == [1, 2])
        #expect(!aiMessage.text.contains("Joseph Stangerson"))
        #expect(!aiMessage.text.contains("Enoch J. Drebber"))
    }

    @Test("Adversarial: Strict spoiler boundary at Chapter 2 never leaks Chapters 3-7 entities in guardrail prompt or AI answer")
    @MainActor
    func testAdversarialStrictSpoilerBoundaryAtChapter2() async throws {
        let repo = InMemorySeededBookRepository()
        try await repo.ensureSampleDataPopulated()

        let chunksUpToCh2 = try await repo.getSpoilerBoundedChunks(
            bookId: "study_in_scarlet",
            targetChapterOrder: 2
        )
        #expect(chunksUpToCh2.map(\.chapterOrder) == [1, 2])

        let forbiddenFutureEntities = [
            "Enoch J. Drebber",
            "RACHE",
            "John Rance",
            "Mrs. Sawyer",
            "Arthur Charpentier",
            "Joseph Stangerson"
        ]

        let adversarialQuestions = [
            "In chapter 2, who was murdered at Lauriston Gardens and who is the killer?",
            "In chapter 2, what clue did the wedding ring provide?",
            "In chapter 2, what did Inspector Lestrade say about the murder?"
        ]

        let aiService = DeterministicSherlockAiService()

        for question in adversarialQuestions {
            let guardrailPrompt = SpoilerGuardManager.buildSpoilerGuardrailPrompt(
                bookTitle: "A Study in Scarlet",
                targetChapter: 2,
                userQuery: question,
                retrievedChunks: chunksUpToCh2
            )
            let visualPrompt = SpoilerGuardManager.buildSceneVisualizationPrompt(
                bookTitle: "A Study in Scarlet",
                targetChapter: 2,
                userQuery: question,
                retrievedChunks: chunksUpToCh2
            )
            let aiAnswer = try await aiService.noSpoilerAnswer(fullPrompt: guardrailPrompt)

            for forbidden in forbiddenFutureEntities {
                #expect(!guardrailPrompt.contains(forbidden), "Guardrail prompt leaked '\(forbidden)' at Chapter 2")
                #expect(!visualPrompt.contains(forbidden), "Visual prompt leaked '\(forbidden)' at Chapter 2")
                #expect(!aiAnswer.contains(forbidden), "AI answer leaked '\(forbidden)' at Chapter 2")
            }
        }

        // Verify via ChatViewModel end-to-end at Chapter 2
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        await viewModel.sendMessage("In chapter 2, who was found dead and what clue was left?")
        let vmAnswer = try #require(viewModel.messages.last?.text)
        for forbidden in forbiddenFutureEntities {
            #expect(!vmAnswer.contains(forbidden), "ChatViewModel AI response leaked '\(forbidden)' at Chapter 2")
        }
    }

    @Test("Adversarial: Book switching isolates state, resets lastDetectedChapter to defaultChapter, and replaces messages with welcome message")
    @MainActor
    func testAdversarialBookSwitchingStateIsolation() async throws {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        // Advance lastDetectedChapter to 7 on A Study in Scarlet
        viewModel.setDefaultChapter(4)
        #expect(viewModel.defaultChapter == 4)

        await viewModel.sendMessage("In chapter 7, who was murdered?")
        #expect(viewModel.lastDetectedChapter == 7)
        #expect(viewModel.messages.count == 3)

        let signOfTheFour = try #require(viewModel.books.first { $0.id == "sign_of_the_four" })
        viewModel.selectBook(signOfTheFour)

        // Verify state isolation on book switch
        #expect(viewModel.selectedBook?.id == "sign_of_the_four")
        #expect(viewModel.lastDetectedChapter == viewModel.defaultChapter)
        #expect(viewModel.lastDetectedChapter == 4)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.sender == .system)
        #expect(viewModel.messages.first?.text.contains("'The Sign of the Four'") == true)
        #expect(viewModel.messages.first?.text.contains("Welcome to No Spoilers, Sherlock!") == true)
    }

    @Test("Adversarial: Direct visualizeScene call decodes valid non-empty PNG via CGImageSourceCreateWithData")
    @MainActor
    func testAdversarialVisualizeSceneDirectPNGDecoding() async throws {
        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()

        await viewModel.visualizeScene("Visualize the scene from Chapter 2", targetChapter: 2)
        #expect(viewModel.messages.count == 3)

        let aiMessage = try #require(viewModel.messages.last)
        #expect(aiMessage.sender == .ai)
        #expect(aiMessage.isSceneVisualization == true)
        #expect(aiMessage.extractedChapter == 2)
        #expect(aiMessage.citedChapters == [1, 2])

        let imageData = try #require(aiMessage.imageData)
        #expect(!imageData.isEmpty)

        let imageSource = try #require(CGImageSourceCreateWithData(imageData as CFData, nil))
        #expect(CGImageSourceGetCount(imageSource) >= 1)
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(cgImage.width >= 1)
        #expect(cgImage.height >= 1)
    }

    @Test("Adversarial: Chapter zero and negative rejection")
    @MainActor
    func adversarialChapterZeroAndNegativeRejection() async {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chapter 0") == 0)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter 0, what happened?") == 0)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chapter -3") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("ch. -5") == nil)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        await viewModel.sendMessage("In chapter 0, who is Holmes?")
        #expect(viewModel.lastDetectedChapter == 1)
        #expect(viewModel.messages.last?.extractedChapter == 1)
    }

    @Test("Adversarial: Ordinal suffix mismatches and huge 64-bit overflow chapter clamping")
    @MainActor
    func adversarialOrdinalSuffixMismatchesAndChapter9999Clamping() async {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter 99999999999999999999, who is the culprit?") == Int.max)
        #expect(SpoilerGuardManager.clampChapter(Int.max, totalChapters: 14) == 14)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("in the 3th chapter") == 3)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        await viewModel.sendMessage("In chapter 99999999999999999999, what happened?")
        #expect(viewModel.lastDetectedChapter == 14)
        #expect(viewModel.messages.last?.extractedChapter == 14)
    }

    @Test("Adversarial: Multi-chapter mention takes minimum boundary regardless of word order")
    @MainActor
    func adversarialMultiChapterMentionTakesMinimumBoundary() async {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Without spoiling chapter 7, tell me what happened in chapter 2") == 2)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("I am in the 2nd chapter, don't spoil chapter 10") == 2)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Don't spoil the 7th chapter, I am only on ch. 2") == 2)

        let viewModel = ChatViewModel()
        await viewModel.loadBooksAndInit()
        await viewModel.sendMessage("Without spoiling chapter 7, tell me what happened in chapter 2")
        #expect(viewModel.lastDetectedChapter == 2)
        #expect(viewModel.messages.last?.extractedChapter == 2)
        #expect(viewModel.messages.last?.citedChapters == [1, 2])
    }

    @Test("Adversarial: Visualization keyword false-positive guard for substrings and figurative idioms")
    func adversarialVisualizationKeywordFalsePositiveGuard() {
        // Substrings inside larger words must NOT trigger visualization
        #expect(!SpoilerGuardManager.isVisualizationRequest("Did Holmes withdraw from the room in chapter 3?"))
        #expect(!SpoilerGuardManager.isVisualizationRequest("Was the countryside picturesque in chapter 2?"))
        #expect(!SpoilerGuardManager.isVisualizationRequest("The suspect's alibi sounded sketchy in chapter 4."))

        // Figurative English idioms must NOT trigger visualization
        #expect(!SpoilerGuardManager.isVisualizationRequest("What is the big picture in chapter 3?"))
        #expect(!SpoilerGuardManager.isVisualizationRequest("What conclusion did Holmes draw in chapter 3?"))
        #expect(!SpoilerGuardManager.isVisualizationRequest("Can we draw a conclusion from the ring in chapter 5?"))

        // Genuine visual prompts MUST still trigger visualization
        #expect(SpoilerGuardManager.isVisualizationRequest("Draw the crime scene in chapter 3"))
        #expect(SpoilerGuardManager.isVisualizationRequest("Sketch Sherlock Holmes at 221B Baker Street"))
        #expect(SpoilerGuardManager.isVisualizationRequest("Show me a picture of Lauriston Gardens"))
    }

    private actor DelayedAiService: AiServiceProtocol {
        func checkAndDownloadOnDeviceModel() async -> String? { nil }

        func noSpoilerAnswer(fullPrompt: String) async throws -> String {
            try await Task.sleep(for: .milliseconds(50))
            return "Delayed answer from previous book session"
        }

        func generateSceneIllustration(visualPrompt: String) async throws -> SceneIllustrationResult {
            try await Task.sleep(for: .milliseconds(50))
            return SceneIllustrationResult(
                caption: "Delayed illustration",
                imageData: DeterministicSherlockAiService.victorianSepiaPlaceholderPNG
            )
        }
    }

    @Test("Adversarial: Concurrent book switch or clearConversation does not bleed in-flight messages")
    @MainActor
    func adversarialConcurrentBookSwitchDoesNotBleedMessages() async throws {
        let viewModel = ChatViewModel(
            repository: InMemorySeededBookRepository(),
            aiService: DelayedAiService()
        )
        await viewModel.loadBooksAndInit()

        let signOfTheFour = try #require(viewModel.books.first { $0.id == "sign_of_the_four" })

        let inFlightTask = Task { @MainActor in
            await viewModel.sendMessage("In chapter 3, who died?")
        }

        // Yield briefly so sendMessage starts, then switch book while AI call is suspended
        try await Task.sleep(for: .milliseconds(10))
        viewModel.selectBook(signOfTheFour)

        await inFlightTask.value

        // Ensure stale response from A Study in Scarlet did NOT bleed into The Sign of the Four
        #expect(viewModel.selectedBook?.id == "sign_of_the_four")
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.sender == .system)
        #expect(!viewModel.messages.contains { $0.text.contains("Delayed answer") })
        #expect(viewModel.isLoading == false)
    }
}
