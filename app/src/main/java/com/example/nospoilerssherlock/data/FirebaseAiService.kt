package com.example.nospoilerssherlock.data

import android.util.Log
import com.google.firebase.Firebase

import com.google.firebase.ai.DownloadStatus
import com.google.firebase.ai.GenerativeModel
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.OnDeviceModelStatus
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.PublicPreviewAPI
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch

class FirebaseAiService {

    @OptIn(PublicPreviewAPI::class)
    fun getHybridModel(): GenerativeModel {
        return Firebase.ai(backend = GenerativeBackend.googleAI())
            .generativeModel(
                modelName = "gemini-3.7-flash",
                onDeviceConfig = OnDeviceConfig(
                    mode = InferenceMode.PREFER_ON_DEVICE
                )
            )
    }

    fun getCloudModel(): GenerativeModel {
        return Firebase.ai(backend = GenerativeBackend.googleAI())
            .generativeModel("gemini-3.7-flash")
    }

    /**
     * Checks if the on-device AI model (Gemini Nano) is installed and available.
     * If the model is not installed but downloadable, initiates the download through Firebase AI Logic.
     */
    @OptIn(PublicPreviewAPI::class)
    suspend fun checkAndDownloadOnDeviceModel(
        onStatusChange: ((OnDeviceModelStatus) -> Unit)? = null
    ): OnDeviceModelStatus? {
        return try {
            val model = getHybridModel()
            val onDevice = model.onDeviceExtension ?: return null
            val status = onDevice.checkStatus()
            onStatusChange?.invoke(status)

            if (status == OnDeviceModelStatus.DOWNLOADABLE) {
                // Device supports Gemini Nano and has the option to download it.
                // Initiate download via Firebase AI Logic.
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        onDevice.download().collect { downloadStatus ->
                            when (downloadStatus) {
                                is DownloadStatus.DownloadCompleted -> {
                                    onDevice.warmUp()
                                    onStatusChange?.invoke(OnDeviceModelStatus.AVAILABLE)
                                }
                                else -> Unit
                            }
                        }
                    } catch (t: Throwable) {
                        Log.w("FirebaseAiService", "On-device download error: ${t.message}")
                    }
                }
            }
            status
        } catch (t: Throwable) {
            Log.w("FirebaseAiService", "Unable to check on-device AI status: ${t.message}")
            null
        }
    }

    /**
     * Generates a streaming response using Firebase AI Logic.
     * Tries on-device AI (Gemini Nano) via hybrid model, seamlessly falling back to the cloud-hosted
     * model if on-device model methods fail (e.g. NoSuchMethod or unsupported device),
     * and falls back to context-based extraction only if offline or all AI models fail.
     */
    @OptIn(PublicPreviewAPI::class)
    fun generateContentStream(
        fullPrompt: String,
        extractedChapter: Int,
        fallbackContextText: String
    ): Flow<String> = flow {
        var responseAccumulator = ""
        var generatedFromAi = false

        // 1. First attempt: Try hybrid/on-device AI
        try {
            checkAndDownloadOnDeviceModel()

            @OptIn(PublicPreviewAPI::class)
            val hybridModel = getHybridModel()

            hybridModel.generateContentStream(fullPrompt).collect { chunk ->
                val chunkText = chunk.text
                if (!chunkText.isNullOrEmpty()) {
                    responseAccumulator += chunkText
                    emit(responseAccumulator)
                    generatedFromAi = true
                }
            }
        } catch (t: Throwable) {
            Log.w(
                "FirebaseAiService",
                "On-device/hybrid AI error ($t), falling back to cloud-hosted model."
            )
        }

        // 2. Second attempt: If on-device AI failed or did not emit, fall back to cloud model
        if (!generatedFromAi) {
            try {
                val cloudModel = getCloudModel()
                responseAccumulator = ""
                cloudModel.generateContentStream(fullPrompt).collect { chunk ->
                    val chunkText = chunk.text
                    if (!chunkText.isNullOrEmpty()) {
                        responseAccumulator += chunkText
                        emit(responseAccumulator)
                        generatedFromAi = true
                    }
                }
            } catch (t: Throwable) {
                Log.w("FirebaseAiService", "Cloud AI generation failed: ${t.message}", t)
            }
        }

        // 3. Final fallback: If both AI options failed (e.g. offline and no local model), use zero-spoiler context
        if (!generatedFromAi || responseAccumulator.isEmpty()) {
            emit(generateFallbackAnswer(extractedChapter, fallbackContextText))
        }
    }




    private fun generateFallbackAnswer(chapter: Int, contextText: String): String {
        val latestSummary = contextText.lines().lastOrNull { it.isNotBlank() } ?: "No events recorded."
        return """
            According to the records up to Chapter $chapter:
            
            $latestSummary
            
            *(Operating in offline spoiler-guard mode. Future events past Chapter $chapter remain protected.)*
        """.trimIndent()
    }
}
