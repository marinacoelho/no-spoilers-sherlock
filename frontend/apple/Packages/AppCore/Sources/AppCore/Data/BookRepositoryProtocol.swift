import Foundation

/// Defines the persistence contract for loading books, chapters, and spoiler-bounded narrative chunks.
public protocol BookRepositoryProtocol: Sendable {
    /// Ensures the repository is populated with initial Sherlock Holmes canon data if empty.
    func ensureSampleDataPopulated() async throws

    /// Returns all available books sorted by `bookOrder` ascending.
    func getBooks() async throws -> [Book]

    /// Returns all chapters for a specific book sorted by `chapterOrder` ascending.
    ///
    /// - Parameter bookId: Identifier of the target book.
    func getChapters(bookId: String) async throws -> [Chapter]

    /// Returns only narrative chunks for `bookId` whose `chapterOrder <= targetChapterOrder`,
    /// sorted ascending by `chapterOrder`.
    ///
    /// - Parameters:
    ///   - bookId: Identifier of the active book.
    ///   - targetChapterOrder: Maximum inclusive chapter order allowed by the spoiler boundary.
    func getSpoilerBoundedChunks(bookId: String, targetChapterOrder: Int) async throws -> [Chunk]
}

/// Thread-safe in-memory repository pre-seeded with *A Study in Scarlet* (Chapters 1–7 verbatim)
/// and *The Sign of the Four* (Chapters 1–4).
public actor InMemorySeededBookRepository: BookRepositoryProtocol {
    private var books: [Book] = []
    private var chapters: [Chapter] = []
    private var chunks: [Chunk] = []
    private var isPopulated: Bool = false

    /// Creates a new `InMemorySeededBookRepository`.
    public init() {}

    /// Populates the in-memory store with *A Study in Scarlet* and *The Sign of the Four* if not yet populated.
    public func ensureSampleDataPopulated() async throws {
        guard !isPopulated, books.isEmpty else {
            return
        }

        let studyInScarlet = Book(
            id: "study_in_scarlet",
            universeId: "sherlock_holmes",
            bookOrder: 1,
            title: "A Study in Scarlet",
            author: "Sir Arthur Conan Doyle",
            totalChapters: 14
        )

        let signOfTheFour = Book(
            id: "sign_of_the_four",
            universeId: "sherlock_holmes",
            bookOrder: 2,
            title: "The Sign of the Four",
            author: "Sir Arthur Conan Doyle",
            totalChapters: 12
        )

        books = [studyInScarlet, signOfTheFour]

        let scarletSampleChapters: [(Int, String, String)] = [
            (
                1,
                "Mr. Sherlock Holmes",
                "In 1878 I took my degree of Doctor of Medicine at the University of London... There I met Stamford and learned of Sherlock Holmes searching for a companion to share rooms at 221B Baker Street."
            ),
            (
                2,
                "The Science of Deduction",
                "Sherlock Holmes was a man who performed strange chemical experiments and possessed exact knowledge of crime history. He explained his deduction methods from a magazine article."
            ),
            (
                3,
                "The Lauriston Garden Mystery",
                "A telegram arrives from Inspector Tobias Gregson regarding a murder at 3 Lauriston Gardens near Brixton Road. The dead man is identified as Enoch J. Drebber of Cleveland, Ohio. The word 'RACHE' is written in blood on the wall."
            ),
            (
                4,
                "What John Rance Had to Tell",
                "Constable John Rance recalls seeing a drunk man lurking outside Lauriston Gardens near the crime scene. Holmes deduces the drunk man was actually the murderer returning for the ring."
            ),
            (
                5,
                "Our Advertisement Brings a Visitor",
                "Holmes places an advertisement in the newspaper offering a lost gold wedding ring found in Brixton Road. An old woman named Mrs. Sawyer arrives at 221B Baker Street to claim it."
            ),
            (
                6,
                "Tobias Gregson Shows What He Can Do",
                "Inspector Gregson arrests Arthur Charpentier, son of the boarding-house keeper where Drebber stayed, believing he committed the crime due to a quarrel."
            ),
            (
                7,
                "Light in the Darkness",
                "Inspector Lestrade arrives with shocking news: Joseph Stangerson, secretary to Enoch Drebber, has also been murdered at Halliday's Private Hotel!"
            )
        ]

        var seededChapters: [Chapter] = []
        var seededChunks: [Chunk] = []

        for (chNum, title, summary) in scarletSampleChapters {
            let paddedNum = String(format: "%02d", chNum)
            let chapterId = "study_in_scarlet_ch\(paddedNum)"
            let chunkId = "chunk_study_in_scarlet_ch\(paddedNum)_001"

            seededChapters.append(
                Chapter(
                    id: chapterId,
                    bookId: "study_in_scarlet",
                    chapterOrder: chNum,
                    title: title
                )
            )

            seededChunks.append(
                Chunk(
                    id: chunkId,
                    bookId: "study_in_scarlet",
                    bookOrder: 1,
                    chapterId: chapterId,
                    chapterOrder: chNum,
                    chunkIndex: 1,
                    content: "Summary of Chapter \(chNum) (\(title)): \(summary)"
                )
            )
        }

        let signSampleChapters: [(Int, String, String)] = [
            (
                1,
                "The Science of Deduction",
                "Sherlock Holmes demonstrates his deductive skill by analyzing Dr. Watson's brother's pocket watch at 221B Baker Street while awaiting a new case."
            ),
            (
                2,
                "The Statement of the Case",
                "Miss Mary Morstan visits 221B Baker Street and recounts the mysterious disappearance of her father, Captain Arthur Morstan, and the annual arrival of six lustrous pearls."
            ),
            (
                3,
                "In Quest of a Solution",
                "Holmes, Watson, and Miss Morstan travel through fog-shrouded London to the Lyceum Theatre and meet Thaddeus Sholto at his exotic house."
            ),
            (
                4,
                "The Story of the Bald-Headed Man",
                "At Pondicherry Lodge, Bartholomew Sholto is found dead inside a locked garret room with a poisoned thorn above his ear and a paper bearing 'The Sign of the Four', along with footprints of a wooden-legged man."
            )
        ]

        for (chNum, title, summary) in signSampleChapters {
            let paddedNum = String(format: "%02d", chNum)
            let chapterId = "sign_of_the_four_ch\(paddedNum)"
            let chunkId = "chunk_sign_of_the_four_ch\(paddedNum)_001"

            seededChapters.append(
                Chapter(
                    id: chapterId,
                    bookId: "sign_of_the_four",
                    chapterOrder: chNum,
                    title: title
                )
            )

            seededChunks.append(
                Chunk(
                    id: chunkId,
                    bookId: "sign_of_the_four",
                    bookOrder: 2,
                    chapterId: chapterId,
                    chapterOrder: chNum,
                    chunkIndex: 1,
                    content: "Summary of Chapter \(chNum) (\(title)): \(summary)"
                )
            )
        }

        chapters = seededChapters
        chunks = seededChunks
        isPopulated = true
    }

    /// Returns all seeded books sorted by `bookOrder` ascending.
    public func getBooks() async throws -> [Book] {
        if !isPopulated {
            try await ensureSampleDataPopulated()
        }
        return books.sorted { $0.bookOrder < $1.bookOrder }
    }

    /// Returns all chapters for `bookId` sorted by `chapterOrder` ascending.
    public func getChapters(bookId: String) async throws -> [Chapter] {
        if !isPopulated {
            try await ensureSampleDataPopulated()
        }
        return chapters
            .filter { $0.bookId == bookId }
            .sorted { $0.chapterOrder < $1.chapterOrder }
    }

    /// Returns only chunks matching `bookId` with `chapterOrder <= targetChapterOrder`, sorted ascending.
    public func getSpoilerBoundedChunks(bookId: String, targetChapterOrder: Int) async throws -> [Chunk] {
        if !isPopulated {
            try await ensureSampleDataPopulated()
        }
        return chunks
            .filter { $0.bookId == bookId && $0.chapterOrder <= targetChapterOrder }
            .sorted {
                if $0.chapterOrder == $1.chapterOrder {
                    return $0.chunkIndex < $1.chunkIndex
                }
                return $0.chapterOrder < $1.chapterOrder
            }
    }
}

/// Alias preserving compatibility with both PRD and ADR naming conventions.
public typealias SeededBookRepository = InMemorySeededBookRepository
