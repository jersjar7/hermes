// ios/Runner/Speech/Plugin/SpeechMethodHandler.swift
// STEP 5: Updated method handler that properly uses enhanced event sender

import Flutter
import Foundation
import Speech

/// Updated method handler that properly separates partial and confirmed results
@available(iOS 16.0, *)
class SpeechMethodHandler: NSObject {
    
    // MARK: - Properties
    
    private let methodChannel: FlutterMethodChannel
    private let eventSender: SpeechEventSender
    
    // Speech components
    private var speechManager: SpeechRecognitionManager?
    
    // 🆕 Sentence detector for pattern detection
    private var sentenceDetector: SentenceDetector?
    
    // State
    private var isInitialized = false
    private var isRecognitionActive = false
    private var currentLocale = "en-US"
    
    // MARK: - Initialization
    
    init(binaryMessenger: FlutterBinaryMessenger, eventSender: SpeechEventSender) {
        self.methodChannel = FlutterMethodChannel(
            name: "hermes/continuous_speech",
            binaryMessenger: binaryMessenger
        )
        self.eventSender = eventSender
        
        super.init()
        
        methodChannel.setMethodCallHandler(handleMethodCall)
        print("🎤 [MethodHandler] Enhanced method channel initialized with PURE PATTERN detection")
    }
    
    deinit {
        cleanup()
        print("🎤 [MethodHandler] Method handler deallocated")
    }
    
    // MARK: - Method Channel Handler
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Method call: \(call.method)")
        
        switch call.method {
        case "isAvailable":
            handleIsAvailable(result: result)
            
        case "initialize":
            handleInitialize(arguments: call.arguments, result: result)
            
        case "startContinuousRecognition":
            handleStartRecognition(arguments: call.arguments, result: result)
            
        case "stopContinuousRecognition":
            handleStopRecognition(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Implementations
    
    private func handleIsAvailable(result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Checking speech recognition availability...")
        
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        guard speechAuth != .denied && speechAuth != .restricted else {
            print("❌ [MethodHandler] Speech recognition denied or restricted")
            result(false)
            return
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale)),
              recognizer.isAvailable else {
            print("❌ [MethodHandler] Speech recognizer not available for locale: \(currentLocale)")
            result(false)
            return
        }
        
        print("✅ [MethodHandler] Speech recognition available")
        result(true)
    }
    
    private func handleInitialize(arguments: Any?, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Initializing ENHANCED PATTERN-BASED speech recognition...")
        
        guard !isInitialized else {
            print("⚠️ [MethodHandler] Already initialized")
            result(true)
            return
        }
        
        let config = parseInitializeArguments(arguments)
        speechManager = SpeechRecognitionManager(config: config, delegate: self)
        
        // 🆕 Create enhanced sentence detector
        let detectorConfig = SentenceDetectionConfig.hermes
        sentenceDetector = SentenceDetector(config: detectorConfig, delegate: self)
        
        print("✅ [MethodHandler] Created ENHANCED PATTERN detector")
        
        Task {
            let granted = await speechManager?.requestPermissions() ?? false
            
            DispatchQueue.main.async { [weak self] in
                if granted {
                    self?.isInitialized = true
                    self?.eventSender.sendStatusUpdate("initialized")
                    print("✅ [MethodHandler] Enhanced pattern-based speech recognition initialized")
                    result(true)
                } else {
                    self?.eventSender.sendError(message: "Speech recognition permissions denied", code: "PERMISSION_DENIED")
                    print("❌ [MethodHandler] Speech recognition permissions denied")
                    result(false)
                }
            }
        }
    }
    
    private func handleStartRecognition(arguments: Any?, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Starting ENHANCED PATTERN continuous recognition...")
        
        guard isInitialized, let speechManager = speechManager else {
            let error = "Speech recognition not initialized"
            eventSender.sendError(message: error, code: "NOT_INITIALIZED")
            result(FlutterError(code: "NOT_INITIALIZED", message: error, details: nil))
            return
        }
        
        guard !isRecognitionActive else {
            print("⚠️ [MethodHandler] Recognition already active")
            result(nil)
            return
        }
        
        let config = parseRecognitionArguments(arguments)
        speechManager.updateConfig(config)
        
        Task {
            do {
                try await speechManager.startRecognition()
                
                DispatchQueue.main.async { [weak self] in
                    self?.isRecognitionActive = true
                    self?.eventSender.sendStatusUpdate("started")
                    print("✅ [MethodHandler] Enhanced pattern recognition started successfully")
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    let errorMessage = "Failed to start recognition: \(error.localizedDescription)"
                    self?.eventSender.sendError(message: errorMessage, code: "START_FAILED")
                    print("❌ [MethodHandler] \(errorMessage)")
                    result(FlutterError(code: "START_FAILED", message: errorMessage, details: nil))
                }
            }
        }
    }
    
    private func handleStopRecognition(result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Stopping enhanced pattern recognition...")
        
        guard isRecognitionActive else {
            print("⚠️ [MethodHandler] Recognition not active")
            result(nil)
            return
        }
        
        speechManager?.stopRecognition()
        
        // 🆕 Force finalize any pending content (only if substantial)
        // Note: We'll handle this through the existing sentence detector
        
        isRecognitionActive = false
        eventSender.sendStatusUpdate("stopped")
        
        print("✅ [MethodHandler] Enhanced pattern recognition stopped")
        result(nil)
    }
    
    // MARK: - Argument Parsing
    
    private func parseInitializeArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            print("🎤 [MethodHandler] No initialization arguments, using default config")
            return .hermes
        }
        
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    private func parseRecognitionArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            print("🎤 [MethodHandler] No recognition arguments, using current config")
            return speechManager?.currentConfig ?? .hermes
        }
        
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if isRecognitionActive {
            speechManager?.stopRecognition()
        }
        
        speechManager = nil
        sentenceDetector = nil
        isInitialized = false
        isRecognitionActive = false
        
        methodChannel.setMethodCallHandler(nil)
    }
}

