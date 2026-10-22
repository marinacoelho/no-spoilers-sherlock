import Foundation
import AppCore
import FirebaseCore
import FirebaseAI

/// A live Firebase AI Logic implementation of `AiServiceProtocol` using Gemini (`gemini-2.5-flash` / `gemini-3.1-flash-image`)
/// with automatic hybrid/offline fallback to `DeterministicSherlockAiService`.
public actor FirebaseSherlockAIService: AiServiceProtocol {
    private let fallbackService = DeterministicSherlockAiService()

    public init() {}

    public func checkAndDownloadOnDeviceModel() async -> String? {
        guard FirebaseApp.app() != nil else {
            return await fallbackService.checkAndDownloadOnDeviceModel()
        }

        let isSystemModelAvailable = FirebaseAI.SystemLanguageModel.default.isAvailable
        if isSystemModelAvailable {
            return "On-Device AI Ready"
        } else {
            return nil
        }
    }

    public func noSpoilerAnswer(fullPrompt: String) async throws -> String {
        guard FirebaseApp.app() != nil else {
            return try await fallbackService.noSpoilerAnswer(fullPrompt: fullPrompt)
        }

        let textBackendOptions: [Bool] = [false, true]
        for useLimitedUseTokens in textBackendOptions {
            do {
                let ai = FirebaseAI.firebaseAI(
                    backend: .googleAI(),
                    useLimitedUseAppCheckTokens: useLimitedUseTokens
                )
                let model = ai.generativeModel(modelName: "gemini-2.5-flash")
                let response = try await model.generateContent(fullPrompt)
                if let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    return text
                }
            } catch {
                continue
            }
        }

        return try await fallbackService.noSpoilerAnswer(fullPrompt: fullPrompt)
    }

    public func generateSceneIllustration(
        visualPrompt: String
    ) async throws -> SceneIllustrationResult {
        guard FirebaseApp.app() != nil else {
            return try await fallbackService.generateSceneIllustration(visualPrompt: visualPrompt)
        }

        let candidateModelNames = [
            "gemini-3.1-flash-image",
            "gemini-2.5-flash-image"
        ]

        let config = GenerationConfig(responseModalities: [.text, .image])
        let tokenOptions: [Bool] = [false, true]

        for modelName in candidateModelNames {
            for useLimitedUseTokens in tokenOptions {
                do {
                    let ai = FirebaseAI.firebaseAI(
                        backend: .googleAI(),
                        useLimitedUseAppCheckTokens: useLimitedUseTokens
                    )
                    let imageModel = ai.generativeModel(
                        modelName: modelName,
                        generationConfig: config
                    )
                    let response = try await imageModel.generateContent(visualPrompt)
                    let caption = response.text ?? ""
                    if let firstImagePart = response.inlineDataParts.first(where: { $0.mimeType.starts(with: "image/") })
                        ?? response.inlineDataParts.first {
                        return SceneIllustrationResult(
                            caption: caption,
                            imageData: firstImagePart.data
                        )
                    }
                } catch {
                    continue
                }
            }
        }

        return try await fallbackService.generateSceneIllustration(visualPrompt: visualPrompt)
    }
}
