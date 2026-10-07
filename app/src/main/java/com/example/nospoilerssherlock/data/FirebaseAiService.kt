package com.example.nospoilerssherlock.data

import android.util.Log
import com.google.firebase.Firebase

import com.google.firebase.ai.DownloadStatus
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.OnDeviceModelStatus
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.PublicPreviewAPI
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.firebase.ai.type.InlineDataPart
import com.google.firebase.ai.type.ResponseModality
import com.google.firebase.ai.type.asImageOrNull
import com.google.firebase.ai.type.generationConfig

@OptIn(PublicPreviewAPI::class)
class FirebaseAiService {
    private val hybridAIModel = Firebase
        .ai(backend = GenerativeBackend.googleAI())
        .generativeModel(
            modelName = "gemini-3.7-flash",
            onDeviceConfig = OnDeviceConfig(
                mode = InferenceMode.PREFER_IN_CLOUD
            )
        )

    /**
     * Nano Banana image generation model accessed via Gemini Developer API through Firebase AI Logic.
     */
    private val nanoBananaModel = Firebase
        .ai(backend = GenerativeBackend.googleAI())
        .generativeModel(
            modelName = "gemini-3.1-flash-image",
            generationConfig = generationConfig {
                responseModalities = listOf(
                    ResponseModality.TEXT,
                    ResponseModality.IMAGE
                )
            }
        )

    suspend fun checkAndDownloadOnDeviceModel(
        onStatusChange: ((OnDeviceModelStatus) -> Unit)? = null
    ) {
        when (hybridAIModel.onDeviceExtension?.checkStatus()) {
            OnDeviceModelStatus.DOWNLOADABLE -> {
                hybridAIModel.onDeviceExtension?.download()?.collect { status ->
                    when (status) {
                        is DownloadStatus.DownloadInProgress -> {
                            onStatusChange?.invoke(OnDeviceModelStatus.DOWNLOADING)
                        }
                        is DownloadStatus.DownloadCompleted -> {
                            onStatusChange?.invoke(OnDeviceModelStatus.AVAILABLE)
                        }
                        else -> Unit
                    }
                }
            }
            OnDeviceModelStatus.AVAILABLE -> {
                onStatusChange?.invoke(OnDeviceModelStatus.AVAILABLE)
            }
            else -> Unit
        }
    }

    suspend fun noSpoilerAnswer(fullPrompt: String): String {
        val response = hybridAIModel.generateContent(fullPrompt)
        return response.text.orEmpty()
    }

    fun generateContentStream(fullPrompt: String): Flow<String> = flow {
        var responseAccumulator = ""

        try {
            hybridAIModel.generateContentStream(fullPrompt).collect { chunk ->
                val chunkText = chunk.text
                if (!chunkText.isNullOrEmpty()) {
                    responseAccumulator += chunkText
                    emit(responseAccumulator)
                }
            }
        } catch (t: Throwable) {
            Log.w(
                "FirebaseAiService",
                "On-device/hybrid AI error ($t)"
            )
        }
    }

    /**
     * Generates a period scene illustration using Nano Banana via Firebase AI Logic.
     * Extracts returned InlineDataPart image bytes and decodes into a Bitmap.
     */
    suspend fun generateSceneIllustration(visualPrompt: String): Pair<String, Bitmap?> {
        return try {
            val response = nanoBananaModel.generateContent(visualPrompt)
            val caption = response.text.orEmpty()
            var bitmap: Bitmap? = null

            Log.d("FirebaseAiService", "Nano Banana response received with ${response.candidates.size} candidates")
            for (candidate in response.candidates) {
                Log.d("FirebaseAiService", "Candidate parts: ${candidate.content.parts.map { it::class.java.simpleName }}")
                for (part in candidate.content.parts) {
                    val candidateImage = part.asImageOrNull()
                    if (candidateImage != null) {
                        bitmap = candidateImage
                        Log.d("FirebaseAiService", "Extracted ImagePart Bitmap: ${bitmap.width}x${bitmap.height}")
                        break
                    } else if (part is InlineDataPart) {
                        bitmap = BitmapFactory.decodeByteArray(part.inlineData, 0, part.inlineData.size)
                        Log.d("FirebaseAiService", "Decoded InlineData Bitmap: ${bitmap?.width}x${bitmap?.height}")
                        break
                    }
                }
                if (bitmap != null) break
            }
            Pair(caption, bitmap)
        } catch (e: Exception) {
            Log.e("FirebaseAiService", "Nano Banana image generation error", e)
            Pair("Sherlock attempted to illustrate this scene, but encountered an error: ${e.localizedMessage ?: "Unknown error"}", null)
        }
    }
}
