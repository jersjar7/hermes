// android/app/src/main/kotlin/com/yourapp/hermes/ContinuousSpeechPlugin.kt

package com.jersondevs.hermes

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class ContinuousSpeechPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var continuousSpeechManager: ContinuousSpeechManager? = null
    private var context: Context? = null
    private var activity: Activity? = null
    
    companion object {
        private const val METHOD_CHANNEL = "hermes/continuous_speech"
        private const val EVENT_CHANNEL = "hermes/continuous_speech/events"
        private const val TAG = "ContinuousSpeech-Android"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        
        android.util.Log.d(TAG, "Plugin attached to engine")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        continuousSpeechManager?.cleanup()
        android.util.Log.d(TAG, "Plugin detached from engine")
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        initializeSpeechManager()
        android.util.Log.d(TAG, "Plugin attached to activity")
    }
    
    override fun onDetachedFromActivity() {
        continuousSpeechManager?.cleanup()
        activity = null
        android.util.Log.d(TAG, "Plugin detached from activity")
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        initializeSpeechManager()
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        // Don't cleanup here - just config change
    }
    
    private fun initializeSpeechManager() {
        if (context != null && activity != null) {
            continuousSpeechManager = ContinuousSpeechManager(context!!, activity!!, eventChannel)
            android.util.Log.d(TAG, "Speech manager initialized")
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> {
                handleIsAvailable(result)
            }
            
            "initialize" -> {
                handleInitialize(result)
            }
            
            "startContinuousRecognition" -> {
                handleStartContinuousRecognition(call, result)
            }
            
            "stopContinuousRecognition" -> {
                handleStopContinuousRecognition(result)
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun handleIsAvailable(result: Result) {
        try {
            val manager = continuousSpeechManager
            if (manager != null) {
                val isAvailable = manager.isAvailable()
                android.util.Log.d(TAG, "isAvailable: $isAvailable")
                result.success(isAvailable)
            } else {
                android.util.Log.w(TAG, "Speech manager not initialized")
                result.success(false)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error checking availability", e)
            result.success(false)
        }
    }
    
    private fun handleInitialize(result: Result) {
        try {
            val manager = continuousSpeechManager
            if (manager != null) {
                val initialized = manager.initialize()
                android.util.Log.d(TAG, "initialize: $initialized")
                result.success(initialized)
            } else {
                android.util.Log.w(TAG, "Speech manager not initialized")
                result.success(false)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error initializing", e)
            result.success(false)
        }
    }
    
    private fun handleStartContinuousRecognition(call: MethodCall, result: Result) {
        try {
            val locale = call.argument<String>("locale") ?: "en-US"
            val partialResults = call.argument<Boolean>("partialResults") ?: true
            
            val manager = continuousSpeechManager
            if (manager != null) {
                val started = manager.startContinuousRecognition(locale, partialResults)
                android.util.Log.d(TAG, "startContinuousRecognition: $started")
                result.success(started)
            } else {
                android.util.Log.w(TAG, "Speech manager not initialized")
                result.error("NOT_INITIALIZED", "Speech manager not initialized", null)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error starting continuous recognition", e)
            result.error("START_ERROR", e.message, null)
        }
    }
    
    private fun handleStopContinuousRecognition(result: Result) {
        try {
            val manager = continuousSpeechManager
            if (manager != null) {
                manager.stopContinuousRecognition()
                android.util.Log.d(TAG, "stopContinuousRecognition called")
                result.success(true)
            } else {
                android.util.Log.w(TAG, "Speech manager not initialized")
                result.success(false)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error stopping continuous recognition", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }
}