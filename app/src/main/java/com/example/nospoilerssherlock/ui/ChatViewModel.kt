package com.example.nospoilerssherlock.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.nospoilerssherlock.data.FirebaseAiService
import com.example.nospoilerssherlock.data.FirestoreRepository
import com.example.nospoilerssherlock.data.SpoilerGuardManager
import com.example.nospoilerssherlock.data.models.Book
import com.example.nospoilerssherlock.data.models.ChatMessage
import com.example.nospoilerssherlock.data.models.MessageSender
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
    val statusMessage: String? = null
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
                // Query Firestore for chunks up to extracted chapter
                val allowedChunks = firestoreRepository.getSpoilerBoundedChunks(activeBook.id, extractedChapter)
                val fallbackContextText = allowedChunks.joinToString("\n") { it.content }

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

                aiService.generateContentStream(fullPrompt, extractedChapter, fallbackContextText)
                    .collect { partialText ->
                        val currentList = _uiState.value.messages.toMutableList()
                        val lastIdx = currentList.lastIndex
                        if (lastIdx >= 0 && currentList[lastIdx].sender == MessageSender.AI) {
                            currentList[lastIdx] = currentList[lastIdx].copy(text = partialText)
                            _uiState.value = _uiState.value.copy(messages = currentList)
                        }
                    }
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
}
