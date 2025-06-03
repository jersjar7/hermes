// android/app/src/main/kotlin/com/jersondevs/hermes/ContinuousSpeechManager.kt
// 🎯 PROVEN SOLUTION: Based on multiple successful Android speech recognition libraries

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
    private var consecutiveNoMatchErrors = 0
    private var sessionStartTime = 0L
    
    // 🎯 SOLUTION: Track partial results to recover from ERROR_NO_MATCH
    private var lastPartialResult = ""
    private var lastUnstableText = ""
    private var hasPartialResults = false
    
    // Audio management
    private var audioManager: AudioManager? = null
    
    private companion object {
        const val TAG = "ContinuousSpeech-Android"
        const val RESTART_DELAY_MS = 800L  // Slightly longer for stability
        const val NO_MATCH_RECOVERY_DELAY = 500L  // Quick recovery after extracting partial results
        const val ERROR_BACKOFF_BASE_MS = 2000L
        const val MAX_CONSECUTIVE_NO_MATCH = 20  // More tolerant since we recover from partials
        const val SILENCE_TIMEOUT_MS = 5000L
        const val MIN_SPEECH_LENGTH_MS = 1500L
        const val MAX_SESSION_DURATION_MS = 45000L
        const val MIN_RESULT_LENGTH = 1
        const val SUCCESS_RESET_DELAY = 8000L
    }
    
    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        setupEventChannel()
        android.util.Log.d(TAG, "🎯 Initialized with ERROR_NO_MATCH workaround using partial results")
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
                android.util.Log.d(TAG, "✅ Android SpeechRecognizer initialized with partial results workaround")
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
                Thread.sleep(300)
            }
            
            currentLocale = locale
            this.partialResults = partialResults
            shouldContinue = true
            consecutiveNoMatchErrors = 0
            sessionStartTime = System.currentTimeMillis()
            
            // Reset partial result tracking
            lastPartialResult = ""
            lastUnstableText = ""
            hasPartialResults = false
            
            android.util.Log.d(TAG, "🚀 Starting proven Android recognition with partial results workaround")
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
        
        restartRunnable?.let { 
            handler.removeCallbacks(it)
            android.util.Log.d(TAG, "Cancelled pending restart")
        }
        restartRunnable = null
        
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
            speechRecognizer?.let { oldRecognizer ->
                try {
                    oldRecognizer.destroy()
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Error destroying old recognizer: ${e.message}")
                }
            }
            
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            
            if (speechRecognizer == null) {
                android.util.Log.e(TAG, "❌ Failed to create SpeechRecognizer")
                handleRecognitionError("Failed to create SpeechRecognizer")
                return
            }
            
            speechRecognizer?.setRecognitionListener(this)
            
            // 🎯 PROVEN: Use settings that maximize partial results
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, currentLocale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)  // Critical for workaround
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                
                // 🎯 OPTIMIZED: Settings that encourage partial results
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, SILENCE_TIMEOUT_MS)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, MIN_SPEECH_LENGTH_MS)
                
                // Prefer online for better accuracy
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
                putExtra(RecognizerIntent.EXTRA_CONFIDENCE_SCORES, true)
                
                // Additional settings to encourage partial results
                putExtra("android.speech.extra.PARTIAL_RESULTS_WITH_CONFIDENCE", true)
                putExtra("android.speech.extra.UNSTABLE_TEXT", true)
            }
            
            isListening = true
            lastResultTime = System.currentTimeMillis()
            
            // Reset partial result tracking for this session
            lastPartialResult = ""
            lastUnstableText = ""
            hasPartialResults = false
            
            speechRecognizer?.startListening(intent)
            android.util.Log.d(TAG, "📱 Started recognition session optimized for partial results")
            
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
            }
        }
        
        handler.postDelayed(restartRunnable!!, delayMs)
    }
    
    private fun handleRecognitionError(message: String) {
        android.util.Log.w(TAG, "⚠️ Recognition error: $message")
        val backoffDelay = ERROR_BACKOFF_BASE_MS
        scheduleRestart("Error recovery", backoffDelay)
    }
    
    // 🎯 SOLUTION: Handle ERROR_NO_MATCH by extracting partial results
    private fun handleNoMatchError() {
        consecutiveNoMatchErrors++
        android.util.Log.w(TAG, "🔍 ERROR_NO_MATCH #$consecutiveNoMatchErrors - checking partial results")
        
        // 🎯 KEY: Try to recover speech from partial results
        val recoveredText = combinePartialResults()
        
        if (recoveredText.isNotEmpty()) {
            android.util.Log.i(TAG, "🎉 RECOVERED from ERROR_NO_MATCH: \"$recoveredText\"")
            
            // Send the recovered result as a final result
            sendResultEvent(recoveredText, isFinal = true, confidence = 0.8)
            lastResultTime = System.currentTimeMillis()
            
            // Reset error count since we successfully recovered
            consecutiveNoMatchErrors = 0
            
            // Quick restart since we got something useful
            scheduleRestart("Recovered from no-match", NO_MATCH_RECOVERY_DELAY)
        } else {
            android.util.Log.w(TAG, "🔍 No partial results to recover from ERROR_NO_MATCH")
            
            if (consecutiveNoMatchErrors >= MAX_CONSECUTIVE_NO_MATCH) {
                android.util.Log.e(TAG, "❌ Too many consecutive no-match errors, audio might be too quiet")
                sendErrorEvent("Unable to detect clear speech. Please speak louder or check microphone.")
                stopContinuousRecognition()
                return
            }
            
            scheduleRestart("No match - trying again", RESTART_DELAY_MS)
        }
    }
    
    // 🎯 CORE SOLUTION: Combine partial results and unstable text
    private fun combinePartialResults(): String {
        val combined = StringBuilder()
        
        if (lastPartialResult.isNotEmpty()) {
            combined.append(lastPartialResult)
        }
        
        if (lastUnstableText.isNotEmpty()) {
            if (combined.isNotEmpty()) {
                combined.append(" ")
            }
            combined.append(lastUnstableText)
        }
        
        val result = combined.toString().trim()
        android.util.Log.d(TAG, "🔧 Combined partial results: \"$result\" (from partial: \"$lastPartialResult\", unstable: \"$lastUnstableText\")")
        
        return result
    }
    
    private fun resetErrorCounts() {
        if (consecutiveNoMatchErrors > 0) {
            android.util.Log.d(TAG, "✅ Resetting error counts (was $consecutiveNoMatchErrors no-matches)")
            consecutiveNoMatchErrors = 0
        }
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
        // Log strong audio levels
        if (rmsdB > 8.0) {
            android.util.Log.v(TAG, "🔊 Strong audio: ${rmsdB.toInt()} dB")
        }
    }
    
    override fun onBufferReceived(buffer: ByteArray?) {
        if (buffer != null && buffer.isNotEmpty()) {
            android.util.Log.v(TAG, "📦 Audio buffer: ${buffer.size} bytes")
        }
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
        
        when (error) {
            SpeechRecognizer.ERROR_NO_MATCH -> {
                // 🎯 CORE: Handle ERROR_NO_MATCH with partial results recovery
                handleNoMatchError()
            }
            
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                android.util.Log.d(TAG, "Speech timeout - quick restart")
                scheduleRestart("Speech timeout", RESTART_DELAY_MS)
            }
            
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                android.util.Log.w(TAG, "Recognizer busy - waiting longer")
                scheduleRestart("Recognizer busy", ERROR_BACKOFF_BASE_MS)
            }
            
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> {
                sendErrorEvent("Network connectivity issue, retrying...")
                handleRecognitionError(errorMessage)
            }
            
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                android.util.Log.e(TAG, "❌ Insufficient permissions - stopping")
                sendErrorEvent("Microphone permission required")
                stopContinuousRecognition()
            }
            
            else -> {
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
                android.util.Log.d(TAG, "🎉 Final result: \"$transcript\" (confidence: $confidence)")
                
                sendResultEvent(transcript, isFinal = true, confidence = confidence)
                lastResultTime = System.currentTimeMillis()
                resetErrorCounts()
                
                if (matches.size > 1) {
                    android.util.Log.d(TAG, "Additional results: ${matches.drop(1).joinToString(", ")}")
                }
                
                handler.postDelayed({ resetErrorCounts() }, SUCCESS_RESET_DELAY)
            } else {
                android.util.Log.w(TAG, "Result too short: \"$transcript\" - checking partials")
                // Even if result is short, try partial recovery
                handleNoMatchError()
            }
        } else {
            android.util.Log.w(TAG, "Empty results - trying partial recovery")
            handleNoMatchError()
        }
        
        scheduleRestart("Session completed", RESTART_DELAY_MS)
    }
    
    // 🎯 CRITICAL: This is where we capture the speech for ERROR_NO_MATCH recovery
    override fun onPartialResults(partialResults: Bundle?) {
        if (!this.partialResults) return
        
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val unstableMatches = partialResults?.getStringArrayList("android.speech.extra.UNSTABLE_TEXT")
        
        if (!matches.isNullOrEmpty()) {
            val transcript = matches[0].trim()
            
            if (transcript.length >= MIN_RESULT_LENGTH) {
                // 🎯 SOLUTION: Store partial results for ERROR_NO_MATCH recovery
                lastPartialResult = transcript
                hasPartialResults = true
                
                android.util.Log.d(TAG, "📝 Partial result: \"$transcript\"")
                sendResultEvent(transcript, isFinal = false, confidence = 0.8)
                lastResultTime = System.currentTimeMillis()
                
                // Partial results count as success
                if (transcript.length > 3) {
                    resetErrorCounts()
                }
            }
        }
        
        // 🎯 SOLUTION: Also capture unstable text for complete recovery
        if (!unstableMatches.isNullOrEmpty()) {
            val unstableText = unstableMatches[0].trim()
            if (unstableText.isNotEmpty()) {
                lastUnstableText = unstableText
                android.util.Log.d(TAG, "📝 Unstable text: \"$unstableText\"")
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
            "recovered" to (isFinal && hasPartialResults && consecutiveNoMatchErrors > 0),
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