// ios/Runner/Speech/Plugin/SpeechMethodHandler.swift

import Flutter
import Foundation
import Speech

/// Handles Flutter method channel calls for speech recognition
/// Simplified - no pattern detection, only continuous partials
@available(iOS 16.0, *)
class SpeechMethodHandler: NSObject {
    
    // MARK: - Properties
    
    private let methodChannel: FlutterMethodChannel
    private let eventSender: SpeechEventSender
    
    // Speech components
    private var speechManager: SpeechRecognitionManager?
    
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
        print("🎤 [MethodHandler] Method channel initialized - partials only")
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
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        guard speechAuth != .denied && speechAuth != .restricted else {
            result(false)
            return
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale)),
              recognizer.isAvailable else {
            result(false)
            return
        }
        
        result(true)
    }
    
    private func handleInitialize(arguments: Any?, result: @escaping FlutterResult) {
        guard !isInitialized else {
            result(true)
            return
        }
        
        let config = parseInitializeArguments(arguments)
        speechManager = SpeechRecognitionManager(config: config, delegate: self)
        
        Task {
            let granted = await speechManager?.requestPermissions() ?? false
            
            DispatchQueue.main.async { [weak self] in
                if granted {
                    self?.isInitialized = true
                    self?.eventSender.sendStatusUpdate("initialized")
                    result(true)
                } else {
                    self?.eventSender.sendError(message: "Speech recognition permissions denied", code: "PERMISSION_DENIED")
                    result(false)
                }
            }
        }
    }
    
    private func handleStartRecognition(arguments: Any?, result: @escaping FlutterResult) {
        guard isInitialized, let speechManager = speechManager else {
            let error = "Speech recognition not initialized"
            eventSender.sendError(message: error, code: "NOT_INITIALIZED")
            result(FlutterError(code: "NOT_INITIALIZED", message: error, details: nil))
            return
        }
        
        guard !isRecognitionActive else {
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
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    let errorMessage = "Failed to start recognition: \(error.localizedDescription)"
                    self?.eventSender.sendError(message: errorMessage, code: "START_FAILED")
                    result(FlutterError(code: "START_FAILED", message: errorMessage, details: nil))
                }
            }
        }
    }
    
    private func handleStopRecognition(result: @escaping FlutterResult) {
        guard isRecognitionActive else {
            result(nil)
            return
        }
        
        speechManager?.stopRecognition()
        isRecognitionActive = false
        eventSender.sendStatusUpdate("stopped")
        
        result(nil)
    }
    
    // MARK: - Argument Parsing
    
    private func parseInitializeArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            return .hermes
        }
        
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    private func parseRecognitionArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
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
        isInitialized = false
        isRecognitionActive = false
        
        methodChannel.setMethodCallHandler(nil)
    }
}

// MARK: - SpeechRecognitionManagerDelegate

@available(iOS 16.0, *)
extension SpeechMethodHandler: SpeechRecognitionManagerDelegate {
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceivePartialResult text: String, confidence: Double) {
        // Send all results as partials - buffer will handle processing
        eventSender.sendPartialResult(
            transcript: text,
            confidence: confidence,
            locale: currentLocale
        )
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceiveFinalResult text: String, confidence: Double) {
        // Treat iOS "final" as partial - buffer decides real finalization
        eventSender.sendPartialResult(
            transcript: text,
            confidence: confidence,
            locale: currentLocale
        )
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didChangeStatus status: SpeechRecognitionStatus) {
        eventSender.sendStatusUpdate("recognition-\(status.shortDescription)")
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didEncounterError error: Error) {
        eventSender.sendError(message: error.localizedDescription, code: "RECOGNITION_ERROR")
    }
}
