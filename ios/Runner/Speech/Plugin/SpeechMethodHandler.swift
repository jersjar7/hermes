// ios/Runner/Speech/Plugin/SpeechMethodHandler.swift

import Flutter
import Foundation
import Speech

/// Handles Flutter method channel calls for speech recognition
/// Coordinates between Flutter requests and speech recognition components
@available(iOS 16.0, *)
class SpeechMethodHandler: NSObject {
    
    // MARK: - Properties
    
    private let methodChannel: FlutterMethodChannel
    private let eventSender: SpeechEventSender
    
    // Speech components
    private var speechManager: SpeechRecognitionManager?
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
        print("🎤 [MethodHandler] Method channel initialized")
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
        
        // Check speech recognition authorization
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        guard speechAuth != .denied && speechAuth != .restricted else {
            print("❌ [MethodHandler] Speech recognition denied or restricted")
            result(false)
            return
        }
        
        // Check if recognizer is available for current locale
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
        print("🎤 [MethodHandler] Initializing speech recognition...")
        
        guard !isInitialized else {
            print("⚠️ [MethodHandler] Already initialized")
            result(true)
            return
        }
        
        // Parse configuration from Flutter
        let config = parseInitializeArguments(arguments)
        
        // Create speech recognition manager
        speechManager = SpeechRecognitionManager(config: config, delegate: self)
        
        // Create sentence detector with Hermes-optimized settings
        sentenceDetector = SentenceDetector(config: .hermes, delegate: self)
        
        // Request permissions asynchronously
        Task {
            let granted = await speechManager?.requestPermissions() ?? false
            
            DispatchQueue.main.async { [weak self] in
                if granted {
                    self?.isInitialized = true
                    self?.eventSender.sendStatusUpdate("initialized")
                    print("✅ [MethodHandler] Speech recognition initialized")
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
        print("🎤 [MethodHandler] Starting continuous recognition...")
        
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
        
        // Parse recognition configuration
        let config = parseRecognitionArguments(arguments)
        speechManager.updateConfig(config)
        
        // Start recognition
        Task {
            do {
                try await speechManager.startRecognition()
                
                DispatchQueue.main.async { [weak self] in
                    self?.isRecognitionActive = true
                    self?.eventSender.sendStatusUpdate("started")
                    print("✅ [MethodHandler] Recognition started successfully")
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
        print("🎤 [MethodHandler] Stopping continuous recognition...")
        
        guard isRecognitionActive else {
            print("⚠️ [MethodHandler] Recognition not active")
            result(nil)
            return
        }
        
        // Stop components
        speechManager?.stopRecognition()
        sentenceDetector?.stop()
        
        isRecognitionActive = false
        eventSender.sendStatusUpdate("stopped")
        
        print("✅ [MethodHandler] Recognition stopped")
        result(nil)
    }
    
    // MARK: - Argument Parsing
    
    private func parseInitializeArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            print("🎤 [MethodHandler] No initialization arguments, using default config")
            return .hermes
        }
        
        // Extract locale
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
        
        // Update locale if provided
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if isRecognitionActive {
            speechManager?.stopRecognition()
            sentenceDetector?.stop()
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
        // Feed partial results to sentence detector
        sentenceDetector?.processPartialTranscript(text)
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceiveFinalResult text: String, confidence: Double) {
        // Force finalize through sentence detector
        sentenceDetector?.forceFinalize(reason: "ios-final")
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didChangeStatus status: SpeechRecognitionStatus) {
        eventSender.sendStatusUpdate("recognition-\(status.shortDescription)")
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didEncounterError error: Error) {
        eventSender.sendError(message: error.localizedDescription, code: "RECOGNITION_ERROR")
    }
}

// MARK: - SentenceDetectorDelegate

@available(iOS 16.0, *)
extension SpeechMethodHandler: SentenceDetectorDelegate {
    
    func sentenceDetector(_ detector: SentenceDetector, didDetectPartial text: String) {
        // Send partial result to Flutter
        eventSender.sendRecognitionResult(
            transcript: text,
            isFinal: false,
            confidence: 1.0,
            locale: currentLocale
        )
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didFinalizeSentence text: String, reason: String) {
        // Send final result to Flutter with reason
        eventSender.sendRecognitionResult(
            transcript: text,
            isFinal: true,
            confidence: 1.0,
            locale: currentLocale,
            reason: reason
        )
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didEncounterError error: Error) {
        eventSender.sendError(message: error.localizedDescription, code: "SENTENCE_DETECTION_ERROR")
    }
}
