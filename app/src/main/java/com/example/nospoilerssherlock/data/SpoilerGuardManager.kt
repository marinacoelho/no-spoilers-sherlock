package com.example.nospoilerssherlock.data

import com.example.nospoilerssherlock.data.models.Chunk
import java.util.regex.Pattern

object SpoilerGuardManager {

    /**
     * Extracts chapter number from user prompt (e.g. "In chapter 5, why...", "ch 3:", "chap. 12")
     * Returns null if no explicit chapter keyword is specified in prompt.
     */
    fun extractChapterFromPrompt(prompt: String): Int? {
        val lower = prompt.lowercase()
        val patterns = listOf(
            Pattern.compile("""\b(?:chapter|chap|ch\.?)\s*(\d+)\b"""),
            Pattern.compile("""\b(\d+)(?:st|nd|rd|th)?\s*chapter\b""")
        )

        for (pattern in patterns) {
            val matcher = pattern.matcher(lower)
            if (matcher.find()) {
                val group = matcher.group(1)
                group?.toIntOrNull()?.let { return it }
            }
        }
        return null
    }

    /**
     * Constructs system guardrail prompt restricting LLM output strictly up to [maxChapter].
     */
    fun buildSpoilerGuardrailPrompt(
        bookTitle: String,
        targetChapter: Int,
        userQuery: String,
        retrievedChunks: List<Chunk>
    ): String {
        val contextText = if (retrievedChunks.isEmpty()) {
            "No prior chapter excerpts found."
        } else {
            retrievedChunks.joinToString("\n\n") { chunk ->
                "[Book: $bookTitle | Chapter ${chunk.chapterOrder}]: ${chunk.content}"
            }
        }

        return """
            SYSTEM INSTRUCTIONS:
            You are "No Spoilers, Sherlock", an intelligent AI reader assistant for book series.
            
            STRICT SPOILER GUARDBOUND:
            - The reader is inquiring about events up to CHAPTER $targetChapter of "$bookTitle".
            - You MUST ONLY use information from Chapters 1 through $targetChapter.
            - ABSOLUTELY DO NOT reveal, hint at, extrapolate, or mention any plot twists, character deaths, murderer identities, or events taking place AFTER Chapter $targetChapter.
            - If the user's question asks about something that is only revealed in Chapter ${targetChapter + 1} or later, respond politely with:
              "🕵️ Spoiler Alert! That detail has not been revealed yet up to Chapter $targetChapter. Keep reading to find out!"
            
            PROVIDED CONTEXT (Chapters 1 to $targetChapter):
            $contextText
            
            USER QUESTION:
            "$userQuery"
            
            ANSWER (Remember: ZERO SPOILERS beyond Chapter $targetChapter!):
        """.trimIndent()
    }
}