// MARK: - SpeechRecognitionManagerDelegate

@available(iOS 16.0, *)
extension SpeechMethodHandler: SpeechRecognitionManagerDelegate {
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceivePartialResult text: String, confidence: Double) {
        print("📝 [MethodHandler] Partial from iOS: '\(String(text.prefix(50)))...'")
        
        // 🆕 Send as partial result to Flutter for UI updates
        eventSender.sendPartialResult(
            transcript: text,
            confidence: confidence,
            locale: currentLocale
        )
        
        // 🆕 Feed to pattern detector for analysis
        sentenceDetector?.processPartialTranscript(text, isFinal: false)
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceiveFinalResult text: String, confidence: Double) {
        print("📝 [MethodHandler] iOS marked as final: '\(String(text.prefix(50)))...'")
        
        // 🚨 CRITICAL: Don't send as final result to Flutter!
        // Send as partial result and let pattern detector decide
        eventSender.sendPartialResult(
            transcript: text,
            confidence: confidence,
            locale: currentLocale
        )
        
        // Let pattern detector analyze this "final" result
        sentenceDetector?.processPartialTranscript(text, isFinal: false)
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didChangeStatus status: SpeechRecognitionStatus) {
        eventSender.sendStatusUpdate("recognition-\(status.shortDescription)")
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didEncounterError error: Error) {
        eventSender.sendError(message: error.localizedDescription, code: "RECOGNITION_ERROR")
    }
}

// MARK: - SentenceDetectorDelegate (for existing SentenceDetector)

@available(iOS 16.0, *)
extension SpeechMethodHandler: SentenceDetectorDelegate {
    
    func sentenceDetector(_ detector: SentenceDetector, didDetectPartial text: String) {
        // Already sent as partial result above, no need to send again
        // This just confirms the pattern detector is processing
        print("🔍 [MethodHandler] Pattern detector processing: '\(String(text.prefix(30)))...'")
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didFinalizeSentence text: String, reason: String) {
        // 🎯 CRITICAL: Only send when pattern detector confirms COMPLETE sentence
        print("🎯 [MethodHandler] ✅ PATTERN CONFIRMED COMPLETE SENTENCE: '\(String(text.prefix(50)))...' (reason: \(reason))")
        
        // 🆕 Use the new pattern-confirmed event sender
        eventSender.sendPatternConfirmedSentence(
            transcript: text,
            confidence: 1.0,
            locale: currentLocale,
            reason: reason
        )
        
        // 🆕 Debug analysis
        print("🔍 [MethodHandler] Sentence finalized with reason: \(reason)")
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didEncounterError error: Error) {
        print("❌ [MethodHandler] Sentence detector error: \(error)")
        eventSender.sendError(message: error.localizedDescription, code: "SENTENCE_DETECTION_ERROR")
    }
}
