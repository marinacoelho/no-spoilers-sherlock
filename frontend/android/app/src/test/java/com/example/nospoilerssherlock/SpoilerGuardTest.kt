package com.example.nospoilerssherlock

import com.example.nospoilerssherlock.data.SpoilerGuardManager
import com.example.nospoilerssherlock.data.models.Chunk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SpoilerGuardTest {

    @Test
    fun testExtractChapterNumber() {
        assertEquals(5, SpoilerGuardManager.extractChapterFromPrompt("In chapter 5, what did Holmes find?"))
        assertEquals(3, SpoilerGuardManager.extractChapterFromPrompt("Tell me about ch 3"))
        assertEquals(12, SpoilerGuardManager.extractChapterFromPrompt("chap 12 summary"))
        assertEquals(4, SpoilerGuardManager.extractChapterFromPrompt("in the 4th chapter"))
        assertNull(SpoilerGuardManager.extractChapterFromPrompt("Who is Inspector Lestrade?"))
    }

    @Test
    fun testSpoilerGuardrailPromptConstruction() {
        val chunks = listOf(
            Chunk(id = "c1", bookId = "study", chapterOrder = 1, content = "Holmes meets Watson at Stamford."),
            Chunk(id = "c3", bookId = "study", chapterOrder = 3, content = "Enoch Drebber found dead at Lauriston Gardens.")
        )

        val prompt = SpoilerGuardManager.buildSpoilerGuardrailPrompt(
            bookTitle = "A Study in Scarlet",
            targetChapter = 3,
            userQuery = "Who was killed?",
            retrievedChunks = chunks
        )

        assertTrue(prompt.contains("CHAPTER 3"))
        assertTrue(prompt.contains("A Study in Scarlet"))
        assertTrue(prompt.contains("ABSOLUTELY DO NOT reveal"))
        assertTrue(prompt.contains("Enoch Drebber found dead"))
    }
}
