// android/app/src/main/kotlin/com/jersondevs/hermes/ContinuousSpeechManager.kt

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
    private var consecutiveErrors = 0
    private var sessionStartTime = 0L
    
    // Audio management
    private var audioManager: AudioManager? = null
    
    // Timing constants optimized for stability
    private companion object {
        const val TAG = "ContinuousSpeech-Android"
        const val RESTART_DELAY_MS = 300L  // Increased from 50ms for stability
        const val ERROR_BACKOFF_BASE_MS = 1000L  // Base delay for errors
        const val MAX_CONSECUTIVE_ERRORS = 5  // Stop after too many errors
        const val SILENCE_TIMEOUT_MS = 3000L  // 3 seconds of silence
        const val MAX_SESSION_DURATION_MS = 45000L  // 45 seconds max per session
        const val MIN_RESULT_LENGTH = 1  // Minimum characters to consider valid
        const val SUCCESS_RESET_ERRORS_DELAY = 5000L  // Reset error count after 5s success
    }
    
    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        setupEventChannel()
        android.util.Log.d(TAG, "ContinuousSpeechManager initialized")
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
        val available = SpeechRecognizer.isRecognitionAvailable(context)
        android.util.Log.d(TAG, "SpeechRecognizer availability: $available")
        return available
    }
    
    fun initialize(): Boolean {
        return try {
            if (isAvailable()) {
                android.util.Log.d(TAG, "✅ Android SpeechRecognizer initialized successfully")
                true
            } else {
                android.util.Log.e(TAG, "❌ SpeechRecognizer not available on this device")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error during initialization", e)
            false
        }
    }
    
    fun startContinuousRecognition(locale: String, partialResults: Boolean): Boolean {
        return try {
            if (isListening) {
                android.util.Log.w(TAG, "Already listening, stopping first...")
                stopContinuousRecognition()
                // Give it a moment to stop
                Thread.sleep(200)
            }
            
            currentLocale = locale
            this.partialResults = partialResults
            shouldContinue = true
            consecutiveErrors = 0
            sessionStartTime = System.currentTimeMillis()
            
            android.util.Log.d(TAG, "🚀 Starting continuous Android recognition")
            android.util.Log.d(TAG, "📍 Locale: $locale, Partial: $partialResults")
            
            startRecognitionSession()
            sendStatusEvent("started")
            
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error starting continuous recognition", e)
            sendErrorEvent("Failed to start recognition: ${e.message}")
            false
        }
    }
    
    fun stopContinuousRecognition() {
        android.util.Log.d(TAG, "🛑 Stopping continuous recognition")
        
        shouldContinue = false
        isListening = false
        
        // Cancel pending restarts
        restartRunnable?.let { 
            handler.removeCallbacks(it)
            android.util.Log.d(TAG, "Cancelled pending restart")
        }
        restartRunnable = null
        
        // Stop current recognition
        speechRecognizer?.let { recognizer ->
            try {
                recognizer.stopListening()
                recognizer.destroy()
                android.util.Log.d(TAG, "Speech recognizer stopped and destroyed")
            } catch (e: Exception) {
                android.util.Log.w(TAG, "Error stopping recognizer: ${e.message}")
            }
        }
        speechRecognizer = null
        
        sendStatusEvent("stopped")
        android.util.Log.d(TAG, "✅ Continuous recognition stopped")
    }
    
    private fun startRecognitionSession() {
        if (!shouldContinue) {
            android.util.Log.d(TAG, "Should not continue, aborting session start")
            return
        }
        
        try {
            // Clean up previous recognizer
            speechRecognizer?.let { oldRecognizer ->
                try {
                    oldRecognizer.destroy()
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Error destroying old recognizer: ${e.message}")
                }
            }
            
            // Create new recognizer
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            
            if (speechRecognizer == null) {
                android.util.Log.e(TAG, "❌ Failed to create SpeechRecognizer")
                handleRecognitionError("Failed to create SpeechRecognizer")
                return
            }
            
            speechRecognizer?.setRecognitionListener(this)
            
            // Prepare intent with optimized settings
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, currentLocale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                
                // Optimized timing for continuous recognition
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, SILENCE_TIMEOUT_MS)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1500L)
                
                // Prefer on-device recognition for better performance
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            
            isListening = true
            lastResultTime = System.currentTimeMillis()
            
            speechRecognizer?.startListening(intent)
            android.util.Log.d(TAG, "📱 Started new recognition session with locale: $currentLocale")
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error starting recognition session", e)
            handleRecognitionError("Session start error: ${e.message}")
        }
    }
    
    private fun scheduleRestart(reason: String = "Automatic restart", delayMs: Long = RESTART_DELAY_MS) {
        if (!shouldContinue) {
            android.util.Log.d(TAG, "Should not continue, skipping restart")
            return
        }
        
        android.util.Log.d(TAG, "🔄 Scheduling restart in ${delayMs}ms: $reason")
        
        restartRunnable?.let { handler.removeCallbacks(it) }
        restartRunnable = Runnable {
            if (shouldContinue && !isListening) {
                android.util.Log.d(TAG, "🔄 Executing restart: $reason")
                startRecognitionSession()
            } else {
                android.util.Log.d(TAG, "Skipping restart - shouldContinue: $shouldContinue, isListening: $isListening")
            }
        }
        
        handler.postDelayed(restartRunnable!!, delayMs)
    }
    
    private fun handleRecognitionError(message: String) {
        consecutiveErrors++
        android.util.Log.w(TAG, "⚠️ Recognition error #$consecutiveErrors: $message")
        
        if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
            android.util.Log.e(TAG, "❌ Too many consecutive errors ($consecutiveErrors), stopping")
            sendErrorEvent("Speech recognition failed after multiple attempts")
            stopContinuousRecognition()
            return
        }
        
        // Exponential backoff for errors
        val backoffDelay = ERROR_BACKOFF_BASE_MS * consecutiveErrors
        scheduleRestart("Error recovery", backoffDelay)
    }
    
    private fun resetErrorCount() {
        if (consecutiveErrors > 0) {
            android.util.Log.d(TAG, "✅ Resetting error count (was $consecutiveErrors)")
            consecutiveErrors = 0
        }
    }
    
    // MARK: - RecognitionListener Implementation
    
    override fun onReadyForSpeech(params: Bundle?) {
        android.util.Log.d(TAG, "🎤 Ready for speech")
        sendStatusEvent("listening")
        resetErrorCount() // Reset on successful start
    }
    
    override fun onBeginningOfSpeech() {
        android.util.Log.d(TAG, "🗣️ Beginning of speech detected")
        lastResultTime = System.currentTimeMillis()
        resetErrorCount() // Reset when speech detected
    }
    
    override fun onRmsChanged(rmsdB: Float) {
        // Audio level monitoring - could be used for voice activity detection
        // android.util.Log.v(TAG, "Audio level: $rmsdB dB")
    }
    
    override fun onBufferReceived(buffer: ByteArray?) {
        // Audio buffer received - not used currently
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
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input detected"
            else -> "Unknown error: $error"
        }
        
        android.util.Log.w(TAG, "🔴 Recognition error: $errorMessage (code: $error)")
        
        // Handle different error types
        when (error) {
            SpeechRecognizer.ERROR_NO_MATCH -> {
                // Very common, don't count as serious error
                android.util.Log.d(TAG, "No match - continuing with quick restart")
                scheduleRestart("No match detected", RESTART_DELAY_MS)
            }
            
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                // Also common, quick restart
                android.util.Log.d(TAG, "Speech timeout - continuing with quick restart")
                scheduleRestart("Speech timeout", RESTART_DELAY_MS)
            }
            
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                // Service busy - wait longer
                android.util.Log.w(TAG, "Recognizer busy - waiting longer")
                scheduleRestart("Recognizer busy", ERROR_BACKOFF_BASE_MS)
            }
            
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> {
                // Network issues - inform user but continue trying
                sendErrorEvent("Network connectivity issue, retrying...")
                handleRecognitionError(errorMessage)
            }
            
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                // Serious error - stop completely
                android.util.Log.e(TAG, "❌ Insufficient permissions - stopping")
                sendErrorEvent("Microphone permission required")
                stopContinuousRecognition()
            }
            
            else -> {
                // Other errors - use backoff strategy
                handleRecognitionError(errorMessage)
            }
        }
    }
    
    override fun onResults(results: Bundle?) {
        isListening = false
        
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val confidences = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        
        if (!matches.isNullOrEmpty()) {
            val transcript = matches[0].trim()
            val confidence = confidences?.getOrNull(0)?.toDouble() ?: 0.9
            
            if (transcript.length >= MIN_RESULT_LENGTH) {
                android.util.Log.d(TAG, "📝 Final result: \"$transcript\" (confidence: $confidence)")
                
                sendResultEvent(transcript, isFinal = true, confidence = confidence)
                lastResultTime = System.currentTimeMillis()
                resetErrorCount() // Reset on successful result
                
                // Schedule success-based restart reset
                handler.postDelayed({ resetErrorCount() }, SUCCESS_RESET_ERRORS_DELAY)
            }
        }
        
        // Always restart for continuous recognition
        scheduleRestart("Session completed", RESTART_DELAY_MS)
    }
    
    override fun onPartialResults(partialResults: Bundle?) {
        if (!this.partialResults) return
        
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val transcript = matches[0].trim()
            
            if (transcript.length >= MIN_RESULT_LENGTH) {
                android.util.Log.d(TAG, "📝 Partial result: \"$transcript\"")
                sendResultEvent(transcript, isFinal = false, confidence = 0.8)
                lastResultTime = System.currentTimeMillis()
            }
        }
    }
    
    override fun onEvent(eventType: Int, params: Bundle?) {
        android.util.Log.d(TAG, "📡 Recognition event: $eventType")
    }
    
    // MARK: - Event Sending
    
    private fun sendResultEvent(transcript: String, isFinal: Boolean, confidence: Double) {
        val event = mapOf(
            "type" to "result",
            "transcript" to transcript,
            "isFinal" to isFinal,
            "confidence" to confidence,
            "locale" to currentLocale,
            "timestamp" to System.currentTimeMillis()
        )
        
        activity.runOnUiThread {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error sending result event", e)
            }
        }
    }
    
    private fun sendErrorEvent(message: String) {
        val event = mapOf(
            "type" to "error",
            "message" to message,
            "timestamp" to System.currentTimeMillis()
        )
        
        activity.runOnUiThread {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error sending error event", e)
            }
        }
    }
    
    private fun sendStatusEvent(status: String) {
        val event = mapOf(
            "type" to "status",
            "status" to status,
            "timestamp" to System.currentTimeMillis()
        )
        
        activity.runOnUiThread {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error sending status event", e)
            }
        }
    }
    
    fun cleanup() {
        android.util.Log.d(TAG, "🧹 Cleaning up speech manager")
        stopContinuousRecognition()
    }
}