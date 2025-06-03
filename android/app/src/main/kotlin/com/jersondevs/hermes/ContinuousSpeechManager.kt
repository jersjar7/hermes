// android/app/src/main/kotlin/com/yourapp/hermes/ContinuousSpeechManager.kt

package com.jersondevs.hermes

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.EventChannel
import java.util.*

class ContinuousSpeechManager(
    private val context: Context,
    private val activity: Activity,
    private val eventChannel: EventChannel
) : RecognitionListener {
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isListening = false
    private var shouldContinue = false
    private var currentLocale = "en-US"
    private var partialResults = true
    
    // Smart restart logic
    private val handler = Handler(Looper.getMainLooper())
    private var restartRunnable: Runnable? = null
    private var lastResultTime = 0L
    private var currentSessionResults = mutableListOf<String>()
    
    // Audio management
    private var audioManager: AudioManager? = null
    private var originalAudioMode: Int = AudioManager.MODE_NORMAL
    
    // Timing constants for optimized experience
    private companion object {
        const val TAG = "ContinuousSpeech-Android"
        const val RESTART_DELAY_MS = 50L  // Much faster restart than plugin's 500ms
        const val SILENCE_TIMEOUT_MS = 2000L  // 2 seconds of silence before restart
        const val MAX_SESSION_DURATION_MS = 30000L  // 30 seconds max per session
        const val MIN_RESULT_LENGTH = 2  // Minimum characters to consider valid
    }
    
    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        setupEventChannel()
    }
    
    private fun setupEventChannel() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                android.util.Log.d(TAG, "Event channel connected")
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
                android.util.Log.d(TAG, "Event channel disconnected")
            }
        })
    }
    
    fun isAvailable(): Boolean {
        return SpeechRecognizer.isRecognitionAvailable(context)
    }
    
    fun initialize(): Boolean {
        return try {
            if (isAvailable()) {
                android.util.Log.d(TAG, "✅ Android SpeechRecognizer available - using optimized restart logic")
                true
            } else {
                android.util.Log.w(TAG, "❌ Android SpeechRecognizer not available on this device")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error during initialization", e)
            false
        }
    }
    
    fun startContinuousRecognition(locale: String, partialResults: Boolean): Boolean {
        return try {
            if (isListening) {
                android.util.Log.w(TAG, "Already listening, ignoring start request")
                return true
            }
            
            currentLocale = locale
            this.partialResults = partialResults
            shouldContinue = true
            currentSessionResults.clear()
            
            android.util.Log.d(TAG, "🚀 Starting optimized Android recognition with locale: $locale")
            
            setupAudioFocus()
            startRecognitionSession()
            
            sendStatusEvent("started")
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error starting continuous recognition", e)
            sendErrorEvent("Failed to start recognition: ${e.message}")
            false
        }
    }
    
    fun stopContinuousRecognition() {
        android.util.Log.d(TAG, "🛑 Stopping continuous recognition")
        
        shouldContinue = false
        isListening = false
        
        // Cancel pending restarts
        restartRunnable?.let { handler.removeCallbacks(it) }
        restartRunnable = null
        
        // Stop current recognition
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
        
        // Restore audio focus
        restoreAudioFocus()
        
        sendStatusEvent("stopped")
        android.util.Log.d(TAG, "✅ Continuous recognition stopped")
    }
    
    private fun startRecognitionSession() {
        if (!shouldContinue) return
        
        try {
            // Clean up previous recognizer
            speechRecognizer?.destroy()
            
            // Create new recognizer
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer?.setRecognitionListener(this)
            
            // Prepare intent
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, currentLocale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                
                // Android-specific optimizations
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, SILENCE_TIMEOUT_MS)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000L)
            }
            
            isListening = true
            lastResultTime = System.currentTimeMillis()
            
            speechRecognizer?.startListening(intent)
            android.util.Log.d(TAG, "📱 Started new recognition session")
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error starting recognition session", e)
            scheduleRestart("Session start error: ${e.message}")
        }
    }
    
    private fun scheduleRestart(reason: String = "Automatic restart") {
        if (!shouldContinue) return
        
        android.util.Log.d(TAG, "🔄 Scheduling restart: $reason")
        
        restartRunnable?.let { handler.removeCallbacks(it) }
        restartRunnable = Runnable {
            if (shouldContinue) {
                android.util.Log.d(TAG, "🔄 Restarting recognition session")
                startRecognitionSession()
            }
        }
        
        handler.postDelayed(restartRunnable!!, RESTART_DELAY_MS)
    }
    
    private fun setupAudioFocus() {
        audioManager?.let { am ->
            originalAudioMode = am.mode
            am.mode = AudioManager.MODE_IN_COMMUNICATION
        }
    }
    
    private fun restoreAudioFocus() {
        audioManager?.mode = originalAudioMode
    }
    
    // MARK: - RecognitionListener Implementation
    
    override fun onReadyForSpeech(params: Bundle?) {
        android.util.Log.d(TAG, "🎤 Ready for speech")
        sendStatusEvent("listening")
    }
    
    override fun onBeginningOfSpeech() {
        android.util.Log.d(TAG, "🗣️ Beginning of speech detected")
        lastResultTime = System.currentTimeMillis()
    }
    
    override fun onRmsChanged(rmsdB: Float) {
        // Audio level changed - could use for voice activity detection
    }
    
    override fun onBufferReceived(buffer: ByteArray?) {
        // Audio buffer received
    }
    
    override fun onEndOfSpeech() {
        android.util.Log.d(TAG, "🔇 End of speech detected")
        isListening = false
    }
    
    override fun onError(error: Int) {
        isListening = false
        
        val errorMessage = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error: $error"
        }
        
        android.util.Log.w(TAG, "⚠️ Recognition error: $errorMessage")
        
        // Handle different error types
        when (error) {
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                // These are normal - just restart
                scheduleRestart("No speech detected")
            }
            
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                // Service busy - wait a bit longer
                restartRunnable?.let { handler.removeCallbacks(it) }
                handler.postDelayed({
                    if (shouldContinue) startRecognitionSession()
                }, 200L)
            }
            
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> {
                // Network issues - inform user but continue trying
                sendErrorEvent("Network connectivity issue, retrying...")
                scheduleRestart("Network error recovery")
            }
            
            else -> {
                // More serious errors - inform user and restart
                sendErrorEvent(errorMessage)
                scheduleRestart("Error recovery")
            }
        }
    }
    
    override fun onResults(results: Bundle?) {
        isListening = false
        
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val transcript = matches[0].trim()
            
            if (transcript.length >= MIN_RESULT_LENGTH) {
                android.util.Log.d(TAG, "📝 Final result: \"$transcript\"")
                
                sendResultEvent(transcript, isFinal = true, confidence = 0.9)
                currentSessionResults.add(transcript)
                lastResultTime = System.currentTimeMillis()
            }
        }
        
        // Always restart for continuous recognition
        scheduleRestart("Session completed")
    }
    
    override fun onPartialResults(partialResults: Bundle?) {
        if (!this.partialResults) return
        
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val transcript = matches[0].trim()
            
            if (transcript.length >= MIN_RESULT_LENGTH) {
                android.util.Log.d(TAG, "📝 Partial result: \"$transcript\"")
                sendResultEvent(transcript, isFinal = false, confidence = 0.7)
                lastResultTime = System.currentTimeMillis()
            }
        }
    }
    
    override fun onEvent(eventType: Int, params: Bundle?) {
        // Additional recognition events
    }
    
    // MARK: - Event Sending
    
    private fun sendResultEvent(transcript: String, isFinal: Boolean, confidence: Double) {
        val event = mapOf(
            "type" to "result",
            "transcript" to transcript,
            "isFinal" to isFinal,
            "confidence" to confidence,
            "locale" to currentLocale
        )
        
        activity.runOnUiThread {
            eventSink?.success(event)
        }
    }
    
    private fun sendErrorEvent(message: String) {
        val event = mapOf(
            "type" to "error",
            "message" to message
        )
        
        activity.runOnUiThread {
            eventSink?.success(event)
        }
    }
    
    private fun sendStatusEvent(status: String) {
        val event = mapOf(
            "type" to "status",
            "status" to status
        )
        
        activity.runOnUiThread {
            eventSink?.success(event)
        }
    }
    
    fun cleanup() {
        android.util.Log.d(TAG, "🧹 Cleaning up speech manager")
        stopContinuousRecognition()
    }
}