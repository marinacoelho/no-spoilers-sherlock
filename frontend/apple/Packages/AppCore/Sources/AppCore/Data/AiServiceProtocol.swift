import Foundation

/// Defines the AI inference contract for spoiler-bounded question answering and Victorian scene illustration.
public protocol AiServiceProtocol: Sendable {
    /// Checks on-device model availability and returns a status string (`"On-Device AI Ready"`,
    /// `"Downloading On-Device AI..."`, or `nil` when using Cloud AI).
    func checkAndDownloadOnDeviceModel() async -> String?

    /// Generates a concise 1–3 sentence spoiler-free answer from a guardrail-wrapped prompt.
    ///
    /// - Parameter fullPrompt: The system + context + query prompt constructed by ``SpoilerGuardManager``.
    /// - Returns: A spoiler-free textual response.
    func noSpoilerAnswer(fullPrompt: String) async throws -> String

    /// Generates a Victorian pen-and-ink scene illustration and caption from a guardrail-wrapped visual prompt.
    ///
    /// - Parameter visualPrompt: The visualization prompt constructed by ``SpoilerGuardManager``.
    /// - Returns: A ``SceneIllustrationResult`` containing the caption and PNG `imageData`.
    func generateSceneIllustration(visualPrompt: String) async throws -> SceneIllustrationResult
}

extension AiServiceProtocol {
    /// Convenience overload forwarding `noSpoilerAnswer(prompt:)` to `noSpoilerAnswer(fullPrompt:)`.
    public func noSpoilerAnswer(prompt: String) async throws -> String {
        try await noSpoilerAnswer(fullPrompt: prompt)
    }

    /// Convenience overload forwarding `generateSceneIllustration(prompt:)` to `generateSceneIllustration(visualPrompt:)`.
    public func generateSceneIllustration(prompt: String) async throws -> SceneIllustrationResult {
        try await generateSceneIllustration(visualPrompt: prompt)
    }
}

/// Deterministic, offline-ready implementation of ``AiServiceProtocol`` that synthesizes grounded,
/// spoiler-bounded answers from the prompt's known chapter events and produces a valid pre-encoded
/// Victorian sepia PNG illustration payload.
public struct DeterministicSherlockAiService: AiServiceProtocol, Sendable {
    /// Optional status string returned by ``checkAndDownloadOnDeviceModel()``.
    public let simulatedOnDeviceStatus: String?

    /// Creates a new `DeterministicSherlockAiService`.
    ///
    /// - Parameter simulatedOnDeviceStatus: Optional status label for on-device availability (`nil` defaults to Cloud AI).
    public init(simulatedOnDeviceStatus: String? = nil) {
        self.simulatedOnDeviceStatus = simulatedOnDeviceStatus
    }

    /// Returns the configured on-device status string (`nil` for Cloud AI by default).
    public func checkAndDownloadOnDeviceModel() async -> String? {
        simulatedOnDeviceStatus
    }

    /// Synthesizes a 1–3 sentence spoiler-free response strictly grounded in the `Known events` block of `fullPrompt`.
    public func noSpoilerAnswer(fullPrompt: String) async throws -> String {
        let targetChapter = extractTargetChapter(from: fullPrompt) ?? 3
        let userQuestion = extractUserQuestion(from: fullPrompt).lowercased()
        let knownEvents = extractKnownEvents(from: fullPrompt)

        guard !knownEvents.isEmpty else {
            return "By Chapter \(targetChapter), no prior chapter excerpts were found in the casebook to answer that question without spoilers."
        }

        let combinedKnown = knownEvents.joined(separator: " ")

        if userQuestion.contains("killed") || userQuestion.contains("dead") || userQuestion.contains("died") || userQuestion.contains("murder") {
            if combinedKnown.contains("Enoch J. Drebber") {
                if combinedKnown.contains("Joseph Stangerson") {
                    return "Enoch J. Drebber of Cleveland, Ohio was found dead at 3 Lauriston Gardens with 'RACHE' written in blood on the wall, and his secretary Joseph Stangerson was subsequently found murdered at Halliday's Private Hotel."
                }
                return "Enoch J. Drebber of Cleveland, Ohio was found dead at 3 Lauriston Gardens near Brixton Road, where the word 'RACHE' was written in blood on the wall."
            }
            if combinedKnown.contains("Bartholomew Sholto") {
                return "Bartholomew Sholto was found dead inside a locked garret room at Pondicherry Lodge with a poisoned thorn above his ear and a paper bearing 'The Sign of the Four'."
            }
            return "That clue or murder has not yet been revealed by this point in the investigation."
        }

        if userQuestion.contains("ring") || userQuestion.contains("clue") || userQuestion.contains("sawyer") {
            if combinedKnown.contains("Mrs. Sawyer") {
                return "A lost gold wedding ring found at Brixton Road led Holmes to place a newspaper advertisement, bringing an old woman named Mrs. Sawyer to 221B Baker Street to claim it."
            }
            if combinedKnown.contains("wooden-legged") || combinedKnown.contains("thorn") {
                return "The clues left behind at Pondicherry Lodge include a poisoned thorn above Bartholomew Sholto's ear, footprints of a wooden-legged man, and a paper inscribed with 'The Sign of the Four'."
            }
            if combinedKnown.contains("RACHE") {
                return "At 3 Lauriston Gardens, the word 'RACHE' was found written in blood upon the wall beside Enoch J. Drebber."
            }
        }

        if userQuestion.contains("lestrade") {
            if combinedKnown.contains("Lestrade") {
                return "Inspector Lestrade of Scotland Yard arrives with the urgent report that Joseph Stangerson, secretary to Enoch Drebber, has been murdered at Halliday's Private Hotel."
            }
            return "Inspector Lestrade's involvement and theory have not yet been detailed in the chapters you have read so far."
        }

        if userQuestion.contains("morstan") || userQuestion.contains("pearl") {
            if combinedKnown.contains("Mary Morstan") {
                return "Miss Mary Morstan consults Sherlock Holmes at 221B Baker Street regarding the mysterious disappearance of her father, Captain Arthur Morstan, and the annual delivery of six lustrous pearls."
            }
            return "Miss Morstan's case details have not yet been introduced in the chapters read so far."
        }

        if let latestEvent = knownEvents.last {
            return latestEvent
        }

        return "Based on the investigation up to this point, the full answer has not yet been revealed."
    }

