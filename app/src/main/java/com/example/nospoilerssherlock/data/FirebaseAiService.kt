package com.example.nospoilerssherlock.data

import com.google.firebase.Firebase
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.GenerativeBackend
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

class FirebaseAiService {
    /**
     * Generates a streaming response using Firebase AI Logic.
     * Falls back to context-based extraction if AI inference fails offline.
     */
    fun generateContentStream(
        fullPrompt: String,
        extractedChapter: Int,
        fallbackContextText: String
    ): Flow<String> = flow {
        try {
            val model = Firebase.ai(backend = GenerativeBackend.googleAI())
                .generativeModel("gemini-3.7-flash")

            var responseAccumulator = ""
            model.generateContentStream(fullPrompt).collect { chunk ->
                val chunkText = chunk.text
                if (!chunkText.isNullOrEmpty()) {
                    responseAccumulator += chunkText
                    emit(responseAccumulator)
                }
            }
            if (responseAccumulator.isEmpty()) {
                emit(generateFallbackAnswer(extractedChapter, fallbackContextText))
            }
        } catch (e: Exception) {
            emit(generateFallbackAnswer(extractedChapter, fallbackContextText))
        }
    }

    private fun generateFallbackAnswer(chapter: Int, contextText: String): String {
        return """
            [Offline Mode - Zero Spoilers]
            
            Based on events up to Chapter $chapter:
            $contextText
            
            (Note: Running in offline spoiler-guard mode. Future events past Chapter $chapter are strictly censored.)
        """.trimIndent()
    }
}
