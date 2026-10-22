import Foundation

/// Stateless domain engine responsible for chapter extraction, boundary clamping,
/// visualization keyword detection, and spoiler-guardrail prompt synthesis.
public struct SpoilerGuardManager: Sendable {
    /// Initializes a `SpoilerGuardManager` instance.
    public init() {}

    /// Exact list of case-insensitive substring keywords that trigger Victorian scene visualization.
    public static let visualizationKeywords: [String] = [
        "visualize",
        "visualise",
        "illustrate",
        "draw",
        "sketch",
        "picture",
        "show me the scene",
        "generate an image",
        "generate image",
        "scene of",
        "depict",
        "portrait of"
    ]

    /// Extracts an explicit chapter number from a natural-language user prompt.
    ///
    /// Matches patterns such as `"In chapter 5"`, `"ch. 3"`, `"chap 12"`, and `"in the 4th chapter"`,
    /// while strictly rejecting negative chapter numbers (e.g., `"In chapter -3"` returns `nil`).
    /// When multiple chapters are mentioned in the same prompt (e.g., `"Without spoiling chapter 7,
    /// tell me what happened in chapter 2"`), returns the minimum mentioned chapter (`2`) so that
    /// future spoilers are never leaked.
    ///
    /// - Parameter prompt: The raw user query text.
    /// - Returns: The minimum extracted non-negative chapter number (including `0` so callers can
    ///   clamp it to `1`), or `nil` if no explicit non-negative chapter reference is present.
    public static func extractChapterFromPrompt(_ prompt: String) -> Int? {
        // Reject negative chapter references explicitly (e.g., "chapter -3", "-4th chapter").
        let negativePattern = #"(?i)(?:\b(?:chapter|chap|ch\.?)\s*-\s*\d+|-\s*\d+(?:st|nd|rd|th)?\s*chapter\b)"#
        if prompt.range(of: negativePattern, options: .regularExpression) != nil {
            return nil
        }

        let patterns = [
            // Pattern 1: "chapter 5", "ch. 3", "chap 12", "ch 3"
            #"(?i)\b(?:chapter|chap|ch\.?)\s+(\d+)\b"#,
            // Pattern 2: "4th chapter", "1st chapter", "2nd chapter", "3rd chapter"
            #"(?i)(?<!-)\b(\d+)(?:st|nd|rd|th)?\s*chapter\b"#
        ]

        var matchedChapters: [Int] = []
        for pattern in patterns {
            matchedChapters.append(contentsOf: allCapturedInts(in: prompt, pattern: pattern))
        }

        let validChapters = matchedChapters.filter { $0 >= 0 }
        return validChapters.min()
    }

    /// Clamps a chapter number within the valid range `1...max(1, totalChapters)`.
    ///
    /// - Parameters:
    ///   - chapter: The raw or extracted chapter number.
    ///   - totalChapters: Total number of chapters in the active book.
    /// - Returns: A chapter number guaranteed to be within `1...max(1, totalChapters)`.
    public static func clampChapter(_ chapter: Int, totalChapters: Int) -> Int {
        let upperBound = max(1, totalChapters)
        return max(1, min(chapter, upperBound))
    }

