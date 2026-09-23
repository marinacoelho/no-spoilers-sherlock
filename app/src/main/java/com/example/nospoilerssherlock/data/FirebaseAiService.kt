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

@OptIn(PublicPreviewAPI::class)
class FirebaseAiService {
    private val hybridAIModel = Firebase
        .ai(backend = GenerativeBackend.googleAI())
        .generativeModel(
            modelName = "gemini-3.7-flash",
            onDeviceConfig = OnDeviceConfig(
                mode = InferenceMode.PREFER_ON_DEVICE
            )
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
}
