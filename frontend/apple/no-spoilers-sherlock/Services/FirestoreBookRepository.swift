import Foundation
import AppCore
import FirebaseCore
import FirebaseFirestore

/// A Cloud Firestore implementation of `BookRepositoryProtocol` with persistent local cache
/// and automatic fallback/merging with `InMemorySeededBookRepository`.
public actor FirestoreBookRepository: BookRepositoryProtocol {
    private let fallbackRepository = InMemorySeededBookRepository()
    private var didConfigureCache = false

    public init() {}

    private func firestoreInstance() -> Firestore? {
        guard FirebaseApp.app() != nil else {
            return nil
        }
        let db = Firestore.firestore()
        if !didConfigureCache {
            let settings = db.settings
            settings.cacheSettings = PersistentCacheSettings()
            db.settings = settings
            didConfigureCache = true
        }
        return db
    }

    public func ensureSampleDataPopulated() async throws {
        try? await fallbackRepository.ensureSampleDataPopulated()

        guard let db = firestoreInstance() else {
            return
        }

        do {
            let snapshot = try await db.collection("books").getDocuments()
            let existingBookIds = Set(snapshot.documents.map(\.documentID))
            let fallbackBooks = try await fallbackRepository.getBooks()
            for book in fallbackBooks where !existingBookIds.contains(book.id) {
                try await seedBookData(book, in: db)
            }
        } catch {
            // Gracefully fall back to in-memory seed data if offline or unreachable on first launch
        }
    }

    public func getBooks() async throws -> [Book] {
        let fallbackBooks = (try? await fallbackRepository.getBooks()) ?? []
        guard let db = firestoreInstance() else {
            return fallbackBooks
        }

        do {
            let snapshot = try await db.collection("books").getDocuments(source: .default)
            var booksById: [String: Book] = Dictionary(uniqueKeysWithValues: fallbackBooks.map { ($0.id, $0) })

            for doc in snapshot.documents {
                let data = doc.data()
                let book = Book(
                    id: doc.documentID,
                    universeId: data["universeId"] as? String ?? "",
                    bookOrder: Self.intValue(from: data["bookOrder"], default: 1),
                    title: data["title"] as? String ?? "",
                    author: data["author"] as? String ?? "",
                    totalChapters: Self.intValue(from: data["totalChapters"], default: 1)
                )
                booksById[book.id] = book
            }

            let merged = Array(booksById.values).sorted { $0.bookOrder < $1.bookOrder }
            if !merged.isEmpty {
                return merged
            }
        } catch {
            // Fall through to fallback repository
        }

        return fallbackBooks
    }

    public func getChapters(bookId: String) async throws -> [Chapter] {
        let fallbackChapters = (try? await fallbackRepository.getChapters(bookId: bookId)) ?? []
        guard let db = firestoreInstance() else {
            return fallbackChapters
        }

        do {
            let snapshot = try await db.collection("chapters")
                .whereField("bookId", isEqualTo: bookId)
                .getDocuments(source: .default)

            var chaptersByOrder: [Int: Chapter] = Dictionary(uniqueKeysWithValues: fallbackChapters.map { ($0.chapterOrder, $0) })
            for doc in snapshot.documents {
                let data = doc.data()
                let chapter = Chapter(
                    id: doc.documentID,
                    bookId: data["bookId"] as? String ?? "",
                    chapterOrder: Self.intValue(from: data["chapterOrder"], default: 1),
                    title: data["title"] as? String ?? ""
                )
                chaptersByOrder[chapter.chapterOrder] = chapter
            }

            let merged = Array(chaptersByOrder.values).sorted { $0.chapterOrder < $1.chapterOrder }
            if !merged.isEmpty {
                return merged
            }
        } catch {
            // Fall through to fallback repository
        }

        return fallbackChapters
    }

    public func getSpoilerBoundedChunks(bookId: String, targetChapterOrder: Int) async throws -> [Chunk] {
        guard let db = firestoreInstance() else {
            return try await fallbackRepository.getSpoilerBoundedChunks(
                bookId: bookId,
                targetChapterOrder: targetChapterOrder
            )
        }

        do {
            let snapshot = try await db.collection("chunks")
                .whereField("bookId", isEqualTo: bookId)
                .whereField("chapterOrder", isLessThanOrEqualTo: targetChapterOrder)
                .getDocuments(source: .default)

            let chunks: [Chunk] = snapshot.documents.map { doc in
                let data = doc.data()
                return Chunk(
                    id: doc.documentID,
                    bookId: data["bookId"] as? String ?? "",
                    bookOrder: Self.intValue(from: data["bookOrder"], default: 1),
                    chapterId: data["chapterId"] as? String ?? "",
                    chapterOrder: Self.intValue(from: data["chapterOrder"], default: 1),
                    chunkIndex: Self.intValue(from: data["chunkIndex"], default: 1),
                    content: data["content"] as? String ?? ""
                )
            }.sorted { lhs, rhs in
                if lhs.chapterOrder != rhs.chapterOrder {
                    return lhs.chapterOrder < rhs.chapterOrder
                }
                return lhs.chunkIndex < rhs.chunkIndex
            }

            if !chunks.isEmpty {
                return chunks
            }
        } catch {
            // Fall through to fallback repository
        }

        return try await fallbackRepository.getSpoilerBoundedChunks(
            bookId: bookId,
            targetChapterOrder: targetChapterOrder
        )
    }

    // MARK: - Private Seeding & Helpers

    private func seedBookData(_ book: Book, in db: Firestore) async throws {
        try await db.collection("books").document(book.id).setData([
            "universeId": book.universeId,
            "bookOrder": book.bookOrder,
            "title": book.title,
            "author": book.author,
            "totalChapters": book.totalChapters
        ])

        let chapters = try await fallbackRepository.getChapters(bookId: book.id)
        for chapter in chapters {
            try await db.collection("chapters").document(chapter.id).setData([
                "bookId": chapter.bookId,
                "chapterOrder": chapter.chapterOrder,
                "title": chapter.title
            ])
        }

        let chunks = try await fallbackRepository.getSpoilerBoundedChunks(
            bookId: book.id,
            targetChapterOrder: book.totalChapters
        )
        for chunk in chunks {
            try await db.collection("chunks").document(chunk.id).setData([
                "bookId": chunk.bookId,
                "bookOrder": chunk.bookOrder,
                "chapterId": chunk.chapterId,
                "chapterOrder": chunk.chapterOrder,
                "chunkIndex": chunk.chunkIndex,
                "content": chunk.content
            ])
        }
    }

    private static func intValue(from raw: Any?, default defaultValue: Int) -> Int {
        if let intVal = raw as? Int {
            return intVal
        } else if let int64Val = raw as? Int64 {
            return Int(int64Val)
        } else if let number = raw as? NSNumber {
            return number.intValue
        }
        return defaultValue
    }
}
