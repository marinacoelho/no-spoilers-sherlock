import Foundation
import SwiftUI
import Testing
@testable import AppCore
@testable import no_spoilers_sherlock

@Suite("No Spoilers, Sherlock iOS Application & AppCore Integration Tests")
struct NoSpoilersSherlockTests {

    @Test("AC-1 & AC-2: Chapter extraction, negative rejection, fallback, and clamping")
    func testChapterExtractionAndClamping() {
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter 5, what did Holmes find?") == 5)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Tell me about ch 3") == 3)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("chap 12 summary") == 12)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("in the 4th chapter") == 4)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("In chapter -3, what happened?") == nil)
        #expect(SpoilerGuardManager.extractChapterFromPrompt("Who is Inspector Lestrade?") == nil)

        #expect(SpoilerGuardManager.clampChapter(0, totalChapters: 14) == 1)
        #expect(SpoilerGuardManager.clampChapter(99, totalChapters: 14) == 14)
    }

    @Test("AC-3: Visualization keyword detection")
    func testVisualizationKeywordDetection() {
        #expect(SpoilerGuardManager.isVisualizationRequest("🎨 Visualize Lauriston Gardens in Chapter 3") == true)
        #expect(SpoilerGuardManager.isVisualizationRequest("Please sketch the room") == true)
        #expect(SpoilerGuardManager.isVisualizationRequest("In Chapter 3, who died?") == false)
    }

    @Test("AC-11: Apple HIG System Default Semantic Colors in SherlockTheme")
    func testAppleHIGSystemDefaultColors() {
        #expect(SherlockTheme.primaryText == Color.primary)
        #expect(SherlockTheme.secondaryText == Color.secondary)
        #expect(SherlockTheme.accent == Color.accentColor)
        #expect(SherlockTheme.userBubbleBackground == Color.accentColor)
        #expect(SherlockTheme.aiBubbleBackground == SherlockTheme.secondaryBackground)
        #expect(SherlockTheme.victorianGold == Color.accentColor)
        #expect(SherlockTheme.parchmentCream == Color.primary)
        #expect(SherlockTheme.fogGrey == Color.secondary)
        #expect(SherlockTheme.spoilerRedAccent == Color.red)
        #expect(SherlockTheme.citationGreen == Color.green)
        #expect(SherlockTheme.detectiveNavyDark == SherlockTheme.background)
        #expect(SherlockTheme.detectiveNavyMedium == SherlockTheme.secondaryBackground)
        #expect(SherlockTheme.detectiveNavyLight == SherlockTheme.tertiaryBackground)
    }

    @Test("AC-4, AC-7, AC-8, AC-9, AC-10: End-to-End ViewModel & Dependency Container flows")
    @MainActor
    func testViewModelAndDependencyContainerFlows() async {
        let container = AppDependencyContainer(
            bookRepository: InMemorySeededBookRepository(),
            aiService: DeterministicSherlockAiService()
        )
        let viewModel = container.makeChatViewModel()

        await viewModel.loadBooksAndInit()

        #expect(viewModel.books.count == 2)
        #expect(viewModel.selectedBook?.id == "study_in_scarlet")
        #expect(viewModel.defaultChapter == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.sender == .system)

        // AC-8: End-to-End Spoiler-Free Q&A Flow & Interim Replacement
        await viewModel.sendMessage("In chapter 3, who died?")
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[1].sender == .user)
        #expect(viewModel.messages[1].extractedChapter == 3)
        #expect(viewModel.messages[2].sender == .ai)
        #expect(viewModel.messages[2].extractedChapter == 3)
        #expect(viewModel.messages[2].citedChapters == [1, 2, 3])
        #expect(viewModel.messages[2].text != "...")

        // AC-9: Scene visualization flow & cross-platform image decoding
        await viewModel.visualizeScene("Visualize the scene from Chapter 3", targetChapter: 3)
        #expect(viewModel.messages.count == 5)
        let vizMessage = viewModel.messages.last
        #expect(vizMessage?.isSceneVisualization == true)
        #expect(vizMessage?.extractedChapter == 3)
        #expect(vizMessage?.imageData != nil)
        if let data = vizMessage?.imageData {
            #expect(SherlockPlatformImage.swiftUIImage(from: data) != nil)
        }

        // AC-10: Book switching and QuickPromptSuggestions
        if let signOfFour = viewModel.books.first(where: { $0.id == "sign_of_the_four" }) {
            viewModel.selectBook(signOfFour)
            #expect(viewModel.selectedBook?.id == "sign_of_the_four")
            #expect(viewModel.messages.count == 1)
            #expect(viewModel.messages.first?.text.contains("The Sign of the Four") == true)

            let quickPrompts = QuickPromptSuggestions(selectedBookId: signOfFour.id, onSuggestionClick: { _ in })
            #expect(quickPrompts.suggestions.contains("In Chapter 2, who is Miss Morstan?"))
        }

        // Clear conversation for EmptyChatHero
        viewModel.clearConversation()
        #expect(viewModel.messages.isEmpty)
    }
}
