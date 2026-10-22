package com.example.nospoilerssherlock.data

import com.example.nospoilerssherlock.data.models.Book
import com.example.nospoilerssherlock.data.models.Chapter
import com.example.nospoilerssherlock.data.models.Chunk
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings
import com.google.firebase.firestore.PersistentCacheSettings
import com.google.firebase.firestore.Source
import kotlinx.coroutines.tasks.await

class FirestoreRepository {

    private val firestore: FirebaseFirestore by lazy {
        val instance = FirebaseFirestore.getInstance()
        val settings = FirebaseFirestoreSettings.Builder()
            .setLocalCacheSettings(PersistentCacheSettings.newBuilder().build())
            .build()
        instance.firestoreSettings = settings
        instance
    }

    /**
     * Seeds initial sample public domain book data (Sherlock Holmes - A Study in Scarlet)
     * if Firestore is empty.
     */
    suspend fun ensureSampleDataPopulated() {
        try {
            val booksSnapshot = firestore.collection("books").get().await()
            if (booksSnapshot.isEmpty) {
                seedStudyInScarletData()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    suspend fun getBooks(): List<Book> {
        return try {
            val snapshot = firestore.collection("books").get(Source.DEFAULT).await()
            snapshot.documents.mapNotNull { doc ->
                Book(
                    id = doc.id,
                    universeId = doc.getString("universeId") ?: "",
                    bookOrder = doc.getLong("bookOrder")?.toInt() ?: 1,
                    title = doc.getString("title") ?: "",
                    author = doc.getString("author") ?: "",
                    totalChapters = doc.getLong("totalChapters")?.toInt() ?: 1
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun getChapters(bookId: String): List<Chapter> {
        return try {
            val snapshot = firestore.collection("chapters")
                .whereEqualTo("bookId", bookId)
                .get(Source.DEFAULT)
                .await()

            snapshot.documents.mapNotNull { doc ->
                Chapter(
                    id = doc.id,
                    bookId = doc.getString("bookId") ?: "",
                    chapterOrder = doc.getLong("chapterOrder")?.toInt() ?: 1,
                    title = doc.getString("title") ?: ""
                )
            }.sortedBy { it.chapterOrder }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Fetches context chunks strictly bounded up to [targetChapterOrder].
     * Reads directly from persistent local cache if offline!
     */
    suspend fun getSpoilerBoundedChunks(bookId: String, targetChapterOrder: Int): List<Chunk> {
        return try {
            val snapshot = firestore.collection("chunks")
                .whereEqualTo("bookId", bookId)
                .whereLessThanOrEqualTo("chapterOrder", targetChapterOrder)
                .get(Source.DEFAULT)
                .await()

            snapshot.documents.mapNotNull { doc ->
                Chunk(
                    id = doc.id,
                    bookId = doc.getString("bookId") ?: "",
                    bookOrder = doc.getLong("bookOrder")?.toInt() ?: 1,
                    chapterId = doc.getString("chapterId") ?: "",
                    chapterOrder = doc.getLong("chapterOrder")?.toInt() ?: 1,
                    chunkIndex = doc.getLong("chunkIndex")?.toInt() ?: 1,
                    content = doc.getString("content") ?: ""
                )
            }.sortedBy { it.chapterOrder }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private suspend fun seedStudyInScarletData() {
        val bookId = "study_in_scarlet"
        val bookData = mapOf(
            "universeId" to "sherlock_holmes",
            "bookOrder" to 1,
            "title" to "A Study in Scarlet",
            "author" to "Sir Arthur Conan Doyle",
            "totalChapters" to 14
        )
        firestore.collection("books").document(bookId).set(bookData).await()

        val sampleChapters = listOf(
            Triple(1, "Mr. Sherlock Holmes", "In 1878 I took my degree of Doctor of Medicine at the University of London... There I met Stamford and learned of Sherlock Holmes searching for a companion to share rooms at 221B Baker Street."),
            Triple(2, "The Science of Deduction", "Sherlock Holmes was a man who performed strange chemical experiments and possessed exact knowledge of crime history. He explained his deduction methods from a magazine article."),
            Triple(3, "The Lauriston Garden Mystery", "A telegram arrives from Inspector Tobias Gregson regarding a murder at 3 Lauriston Gardens near Brixton Road. The dead man is identified as Enoch J. Drebber of Cleveland, Ohio. The word 'RACHE' is written in blood on the wall."),
            Triple(4, "What John Rance Had to Tell", "Constable John Rance recalls seeing a drunk man lurking outside Lauriston Gardens near the crime scene. Holmes deduces the drunk man was actually the murderer returning for the ring."),
            Triple(5, "Our Advertisement Brings a Visitor", "Holmes places an advertisement in the newspaper offering a lost gold wedding ring found in Brixton Road. An old woman named Mrs. Sawyer arrives at 221B Baker Street to claim it."),
            Triple(6, "Tobias Gregson Shows What He Can Do", "Inspector Gregson arrests Arthur Charpentier, son of the boarding-house keeper where Drebber stayed, believing he committed the crime due to a quarrel."),
            Triple(7, "Light in the Darkness", "Inspector Lestrade arrives with shocking news: Joseph Stangerson, secretary to Enoch Drebber, has also been murdered at Halliday's Private Hotel!")
        )

        for ((chNum, title, summary) in sampleChapters) {
            val chId = "${bookId}_ch${chNum.toString().padStart(2, '0')}"
            firestore.collection("chapters").document(chId).set(
                mapOf(
                    "bookId" to bookId,
                    "chapterOrder" to chNum,
                    "title" to title
                )
            ).await()

            val chunkId = "chunk_${chId}_001"
            firestore.collection("chunks").document(chunkId).set(
                mapOf(
                    "bookId" to bookId,
                    "bookOrder" to 1,
                    "chapterId" to chId,
                    "chapterOrder" to chNum,
                    "chunkIndex" to 1,
                    "content" to "Summary of Chapter $chNum ($title): $summary"
                )
            ).await()
        }
    }
}