    /// Determines whether the user's prompt is requesting a Victorian scene illustration.
    ///
    /// Performs a case-insensitive word-boundary match against ``visualizationKeywords`` while
    /// excluding common non-visual figurative idioms (such as `"big picture"` or `"draw a conclusion"`).
    ///
    /// - Parameter prompt: The user's natural-language prompt.
    /// - Returns: `true` if any visualization keyword is present as a distinct word or phrase; otherwise `false`.
    public static func isVisualizationRequest(_ prompt: String) -> Bool {
        var sanitized = prompt.lowercased()

        // Strip common non-visual figurative English idioms before checking visual keywords.
        let nonVisualIdiomPatterns = [
            #"\b(?:big|bigger|whole|full|overall|clear|mental)\s+picture\b"#,
            #"\bpicture\s+of\s+(?:health|innocence|calm|misery)\b"#,
            #"\bdraw(?:s|ing|n)?\b[^.?!]{0,40}\b(?:conclusion|conclusions|inference|inferences|parallel|parallels|attention|blood|lots)\b"#,
            #"\b(?:conclusion|conclusions|inference|inferences)\b[^.?!]{0,40}\b(?:draw|drawn|draws|drawing)\b"#
        ]

        for idiom in nonVisualIdiomPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: idiom,
                with: " ",
                options: .regularExpression
            )
        }

        return visualizationKeywords.contains { keyword in
            let escaped = NSRegularExpression.escapedPattern(for: keyword.lowercased())
            let boundaryPattern = #"\b\#(escaped)\b"#
            return sanitized.range(of: boundaryPattern, options: .regularExpression) != nil
        }
    }

    /// Builds a strict spoiler-guardrail system prompt for answering a user's question up to `targetChapter`.
    ///
    /// Strips any leading `"Summary of Chapter X (...): "` prefix from each chunk and formats the
    /// allowed excerpts as `"- Chapter X: <cleanContent>"`.
    ///
    /// - Parameters:
    ///   - bookTitle: Title of the active book (e.g., `"A Study in Scarlet"`).
    ///   - targetChapter: The maximum allowed chapter boundary (`1...totalChapters`).
    ///   - userQuery: The user's original question.
    ///   - retrievedChunks: Spoiler-bounded chunks with `chapterOrder <= targetChapter`.
    /// - Returns: The complete multi-line prompt enforcing the `STRICT SPOILER GUARDBOUND`.
    public static func buildSpoilerGuardrailPrompt(
        bookTitle: String,
        targetChapter: Int,
        userQuery: String,
        retrievedChunks: [Chunk]
    ) -> String {
        let formattedExcerpts = formatChunks(retrievedChunks)

        return """
        You are "No Spoilers, Sherlock", a sharp Victorian literary detective assistant helping a reader who is currently on CHAPTER \(targetChapter) of "\(bookTitle)".
        Answer the user's question directly and concisely in 1 to 3 sentences without listing chapters.

        === STRICT SPOILER GUARDBOUND ===
        - Permitted scope: Chapters 1 through \(targetChapter) of "\(bookTitle)" ONLY.
        - ABSOLUTELY DO NOT reveal, hint at, extrapolate, or mention any plot twists, character deaths, murderer identities, or events taking place AFTER Chapter \(targetChapter).
        - If the answer requires events after Chapter \(targetChapter), state that the clue has not yet been revealed by Chapter \(targetChapter).

        Known events (Chapters 1-\(targetChapter)):
        \(formattedExcerpts)

        USER QUESTION: \(userQuery)

        Sherlock's Direct Answer (ZERO SPOILERS beyond Chapter \(targetChapter)! Do not list chapters):
        """
    }

    /// Builds a strict spoiler-bounded Victorian scene visualization prompt in the style of Sidney Paget.
    ///
    /// Strips any leading `"Summary of Chapter X (...): "` prefix from each chunk and instructs the
    /// image generator to produce an 1880s Victorian London pen-and-ink illustration.
    ///
    /// - Parameters:
    ///   - bookTitle: Title of the active book (e.g., `"A Study in Scarlet"`).
    ///   - targetChapter: The maximum allowed chapter boundary (`1...totalChapters`).
    ///   - userQuery: The user's visualization query.
    ///   - retrievedChunks: Spoiler-bounded chunks with `chapterOrder <= targetChapter`.
    /// - Returns: The complete multi-line prompt for Victorian scene illustration.
    public static func buildSceneVisualizationPrompt(
        bookTitle: String,
        targetChapter: Int,
        userQuery: String,
        retrievedChunks: [Chunk]
    ) -> String {
        let formattedExcerpts = formatChunks(retrievedChunks)

        return """
        Generate an atmospheric, historical period illustration in the style of classic Victorian 19th-century pen-and-ink engraving and etching, reminiscent of Sidney Paget's original illustrations for Sherlock Holmes in The Strand Magazine.

        === STRICT SPOILER GUARDBOUND ===
        - Depict ONLY scenes, characters, and clues known up to CHAPTER \(targetChapter) of "\(bookTitle)".
        - ABSOLUTELY DO NOT depict any murderer identity, hidden culprit, future clue, or plot twist occurring after Chapter \(targetChapter).
        - Period accuracy: 1880s Victorian London (gas lamps, cobblestones, London pea-soup fog, authentic period clothing and architecture).

        Known events (Chapters 1-\(targetChapter)):
        \(formattedExcerpts)

        SCENE TO ILLUSTRATE: \(userQuery)
        """
    }

    // MARK: - Private Helpers

    private static func formatChunks(_ chunks: [Chunk]) -> String {
        guard !chunks.isEmpty else {
            return "No prior chapter excerpts found."
        }

        let sortedChunks = chunks.sorted { $0.chapterOrder < $1.chapterOrder }
        return sortedChunks.map { chunk in
            let cleanContent = stripSummaryPrefix(from: chunk.content)
            return "- Chapter \(chunk.chapterOrder): \(cleanContent)"
        }.joined(separator: "\n")
    }

    private static func stripSummaryPrefix(from text: String) -> String {
        let prefixPattern = #"^Summary of Chapter \d+ \([^)]+\):\s*"#
        guard let range = text.range(of: prefixPattern, options: .regularExpression) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func allCapturedInts(in text: String, pattern: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            let rawDigits = String(text[captureRange])
            guard !rawDigits.isEmpty, rawDigits.allSatisfy(\.isWholeNumber) else {
                return nil
            }
            // Saturate huge positive digit sequences to Int.max so clampChapter clamps to totalChapters.
            return Int(rawDigits) ?? Int.max
        }
    }
}
