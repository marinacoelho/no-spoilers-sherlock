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
     * Constructs system guardrail prompt restricting LLM output strictly up to [targetChapter].
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
            retrievedChunks.joinToString("\n") { chunk ->
                val cleanContent = chunk.content
                    .replace(Regex("""^Summary of Chapter \d+ \([^)]+\):\s*"""), "")
                    .trim()
                "- Chapter ${chunk.chapterOrder}: $cleanContent"
            }
        }

        return """
            SYSTEM INSTRUCTIONS:
            You are "No Spoilers, Sherlock", an intelligent AI reader assistant.
            Provide a concise, direct answer to the user's question using ONLY events known up to CHAPTER $targetChapter of "$bookTitle".
            Do NOT list, recite, or repeat the chapters. Answer only the specific question asked in 1-3 sentences.
            
            STRICT SPOILER GUARDBOUND:
            - You MUST ONLY use information from Chapters 1 through $targetChapter.
            - ABSOLUTELY DO NOT reveal, hint at, extrapolate, or mention any plot twists, character deaths, murderer identities, or events taking place AFTER Chapter $targetChapter.
            - If the user's question asks about something not yet revealed up to Chapter $targetChapter, respond politely without spoiling future chapters.

            Known events (Chapters 1-$targetChapter):
            $contextText

            USER QUESTION:
            "$userQuery"

            Sherlock's Direct Answer (ZERO SPOILERS beyond Chapter $targetChapter! Do not list chapters):
        """.trimIndent()
    }
}
