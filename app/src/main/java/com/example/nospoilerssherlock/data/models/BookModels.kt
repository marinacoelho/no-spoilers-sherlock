package com.example.nospoilerssherlock.data.models

data class Book(
    val id: String = "",
    val universeId: String = "",
    val bookOrder: Int = 1,
    val title: String = "",
    val author: String = "",
    val totalChapters: Int = 1
)

data class Chapter(
    val id: String = "",
    val bookId: String = "",
    val chapterOrder: Int = 1,
    val title: String = ""
)

data class Chunk(
    val id: String = "",
    val bookId: String = "",
    val bookOrder: Int = 1,
    val chapterId: String = "",
    val chapterOrder: Int = 1,
    val chunkIndex: Int = 1,
    val content: String = ""
)

enum class MessageSender {
    USER, AI, SYSTEM
}

data class ChatMessage(
    val id: String = java.util.UUID.randomUUID().toString(),
    val sender: MessageSender,
    val text: String,
    val timestamp: Long = System.currentTimeMillis(),
    val extractedChapter: Int? = null,
    val citedChapters: List<Int> = emptyList(),
    val isOfflineMode: Boolean = false
)
