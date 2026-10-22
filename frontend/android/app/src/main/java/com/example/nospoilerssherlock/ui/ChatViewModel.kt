package com.example.nospoilerssherlock.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.nospoilerssherlock.data.FirebaseAiService
import com.example.nospoilerssherlock.data.FirestoreRepository
import com.example.nospoilerssherlock.data.SpoilerGuardManager
import com.example.nospoilerssherlock.data.models.Book
import com.example.nospoilerssherlock.data.models.ChatMessage
import com.example.nospoilerssherlock.data.models.MessageSender
import com.google.firebase.ai.OnDeviceModelStatus
import com.google.firebase.ai.type.PublicPreviewAPI
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ChatUiState(
    val books: List<Book> = emptyList(),
    val selectedBook: Book? = null,
    val defaultChapter: Int = 3,
    val messages: List<ChatMessage> = emptyList(),
    val isLoading: Boolean = false,
    val lastDetectedChapter: Int? = null,
    val statusMessage: String? = null,
    val onDeviceStatus: String? = null
)

class ChatViewModel(
    private val firestoreRepository: FirestoreRepository = FirestoreRepository(),
    private val aiService: FirebaseAiService = FirebaseAiService()
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    init {
        loadBooksAndInit()
    }

    private fun loadBooksAndInit() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            firestoreRepository.ensureSampleDataPopulated()

            val books = firestoreRepository.getBooks()
            val initialBook = books.firstOrNull() ?: Book(
                id = "study_in_scarlet",
                title = "A Study in Scarlet",
                author = "Sir Arthur Conan Doyle",
                totalChapters = 14
            )

            val welcomeMessage = ChatMessage(
                sender = MessageSender.SYSTEM,
                text = "🔍 Welcome to No Spoilers, Sherlock!\nAsk any question about '${initialBook.title}' (e.g. 'In chapter 3, who was killed at Lauriston Gardens?'). I will automatically detect your chapter and strictly prevent any future spoilers!"
            )

            _uiState.value = _uiState.value.copy(
                books = books.ifEmpty { listOf(initialBook) },
                selectedBook = initialBook,
                messages = listOf(welcomeMessage),
                isLoading = false
            )

            // Check if user has on-device AI downloaded and installed.
            // If the device has the option to download an on-device model, download through Firebase AI Logic.
            @OptIn(PublicPreviewAPI::class)
            aiService.checkAndDownloadOnDeviceModel { status ->
                val statusText = when (status) {
                    OnDeviceModelStatus.AVAILABLE -> "On-Device AI Ready"
                    OnDeviceModelStatus.DOWNLOADING, OnDeviceModelStatus.DOWNLOADABLE -> "Downloading On-Device AI..."
                    else -> null
                }
                _uiState.value = _uiState.value.copy(onDeviceStatus = statusText)
            }
        }
    }


    fun selectBook(book: Book) {
        _uiState.value = _uiState.value.copy(selectedBook = book)
    }

    fun setDefaultChapter(chapterNum: Int) {
        _uiState.value = _uiState.value.copy(defaultChapter = chapterNum)
    }

    fun sendMessage(userText: String) {
        if (userText.isBlank()) return

        val activeBook = _uiState.value.selectedBook ?: return
        val extractedChapter = SpoilerGuardManager.extractChapterFromPrompt(userText)
            ?: _uiState.value.defaultChapter

        if (SpoilerGuardManager.isVisualizationRequest(userText)) {
            visualizeScene(userText, extractedChapter)
            return
        }

        val userMessage = ChatMessage(
            sender = MessageSender.USER,
            text = userText,
            extractedChapter = extractedChapter
        )

        val updatedMessages = _uiState.value.messages + userMessage
        _uiState.value = _uiState.value.copy(
            messages = updatedMessages,
            isLoading = true,
            lastDetectedChapter = extractedChapter,
            statusMessage = "Restricting spoiler boundary to Chapter $extractedChapter of ${activeBook.title}..."
        )

        viewModelScope.launch {
            try {
                val allowedChunks = firestoreRepository.getSpoilerBoundedChunks(activeBook.id, extractedChapter)

                val fullPrompt = SpoilerGuardManager.buildSpoilerGuardrailPrompt(
                    bookTitle = activeBook.title,
                    targetChapter = extractedChapter,
                    userQuery = userText,
                    retrievedChunks = allowedChunks
                )

                val initialAiMessage = ChatMessage(
                    sender = MessageSender.AI,
                    text = "...",
                    extractedChapter = extractedChapter,
                    citedChapters = allowedChunks.map { it.chapterOrder }.distinct()
                )

                _uiState.value = _uiState.value.copy(
                    messages = _uiState.value.messages + initialAiMessage
                )

                val noSpoilerAnswer = ChatMessage(
                    sender = MessageSender.AI,
                    text = aiService.noSpoilerAnswer(fullPrompt),
                    extractedChapter = extractedChapter,
                    citedChapters = allowedChunks.map { it.chapterOrder }.distinct()
                )

                _uiState.value = _uiState.value.copy(
                    messages = _uiState.value.messages + noSpoilerAnswer
                )
            } catch (e: Exception) {
                val errorMessage = ChatMessage(
                    sender = MessageSender.SYSTEM,
                    text = "⚠️ Unable to query book context. Ensure you have chapter content loaded."
                )
                _uiState.value = _uiState.value.copy(
                    messages = _uiState.value.messages + errorMessage
                )
            } finally {
                _uiState.value = _uiState.value.copy(isLoading = false, statusMessage = null)
            }
        }
    }

    /**
     * Generates a spoiler-bounded scene illustration using Nano Banana via Firebase AI Logic.
     */
    fun visualizeScene(sceneQuery: String, targetChapter: Int? = null) {
        val activeBook = _uiState.value.selectedBook ?: return
        val chapter = targetChapter
            ?: SpoilerGuardManager.extractChapterFromPrompt(sceneQuery)
            ?: _uiState.value.lastDetectedChapter
            ?: _uiState.value.defaultChapter

        val userMessage = ChatMessage(
            sender = MessageSender.USER,
            text = sceneQuery,
            extractedChapter = chapter
        )

        _uiState.value = _uiState.value.copy(
            messages = _uiState.value.messages + userMessage,
            isLoading = true,
            lastDetectedChapter = chapter,
            statusMessage = "🎨 Sherlock is illustrating the scene with Nano Banana AI (Chapter $chapter)..."
        )

        viewModelScope.launch {
            try {
                val allowedChunks = firestoreRepository.getSpoilerBoundedChunks(activeBook.id, chapter)

                val visualPrompt = SpoilerGuardManager.buildSceneVisualizationPrompt(
                    bookTitle = activeBook.title,
                    targetChapter = chapter,
                    userQuery = sceneQuery,
                    retrievedChunks = allowedChunks
                )

                val (caption, bitmap) = aiService.generateSceneIllustration(visualPrompt)

                val illustrationMessage = ChatMessage(
                    sender = MessageSender.AI,
                    text = if (caption.isNotBlank()) caption else "🎨 *Scene Illustration (Chapter $chapter - Sidney Paget Victorian style)*",
                    extractedChapter = chapter,
                    citedChapters = allowedChunks.map { it.chapterOrder }.distinct(),
                    imageBitmap = bitmap,
                    isSceneVisualization = true
                )

                _uiState.value = _uiState.value.copy(
                    messages = _uiState.value.messages + illustrationMessage
                )
            } catch (e: Exception) {
                val errorMessage = ChatMessage(
                    sender = MessageSender.SYSTEM,
                    text = "⚠️ Unable to generate scene visualization: ${e.localizedMessage ?: "Unknown error"}"
                )
                _uiState.value = _uiState.value.copy(
                    messages = _uiState.value.messages + errorMessage
                )
            } finally {
                _uiState.value = _uiState.value.copy(isLoading = false, statusMessage = null)
            }
        }
    }
}