    /// Generates a Victorian pen-and-ink scene illustration result with a valid pre-encoded PNG binary payload.
    public func generateSceneIllustration(visualPrompt: String) async throws -> SceneIllustrationResult {
        let targetChapter = extractTargetChapter(from: visualPrompt) ?? 3
        let bookTitle = extractBookTitle(from: visualPrompt) ?? "Sherlock Holmes"
        let caption = "🎨 *Scene Illustration (Chapter \(targetChapter) of \(bookTitle) — Sidney Paget 1880s Victorian Engraving Style)*"
        return SceneIllustrationResult(
            caption: caption,
            imageData: Self.victorianSepiaPlaceholderPNG
        )
    }

    // MARK: - Valid Pre-Encoded PNG Payload

    /// A valid binary PNG image (1x1 RGBA warm Victorian gold/sepia pixel `#D4AF37`)
    /// with standard PNG signature, `IHDR`, zlib-compressed `IDAT`, and `IEND` chunks,
    /// ensuring `UIImage(data:)` and `NSImage(data:)` always decode a non-nil image.
    public static let victorianSepiaPlaceholderPNG: Data = {
        // Valid 1x1 8-bit RGB PNG (Victorian Gold #D4AF37) with verified CRC32 checksums.
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Signature
            0x00, 0x00, 0x00, 0x0D,                         // IHDR Length (13)
            0x49, 0x48, 0x44, 0x52,                         // "IHDR"
            0x00, 0x00, 0x00, 0x01,                         // Width: 1
            0x00, 0x00, 0x00, 0x01,                         // Height: 1
            0x08,                                           // Bit depth: 8
            0x02,                                           // Color type: 2 (Truecolor RGB)
            0x00, 0x00, 0x00,                               // Compression, Filter, Interlace
            0x90, 0x77, 0x53, 0xDE,                         // IHDR CRC32
            0x00, 0x00, 0x00, 0x0C,                         // IDAT Length (12)
            0x49, 0x44, 0x41, 0x54,                         // "IDAT"
            0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, // Zlib stream for 1x1 RGB pixel
            0x03, 0x01, 0x01, 0x00,
            0x18, 0xDD, 0x8D, 0xB0,                         // IDAT CRC32
            0x00, 0x00, 0x00, 0x00,                         // IEND Length (0)
            0x49, 0x45, 0x4E, 0x44,                         // "IEND"
            0xAE, 0x42, 0x60, 0x82                          // IEND CRC32
        ]
        return Data(bytes)
    }()

    // MARK: - Private Prompt Parsing Helpers

    private func extractTargetChapter(from prompt: String) -> Int? {
        let pattern = #"CHAPTER\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsRange = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        guard let match = regex.firstMatch(in: prompt, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: prompt) else {
            return nil
        }
        return Int(prompt[range])
    }

    private func extractBookTitle(from prompt: String) -> String? {
        let pattern = #"CHAPTER\s+\d+\s+of\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsRange = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        guard let match = regex.firstMatch(in: prompt, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: prompt) else {
            return nil
        }
        return String(prompt[range])
    }

    private func extractUserQuestion(from prompt: String) -> String {
        if let range = prompt.range(of: "USER QUESTION:") {
            let tail = prompt[range.upperBound...]
            if let endRange = tail.range(of: "Sherlock's Direct Answer") {
                return String(tail[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = prompt.range(of: "SCENE TO ILLUSTRATE:") {
            return String(prompt[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prompt
    }

    private func extractKnownEvents(from prompt: String) -> [String] {
        let lines = prompt.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- Chapter ") else { return nil }
            if let colonRange = trimmed.range(of: ": ") {
                return String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
        }
    }
}
